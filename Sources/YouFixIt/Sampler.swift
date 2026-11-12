import CoreAudio
import CoreGraphics
import Darwin
import Foundation
import IOKit.pwr_mgt

/// Reads the whole machine into a `Sample`. Lives off the main actor; AppKit facts arrive as `AppSeed`s.
actor Sampler {
    private var prevTicks: [pid_t: (start: TimeInterval, ticks: UInt64)] = [:]
    private var prevMach: UInt64 = 0
    private var prevCPU: host_cpu_load_info_data_t?
    private var pathCache: [pid_t: (start: TimeInterval, path: String)] = [:]
    private var simCache: (at: Date, sims: [Sample.Sim])?
    private var vmCache: [String: (at: Date, idle: Bool)] = [:]
    private var jobsCache: (at: Date, jobs: [pid_t: String])?
    private var assertionCache: (at: Date, list: [Sample.Assertion])?
    private var lastBusy: [pid_t: (start: Date, at: Date)] = [:]
    private let began = Date()

    static let me = getuid()
    /// Names whose orphans may be dev servers (R3) or other leftovers (G12).
    static let serverNames: Set<String> = ["node", "bun", "deno", "python", "python3", "ruby", "java", "php"]
    /// Databases a coding session can start and leave behind (B3).
    static let dbNames: Set<String> = ["mysqld", "mariadbd", "postgres", "redis-server", "valkey-server", "mongod", "memcached"]
    static let browserNames: Set<String> = ["Google Chrome", "Google Chrome Beta", "Google Chrome Canary", "Chromium", "Brave Browser", "Microsoft Edge", "chrome-headless-shell"]
    static let brewPrefixes = ["/opt/homebrew/", "/usr/local/Cellar/", "/usr/local/opt/"]
    /// launchd label prefixes of a Homebrew service (the older and the current naming); the rest is the formula name.
    static let brewLabels = ["homebrew.mxcl.", "sh.brew."]
    /// A Claude coding session started by the Claude desktop app.
    static let claudeSession = "/claude.app/Contents/MacOS/claude"
    /// Virtual machine apps and the Docker socket that says whether anything runs inside.
    static let vmSockets: [String: String] = [
        "com.docker.docker": NSHomeDirectory() + "/.docker/run/docker.sock",
        "dev.kdrag0n.MacVirt": NSHomeDirectory() + "/.orbstack/run/docker.sock",
    ]

    func take(apps seeds: [AppSeed], frontmost: pid_t) async -> Sample {
        let now = Date()
        let mach = mach_absolute_time()
        let deltaMach = prevMach == 0 ? 0 : Double(mach &- prevMach)

        // 1. Every process: parent, owner, start time, CPU ticks, memory, disk traffic.
        var procs: [pid_t: Sample.Proc] = [:]
        var children: [pid_t: [pid_t]] = [:]
        var ticksNow: [pid_t: (start: TimeInterval, ticks: UInt64)] = [:]
        for pid in Self.pids() {
            var bsd = proc_bsdinfo()
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 else { continue }
            var task = proc_taskinfo()
            let haveTask = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size)) > 0
            let start = TimeInterval(bsd.pbi_start_tvsec) + TimeInterval(bsd.pbi_start_tvusec) / 1_000_000
            let path = self.path(pid, start: start)
            let name = path.isEmpty ? Self.shortName(&bsd) : (path as NSString).lastPathComponent
            let ticks = task.pti_total_user &+ task.pti_total_system
            var cpu = 0.0
            if haveTask, deltaMach > 0, let prev = prevTicks[pid], prev.start == start, ticks >= prev.ticks {
                cpu = Double(ticks - prev.ticks) / deltaMach
            }
            if haveTask { ticksNow[pid] = (start, ticks) }
            var footprint = task.pti_resident_size
            var io: UInt64 = 0
            if bsd.pbi_uid == Self.me, let usage = Self.rusage(pid) {
                footprint = usage.footprint
                io = usage.io
            }
            let ppid = pid_t(bsd.pbi_ppid)
            procs[pid] = Sample.Proc(pid: pid, ppid: ppid, uid: bsd.pbi_uid, name: name, path: path,
                                     start: Date(timeIntervalSince1970: start), cpu: cpu, footprint: footprint, diskIO: io)
            children[ppid, default: []].append(pid)
        }
        prevTicks = ticksNow
        prevMach = mach
        pathCache = pathCache.filter { procs[$0.key]?.start.timeIntervalSince1970 == $0.value.start }

        // 2. Windows and audio, then the apps.
        let win = Self.windows()
        let audio = Self.audioPids()
        let apps = seeds.map { s in
            Sample.App(pid: s.pid, bundleID: s.bundleID, name: s.name, url: s.url, regular: s.regular, accessory: s.accessory, hidden: s.hidden,
                       active: s.active, launched: s.launched, lastActivated: s.lastActivated,
                       windows: win.normal[s.pid] ?? 0, hasModal: win.modal.contains(s.pid), audio: audio.contains(s.pid))
        }
        let appPids = Set(seeds.map(\.pid))

        // 3. Arguments, working directory and sockets, only for our own parent-pid-1 processes (orphans, launchd_sim,
        //    headless browsers) and Homebrew services; the working directory of Claude coding sessions.
        var args: [pid_t: [String]] = [:]
        var cwd: [pid_t: String] = [:]
        var listening = Set<pid_t>()
        var ports: [pid_t: [Int]] = [:]
        var clients: [pid_t: Int] = [:]
        var orphanCandidates = false
        var brewCandidates = false
        func sockets(under root: pid_t, where test: (Sample.Proc) -> Bool) {
            // The listener is often a child (npm exec → node), so look through the whole tree. Clients are judged per
            // tree, so the tree's processes talking to each other never count as someone using it.
            var tree: [pid_t: Sockets] = [:]
            var queue = [root]
            while let pid = queue.popLast() {
                if let q = procs[pid], test(q) {
                    let sock = Self.sockets(pid)
                    tree[pid] = sock
                    if !sock.listening.isEmpty {
                        listening.insert(pid)
                        ports[pid] = sock.listening
                    }
                }
                queue.append(contentsOf: children[pid] ?? [])
            }
            clients.merge(Self.clients(tree)) { $1 }
        }
        let leftovers = Self.serverNames.union(Self.dbNames)
        for p in procs.values where p.uid == Self.me {
            if p.path.hasSuffix(Self.claudeSession), let dir = Self.cwd(p.pid) { cwd[p.pid] = dir }
            if Self.brewPrefixes.contains(where: { p.path.hasPrefix($0) }) { brewCandidates = true }
            // A database behind a wrapper (mysqld_safe, a shell) is judged where it runs; a worker of one is part of it.
            if p.ppid != 1, Self.dbNames.contains(p.name), procs[p.ppid]?.name != p.name {
                orphanCandidates = true
                args[p.pid] = Self.args(p.pid)
                sockets(under: p.pid) { Self.dbNames.contains($0.name) }
            }
            let browser = Self.browserNames.contains(p.name)
            guard p.ppid == 1 || browser else { continue }
            if p.name == "launchd_sim" || leftovers.contains(p.name) || browser { args[p.pid] = Self.args(p.pid) }
            if p.ppid == 1, leftovers.contains(p.name), !appPids.contains(p.pid) {
                orphanCandidates = true
                if let dir = Self.cwd(p.pid) { cwd[p.pid] = dir }
                sockets(under: p.pid) { leftovers.contains($0.name) }
            }
            if p.ppid == 1, browser { orphanCandidates = true }
        }
        var jobs: [pid_t: String] = [:]
        if orphanCandidates || brewCandidates {
            if let cached = jobsCache, now.timeIntervalSince(cached.at) < 60 {
                jobs = cached.jobs
            } else {
                jobs = await Self.jobs()
                jobsCache = (now, jobs)
            }
        }
        for (root, label) in jobs where Self.brewLabels.contains(where: { label.hasPrefix($0) }) { sockets(under: root) { _ in true } }

        // 4. Simulators, only when a device is actually booted (simctl itself would start CoreSimulatorService).
        var sims: [Sample.Sim] = []
        let launchdSims = procs.values.filter { $0.name == "launchd_sim" }
        if !launchdSims.isEmpty {
            if let cached = simCache, now.timeIntervalSince(cached.at) < 60 {
                sims = cached.sims
            } else {
                sims = await Self.bootedSims(launchd: launchdSims, args: args)
                simCache = (now, sims)
            }
        } else {
            simCache = nil
        }
        // 5. Virtual machine apps: ask their Docker socket whether anything runs inside, once a minute.
        var containersIdle: [String: Bool] = [:]
        for seed in seeds {
            guard let sock = Self.vmSockets[seed.bundleID] else { continue }
            if let cached = vmCache[seed.bundleID], now.timeIntervalSince(cached.at) < 60 {
                containersIdle[seed.bundleID] = cached.idle
            } else {
                let idle = await Self.containersIdle(socket: sock)
                vmCache[seed.bundleID] = (now, idle)
                containersIdle[seed.bundleID] = idle
            }
        }

        // 6. What keeps the Mac awake, once a minute.
        let assertions: [Sample.Assertion]
        if let cached = assertionCache, now.timeIntervalSince(cached.at) < 60 {
            assertions = cached.list
        } else {
            assertions = Self.assertions()
            assertionCache = (now, assertions)
        }

        // 7. Claude coding sessions: when each tree last did any work, remembered beyond the fifteen-minute history.
        //    Until a session has been watched for a while, "quiet" counts from when watching began.
        var quietSince: [pid_t: Date] = [:]
        var sessions = Set<pid_t>()
        for p in procs.values where p.uid == Self.me && p.path.hasSuffix(Self.claudeSession) {
            sessions.insert(p.pid)
            var cpu = 0.0
            var queue = [p.pid]
            while let pid = queue.popLast() {
                cpu += procs[pid]?.cpu ?? 0
                queue.append(contentsOf: children[pid] ?? [])
            }
            if cpu >= 0.02 { lastBusy[p.pid] = (p.start, now) }
            let busy = lastBusy[p.pid].flatMap { $0.start == p.start ? $0.at : nil }
            quietSince[p.pid] = busy ?? max(p.start, began)
        }
        lastBusy = lastBusy.filter { sessions.contains($0.key) }

        // 8. The machine.
        let cpuBusy = systemCPU()
        let mem = Self.memory()
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        let login = procs.values.first { $0.name == "loginwindow" && $0.uid == Self.me }?.start
        let front = procs[frontmost]
        let fullscreen = front.map { win.fullscreen.contains($0.pid) } ?? false

        return Sample(at: now, procs: procs, children: children, apps: apps, sims: sims, jobs: jobs, args: args, cwd: cwd,
                      listening: listening, ports: ports, clients: clients, containersIdle: containersIdle, assertions: assertions,
                      quietSince: quietSince, frontmost: frontmost,
                      fullscreen: fullscreen, cpuBusy: cpuBusy, load1: load[0],
                      cores: ProcessInfo.processInfo.activeProcessorCount, memUsed: mem.used,
                      memTotal: ProcessInfo.processInfo.physicalMemory, compressed: mem.compressed, swapUsed: mem.swap,
                      pressure: Self.pressure(), thermal: ProcessInfo.processInfo.thermalState.rawValue,
                      booted: Self.bootTime(), loggedIn: login)
    }

    // MARK: - libproc

    nonisolated static func pids() -> [pid_t] {
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytes > 0 else { return [] }
        var buf = [pid_t](repeating: 0, count: Int(bytes) / MemoryLayout<pid_t>.size + 64)
        let got = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &buf, Int32(buf.count * MemoryLayout<pid_t>.size))
        guard got > 0 else { return [] }
        return buf.prefix(Int(got) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    private func path(_ pid: pid_t, start: TimeInterval) -> String {
        if let cached = pathCache[pid], cached.start == start { return cached.path }
        let path = Self.currentPath(pid)
        pathCache[pid] = (start, path)
        return path
    }

    /// The executable of a process right now; "" when it is gone or unreadable.
    nonisolated static func currentPath(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let len = Int(proc_pidpath(pid, &buf, UInt32(buf.count)))
        return len > 0 ? String(decoding: buf.prefix(len).map { UInt8(bitPattern: $0) }, as: UTF8.self) : ""
    }

    /// Owner and parent of a process right now; nil when it is gone.
    nonisolated static func info(_ pid: pid_t) -> (uid: uid_t, ppid: pid_t)? {
        var bsd = proc_bsdinfo()
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 else { return nil }
        return (bsd.pbi_uid, pid_t(bsd.pbi_ppid))
    }

    /// Every process in a process group right now.
    nonisolated static func groupPids(_ pgid: pid_t) -> [pid_t] {
        let bytes = proc_listpids(UInt32(PROC_PGRP_ONLY), UInt32(pgid), nil, 0)
        guard bytes > 0 else { return [] }
        var buf = [pid_t](repeating: 0, count: Int(bytes) / MemoryLayout<pid_t>.size + 16)
        let got = proc_listpids(UInt32(PROC_PGRP_ONLY), UInt32(pgid), &buf, Int32(buf.count * MemoryLayout<pid_t>.size))
        guard got > 0 else { return [] }
        return buf.prefix(Int(got) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    /// Working directories and command lines of all our processes right now, for "is anything using this folder".
    nonisolated static func usage() -> (cwds: [String], args: [String]) {
        var cwds: [String] = []
        var lines: [String] = []
        let own = getpid()
        for pid in pids() where pid != own {
            guard let i = info(pid), i.uid == Self.me else { continue }
            if let dir = cwd(pid) { cwds.append(dir) }
            lines.append(args(pid).joined(separator: " "))
        }
        return (cwds, lines)
    }

    nonisolated static func shortName(_ bsd: inout proc_bsdinfo) -> String {
        withUnsafePointer(to: &bsd.pbi_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) * 2 + 1) { String(cString: $0) }
        }
    }

    /// The current working directory of one of our own processes; nil when unreadable.
    nonisolated static func cwd(_ pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(MemoryLayout<proc_vnodepathinfo>.size)) > 0 else { return nil }
        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return path.isEmpty ? nil : path
    }

    /// A process and all its descendants, read right now (for an apply-time re-check, when the sample may be stale).
    nonisolated static func treePids(_ root: pid_t) -> [pid_t] {
        var children: [pid_t: [pid_t]] = [:]
        for pid in pids() {
            var bsd = proc_bsdinfo()
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 else { continue }
            children[pid_t(bsd.pbi_ppid), default: []].append(pid)
        }
        var out: [pid_t] = []
        var queue = [root]
        while let pid = queue.popLast() {
            out.append(pid)
            queue.append(contentsOf: children[pid] ?? [])
        }
        return out
    }

    /// Real memory footprint and lifetime disk traffic; only answers for our own processes.
    nonisolated static func rusage(_ pid: pid_t) -> (footprint: UInt64, io: UInt64)? {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { p in
            p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        return ok == 0 ? (info.ri_phys_footprint, info.ri_diskio_bytesread &+ info.ri_diskio_byteswritten) : nil
    }

    nonisolated static func args(_ pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return [] }
        var buf = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0, size > 4 else { return [] }
        let argc = Int(buf.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        var i = 4
        while i < size, buf[i] != 0 { i += 1 }   // the executable path
        while i < size, buf[i] == 0 { i += 1 }   // padding
        var out: [String] = []
        while out.count < argc, i < size {
            var j = i
            while j < size, buf[j] != 0 { j += 1 }
            out.append(String(decoding: buf[i..<j], as: UTF8.self))
            i = j + 1
        }
        return out
    }

    /// A process's TCP sockets: the ports it listens on, and its open connections.
    struct Sockets: Sendable {
        struct Connection: Sendable {
            let local: Int
            let foreign: Int
            let loopback: Bool      // the peer is on this Mac (127.0.0.0/8, ::1, or loopback mapped into IPv6)
        }
        var listening: [Int] = []
        var connections: [Connection] = []
    }

    nonisolated static func sockets(_ pid: pid_t) -> Sockets {
        var out = Sockets()
        let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bytes > 0 else { return out }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bytes) / MemoryLayout<proc_fdinfo>.size + 16)
        let got = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, Int32(fds.count * MemoryLayout<proc_fdinfo>.size))
        guard got > 0 else { return out }
        for fd in fds.prefix(Int(got) / MemoryLayout<proc_fdinfo>.size) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var si = socket_fdinfo()
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &si, Int32(MemoryLayout<socket_fdinfo>.size)) > 0 else { continue }
            guard si.psi.soi_kind == SOCKINFO_TCP else { continue }
            let tcp = si.psi.soi_proto.pri_tcp
            let local = port(tcp.tcpsi_ini.insi_lport)
            switch tcp.tcpsi_state {
            case TSI_S_LISTEN:
                if !out.listening.contains(local) { out.listening.append(local) }
            case TSI_S_ESTABLISHED:
                out.connections.append(Sockets.Connection(local: local, foreign: port(tcp.tcpsi_ini.insi_fport), loopback: loopback(tcp.tcpsi_ini)))
            default: break
            }
        }
        return out
    }

    /// Ports arrive in network byte order in the low 16 bits.
    nonisolated static func port(_ raw: Int32) -> Int { Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: raw))) }

    nonisolated static func loopback(_ ini: in_sockinfo) -> Bool {
        if ini.insi_vflag & UInt8(INI_IPV4) != 0 {
            return UInt32(bigEndian: ini.insi_faddr.ina_46.i46a_addr4.s_addr) >> 24 == 127
        }
        return withUnsafeBytes(of: ini.insi_faddr.ina_6) { b in
            func zero(_ n: Int) -> Bool { (0..<n).allSatisfy { b[$0] == 0 } }
            if zero(15), b[15] == 1 { return true }                                         // ::1
            return zero(10) && b[10] == 0xff && b[11] == 0xff && b[12] == 127               // ::ffff:127.x.x.x
        }
    }

    /// Who is using a server tree: connections that arrived on one of the tree's listening ports from a peer outside it.
    /// A loopback peer whose port belongs to the tree is the tree talking to itself (Next's workers do), and a connection
    /// on a port the tree does not listen on is one it made (to a database, to the internet). Neither means someone uses it.
    nonisolated static func clients(_ tree: [pid_t: Sockets]) -> [pid_t: Int] {
        let listening = Set(tree.values.flatMap(\.listening))
        let own = listening.union(tree.values.flatMap { $0.connections.map(\.local) })
        var out: [pid_t: Int] = [:]
        for (pid, s) in tree {
            let n = s.connections.filter { listening.contains($0.local) && !($0.loopback && own.contains($0.foreign)) }.count
            if n > 0 { out[pid] = n }
        }
        return out
    }

    /// The same, read right now for an apply-time re-check: clients anywhere in the tree under `root`.
    nonisolated static func liveClients(root: pid_t) -> Int {
        var tree: [pid_t: Sockets] = [:]
        for pid in treePids(root) { tree[pid] = sockets(pid) }
        return clients(tree).values.reduce(0, +)
    }

    /// Sleep-preventing power assertions, credited to the process they are held for.
    nonisolated static func assertions() -> [Sample.Assertion] {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == 0, let dict = raw?.takeRetainedValue() as NSDictionary? else { return [] }
        var out: [Sample.Assertion] = []
        for (key, value) in dict {
            guard let holder = (key as? NSNumber)?.int32Value, let list = value as? [NSDictionary] else { continue }
            for a in list {
                guard let type = a["AssertType"] as? String, let since = a["AssertStartWhen"] as? Date else { continue }
                let owner = (a["AssertionOnBehalfOfPID"] as? NSNumber)?.int32Value ?? holder
                out.append(Sample.Assertion(pid: owner, type: type, name: a["AssertName"] as? String ?? "", since: since))
            }
        }
        return out
    }

    /// True when the Docker socket answers and lists no containers. Any failure counts as "in use".
    nonisolated static func containersIdle(socket: String) async -> Bool {
        guard FileManager.default.fileExists(atPath: socket),
              let r = await Shell.run("/usr/bin/curl", ["-s", "--max-time", "5", "--unix-socket", socket, "http://localhost/containers/json"], timeout: 8),
              r.status == 0 else { return false }
        return r.out.trimmingCharacters(in: .whitespacesAndNewlines) == "[]"
    }

    // MARK: - Windows and audio

    /// Windows on every Space, minimized ones included: a window parked on another desktop still means "in use".
    /// `fullscreen` only counts windows on screen right now.
    nonisolated static func windows() -> (normal: [pid_t: Int], modal: Set<pid_t>, fullscreen: Set<pid_t>) {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return ([:], [], [])
        }
        let screen = CGDisplayBounds(CGMainDisplayID())
        var normal: [pid_t: Int] = [:]
        var modal = Set<pid_t>()
        var fullscreen = Set<pid_t>()
        for w in list {
            guard let owner = w[kCGWindowOwnerPID as String] as? Int else { continue }
            let pid = pid_t(owner)
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            let alpha = w[kCGWindowAlpha as String] as? Double ?? 1
            let onScreen = (w[kCGWindowIsOnscreen as String] as? Bool) ?? false
            var bounds = CGRect.zero
            if let dict = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: dict) { bounds = r }
            guard alpha > 0.05, bounds.width >= 50, bounds.height >= 50 else { continue }
            switch layer {
            case 0:
                normal[pid, default: 0] += 1
                if onScreen, bounds.width >= screen.width, bounds.height >= screen.height { fullscreen.insert(pid) }
            case 8: if onScreen { modal.insert(pid) }
            default: break
            }
        }
        return (normal, modal, fullscreen)
    }

    nonisolated static func audioPids() -> Set<pid_t> {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var list = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &list, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &list, 0, nil, &size, &objects) == noErr else { return [] }
        var out = Set<pid_t>()
        for object in objects {
            var running: UInt32 = 0
            var rsize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput,
                                                         mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(object, &runningAddr, 0, nil, &rsize, &running) == noErr, running != 0 else { continue }
            var pid: pid_t = 0
            var psize = UInt32(MemoryLayout<pid_t>.size)
            var pidAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID,
                                                     mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(object, &pidAddr, 0, nil, &psize, &pid) == noErr else { continue }
            out.insert(pid)
        }
        return out
    }

    // MARK: - The machine

    private func systemCPU() -> Double {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let ok = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard ok == KERN_SUCCESS else { return 0 }
        defer { prevCPU = info }
        guard let prev = prevCPU else { return 0 }
        let user = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + system + idle + nice
        return total > 0 ? (user + system + nice) / total : 0
    }

    nonisolated static func memory() -> (used: UInt64, compressed: UInt64, swap: UInt64) {
        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let ok = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        let page = UInt64(getpagesize())
        var used: UInt64 = 0, compressed: UInt64 = 0
        if ok == KERN_SUCCESS {
            // Activity Monitor's "Memory Used": app memory (internal minus purgeable) + wired + compressed.
            let app = UInt64(max(0, Int64(vm.internal_page_count) - Int64(vm.purgeable_count)))
            compressed = UInt64(vm.compressor_page_count) * page
            used = app * page + UInt64(vm.wire_count) * page + compressed
        }
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let swapUsed = sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 ? swap.xsu_used : 0
        return (used, compressed, swapUsed)
    }

    nonisolated static func pressure() -> Int {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 ? Int(level) : 1
    }

    nonisolated static func bootTime() -> Date {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return Date() }
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
    }

    // MARK: - Simulators and launchd

    nonisolated static func bootedSims(launchd: [Sample.Proc], args: [pid_t: [String]]) async -> [Sample.Sim] {
        // launchd_sim's one argument is …/Devices/UDID/data/var/run/launchd_bootstrap.plist
        var pidByUDID: [String: pid_t] = [:]
        for p in launchd {
            for a in args[p.pid] ?? [] {
                let parts = a.components(separatedBy: "/")
                if let i = parts.firstIndex(of: "Devices"), i + 1 < parts.count { pidByUDID[parts[i + 1]] = p.pid }
            }
        }
        guard let out = await Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "booted", "-j"], timeout: 15),
              out.status == 0, let data = out.out.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else { return [] }
        let iso = ISO8601DateFormatter()
        var sims: [Sample.Sim] = []
        for (runtimeID, list) in devices {
            // com.apple.CoreSimulator.SimRuntime.iOS-26-5 → "iOS 26.5"
            let tail = runtimeID.components(separatedBy: ".").last ?? runtimeID
            let bits = tail.components(separatedBy: "-")
            let runtime = bits.count >= 2 ? "\(bits[0]) \(bits.dropFirst().joined(separator: "."))" : tail
            for d in list {
                guard let udid = d["udid"] as? String, (d["state"] as? String) == "Booted" else { continue }
                sims.append(Sample.Sim(udid: udid, name: d["name"] as? String ?? "iPhone", runtime: runtime,
                                       launchdPid: pidByUDID[udid], lastUsed: (d["lastUsedAt"] as? String).flatMap { iso.date(from: $0) }))
            }
        }
        return sims.sorted { $0.name < $1.name }
    }

    /// Our launchd jobs that are running right now: pid to label. Rows are "PID\tStatus\tLabel".
    nonisolated static func jobs() async -> [pid_t: String] {
        guard let out = await Shell.run("/bin/launchctl", ["list"], timeout: 10), out.status == 0 else { return [:] }
        var jobs: [pid_t: String] = [:]
        for line in out.out.split(separator: "\n").dropFirst() {
            let cols = line.split(separator: "\t")
            if cols.count == 3, let pid = pid_t(cols[0]) { jobs[pid] = String(cols[2]) }
        }
        return jobs
    }
}

/// Runs a system tool with a timeout and returns what it printed. Never throws; nil means it could not start.
enum Shell {
    struct Result: Sendable {
        let status: Int32
        let out: String
    }

    private final class Box: @unchecked Sendable {
        let process = Process()
    }

    static func run(_ path: String, _ args: [String], timeout: TimeInterval, env: [String: String] = [:]) async -> Result? {
        let box = Box()
        let process = box.process
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        if !env.isEmpty { process.environment = ProcessInfo.processInfo.environment.merging(env) { $1 } }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let handle = pipe.fileHandleForReading
        let reader = Task.detached { handle.readDataToEndOfFile() }
        var started = true
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in c.resume() }
            do { try process.run() } catch { started = false; c.resume() }
        }
        guard started else { reader.cancel(); return nil }
        let timer = Task.detached {
            try? await Task.sleep(for: .seconds(timeout))
            if box.process.isRunning { box.process.terminate() }
        }
        let data = await reader.value
        timer.cancel()
        return Result(status: process.terminationStatus, out: String(decoding: data, as: UTF8.self))
    }
}
