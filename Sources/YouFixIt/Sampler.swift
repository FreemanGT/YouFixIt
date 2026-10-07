import CoreAudio
import CoreGraphics
import Darwin
import Foundation

/// Reads the whole machine into a `Sample`. Lives off the main actor; AppKit facts arrive as `AppSeed`s.
actor Sampler {
    private var prevTicks: [pid_t: (start: TimeInterval, ticks: UInt64)] = [:]
    private var prevMach: UInt64 = 0
    private var prevCPU: host_cpu_load_info_data_t?
    private var pathCache: [pid_t: (start: TimeInterval, path: String)] = [:]
    private var simCache: (at: Date, sims: [Sample.Sim])?

    static let me = getuid()
    /// Names whose orphans may be dev servers (R3) or other leftovers (G12).
    static let serverNames: Set<String> = ["node", "bun", "deno", "python", "python3", "ruby", "java", "php"]
    static let browserNames: Set<String> = ["Google Chrome", "Google Chrome Beta", "Google Chrome Canary", "Chromium", "Brave Browser", "Microsoft Edge", "chrome-headless-shell"]

    func take(apps seeds: [AppSeed], frontmost: pid_t) async -> Sample {
        let now = Date()
        let mach = mach_absolute_time()
        let deltaMach = prevMach == 0 ? 0 : Double(mach &- prevMach)

        // 1. Every process: parent, owner, start time, CPU ticks, memory.
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
            if bsd.pbi_uid == Self.me, let fp = Self.footprint(pid) { footprint = fp }
            let ppid = pid_t(bsd.pbi_ppid)
            procs[pid] = Sample.Proc(pid: pid, ppid: ppid, uid: bsd.pbi_uid, name: name, path: path,
                                     start: Date(timeIntervalSince1970: start), cpu: cpu, footprint: footprint)
            children[ppid, default: []].append(pid)
        }
        prevTicks = ticksNow
        prevMach = mach
        pathCache = pathCache.filter { procs[$0.key]?.start.timeIntervalSince1970 == $0.value.start }

        // 2. Windows and audio, then the apps.
        let win = Self.windows()
        let audio = Self.audioPids()
        let apps = seeds.map { s in
            Sample.App(pid: s.pid, bundleID: s.bundleID, name: s.name, url: s.url, regular: s.regular, hidden: s.hidden,
                       active: s.active, launched: s.launched, lastActivated: s.lastActivated,
                       windows: win.normal[s.pid] ?? 0, hasModal: win.modal.contains(s.pid), audio: audio.contains(s.pid))
        }
        let appPids = Set(seeds.map(\.pid))

        // 3. Arguments and sockets, only for our own parent-pid-1 processes (orphans, launchd_sim, headless browsers).
        var args: [pid_t: [String]] = [:]
        var listening = Set<pid_t>()
        var orphanCandidates = false
        for p in procs.values where p.uid == Self.me {
            let browser = Self.browserNames.contains(p.name)
            guard p.ppid == 1 || browser else { continue }
            if p.name == "launchd_sim" || Self.serverNames.contains(p.name) || browser { args[p.pid] = Self.args(p.pid) }
            if p.ppid == 1, Self.serverNames.contains(p.name), !appPids.contains(p.pid) {
                orphanCandidates = true
                // The listener is often a child (npm exec → node), so look through the whole tree.
                var queue = [p.pid]
                while let pid = queue.popLast() {
                    if let q = procs[pid], Self.serverNames.contains(q.name), Self.listens(pid) { listening.insert(pid) }
                    queue.append(contentsOf: children[pid] ?? [])
                }
            }
            if p.ppid == 1, browser { orphanCandidates = true }
        }

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
        var managed = Set<pid_t>()
        if orphanCandidates { managed = await Self.managedPids() }

        // 5. The machine.
        let cpuBusy = systemCPU()
        let mem = Self.memory()
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        let login = procs.values.first { $0.name == "loginwindow" && $0.uid == Self.me }?.start
        let front = procs[frontmost]
        let fullscreen = front.map { win.fullscreen.contains($0.pid) } ?? false

        return Sample(at: now, procs: procs, children: children, apps: apps, sims: sims, managedPids: managed, args: args,
                      listening: listening, frontmost: frontmost, fullscreen: fullscreen, cpuBusy: cpuBusy, load1: load[0],
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
        var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let len = Int(proc_pidpath(pid, &buf, UInt32(buf.count)))
        let path = len > 0 ? String(decoding: buf.prefix(len).map { UInt8(bitPattern: $0) }, as: UTF8.self) : ""
        pathCache[pid] = (start, path)
        return path
    }

    nonisolated static func shortName(_ bsd: inout proc_bsdinfo) -> String {
        withUnsafePointer(to: &bsd.pbi_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) * 2 + 1) { String(cString: $0) }
        }
    }

    nonisolated static func footprint(_ pid: pid_t) -> UInt64? {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { p in
            p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        return ok == 0 ? info.ri_phys_footprint : nil
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

    /// True when the process has a TCP socket in LISTEN state (a server of some kind).
    nonisolated static func listens(_ pid: pid_t) -> Bool {
        let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bytes > 0 else { return false }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bytes) / MemoryLayout<proc_fdinfo>.size + 16)
        let got = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, Int32(fds.count * MemoryLayout<proc_fdinfo>.size))
        guard got > 0 else { return false }
        for fd in fds.prefix(Int(got) / MemoryLayout<proc_fdinfo>.size) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var si = socket_fdinfo()
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &si, Int32(MemoryLayout<socket_fdinfo>.size)) > 0 else { continue }
            if si.psi.soi_kind == SOCKINFO_TCP, si.psi.soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN { return true }
        }
        return false
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

    nonisolated static func managedPids() async -> Set<pid_t> {
        guard let out = await Shell.run("/bin/launchctl", ["list"], timeout: 10), out.status == 0 else { return [] }
        var pids = Set<pid_t>()
        for line in out.out.split(separator: "\n").dropFirst() {
            if let first = line.split(separator: "\t").first, let pid = pid_t(first) { pids.insert(pid) }
        }
        return pids
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

    static func run(_ path: String, _ args: [String], timeout: TimeInterval) async -> Result? {
        let box = Box()
        let process = box.process
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
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
