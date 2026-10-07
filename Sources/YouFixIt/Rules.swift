import Foundation

/// Pure functions from samples to findings. Nothing here touches the Mac.
enum Rules {
    static let simGUIBundles: Set<String> = ["com.apple.dt.Devices", "com.apple.iphonesimulator"]
    /// Processes that drive simulators. Freshly started, or busy, means a build or test is going on.
    static let simDrivers: Set<String> = [
        "Xcode", "xcodebuild", "xctest", "xctrace", "simctl", "xcrun", "claude-ios-sim", "Simulator", "DevicesTrampoline",
        "SimRenderServer", "SimStreamProcessorService", "SimMetalHost", "SimAudioProcessorService",
    ]
    static let devServers: Set<String> = ["node", "bun", "deno"]
    static let otherLeftovers: Set<String> = ["python", "python3", "ruby", "java", "php"]
    static let chromeFamily: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "com.brave.Browser",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "org.chromium.Chromium",
    ]
    static let tempProfileDirs = ["/private/tmp/", "/tmp/", "/var/folders/", "/private/var/folders/"]
    /// Virtual machine apps that may be quit when their Docker socket says nothing runs inside.
    static let vmActionable: Set<String> = ["com.docker.docker", "dev.kdrag0n.MacVirt"]
    /// Virtual machine apps that are only explained: a guest may hold unsaved state.
    static let vmExplain: Set<String> = ["com.parallels.desktop.console", "com.vmware.fusion", "com.utmapp.UTM", "org.virtualbox.app.VirtualBox"]
    static let brewPrefixes = ["/opt/homebrew/", "/usr/local/Cellar/", "/usr/local/opt/"]

    static func findings(history: [Sample], disk: DiskScan?, keep: Set<String>, tuning: Tuning) -> [Finding] {
        guard let s = history.last else { return [] }
        var out: [Finding] = []
        out += idleSimulators(s, history, tuning)
        out += idleApps(s, history, keep: keep, tuning)
        out += idleVMs(s, history, keep: keep, tuning)
        out += devServers(s, history, tuning)
        out += testBrowsers(s, history, tuning)
        if let disk { out += space(disk, s, tuning) }
        out += insights(s, history, tuning)
        return out.filter { !keep.contains($0.keepKey) }
    }

    // MARK: - Windows over the history

    /// Samples from the last `seconds`, oldest first.
    static func window(_ h: [Sample], _ seconds: TimeInterval) -> [Sample] {
        guard let now = h.last?.at else { return [] }
        return h.filter { now.timeIntervalSince($0.at) <= seconds }
    }

    /// The history covers (most of) the last `seconds`, so idle judgements rest on real observation.
    static func spans(_ h: [Sample], _ seconds: TimeInterval) -> Bool {
        guard let first = h.first, let last = h.last else { return false }
        return last.at.timeIntervalSince(first.at) >= seconds * 0.75
    }

    /// Average CPU of a process tree (fraction of one core) over the last `seconds`.
    static func avgCPU(_ pid: pid_t, _ h: [Sample], _ seconds: TimeInterval) -> Double {
        let w = window(h, seconds)
        guard !w.isEmpty else { return 0 }
        return w.reduce(0) { $0 + $1.cpu(of: pid) } / Double(w.count)
    }

    /// The busiest moment of a process tree in the last `seconds`.
    static func maxCPU(_ pid: pid_t, _ h: [Sample], _ seconds: TimeInterval) -> Double {
        window(h, seconds).map { $0.cpu(of: pid) }.max() ?? 0
    }

    /// Disk traffic of a process tree, bytes per second, over the last `seconds`.
    static func ioRate(_ pid: pid_t, _ h: [Sample], _ seconds: TimeInterval) -> Double {
        let w = window(h, seconds)
        guard let first = w.first, let last = w.last, last.at > first.at else { return 0 }
        let a = first.io(of: pid), b = last.io(of: pid)
        return b > a ? Double(b - a) / last.at.timeIntervalSince(first.at) : 0
    }

    /// Average CPU of every process with one of these names, summed.
    static func avgCPU(named names: Set<String>, _ h: [Sample], _ seconds: TimeInterval) -> Double {
        let w = window(h, seconds)
        guard !w.isEmpty else { return 0 }
        let total = w.reduce(0.0) { sum, s in sum + s.procs.values.filter { names.contains($0.name) }.reduce(0) { $0 + $1.cpu } }
        return total / Double(w.count)
    }

    /// Every sample in the last `seconds` passes the test, and the window really spans that long.
    static func held(_ h: [Sample], _ seconds: TimeInterval, _ test: (Sample) -> Bool) -> Bool {
        let w = window(h, seconds)
        guard spans(w, seconds) else { return false }
        return w.allSatisfy(test)
    }

    // MARK: - Running now

    /// R1: a booted simulator nothing is using.
    static func idleSimulators(_ s: Sample, _ h: [Sample], _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return s.sims.compactMap { sim in
            guard let pid = sim.launchdPid, let root = s.procs[pid] else { return nil }
            let tree = s.tree(pid)
            guard s.at.timeIntervalSince(root.start) >= t.idle,
                  tree.allSatisfy({ s.at.timeIntervalSince($0.start) >= t.idle }),
                  avgCPU(pid, h, t.idle) < 0.05, maxCPU(pid, h, 60) < 0.2 else { return nil }
            for app in s.apps where simGUIBundles.contains(app.bundleID) {
                if app.active { return nil }
                if app.windows > 0, let last = app.lastActivated, s.at.timeIntervalSince(last) < 600 { return nil }
            }
            for p in s.procs.values where simDrivers.contains(p.name) {
                if s.at.timeIntervalSince(p.start) < t.idle { return nil }
                if avgCPU(p.pid, h, t.idle) >= 0.01 { return nil }
            }
            return Finding(id: "sim:\(sim.udid)", keepKey: sim.udid, group: .running, name: sim.name,
                           why: Copy.whyIdleSim(runtime: sim.runtime, since: tree.map(\.start).max()), bytes: s.footprint(of: pid),
                           action: .shutdownSim(udid: sim.udid), undoLabel: Copy.bootAgain, link: nil, iconPath: nil, symbol: "iphone")
        }
    }

    /// R2: a Dock app untouched for an hour, with no window on screen, holding real memory and doing nothing.
    static func idleApps(_ s: Sample, _ h: [Sample], keep: Set<String>, _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return s.apps.filter(\.regular).compactMap { app in
            guard let p = s.procs[app.pid], Safety.refusal(p, app: app, in: s, history: h, keep: keep, tuning: t) == nil,
                  let last = app.lastActivated, s.at.timeIntervalSince(last) >= t.appIdle,
                  app.hidden || app.windows == 0 else { return nil }
            let bytes = s.footprint(of: app.pid)
            // Quiet in every way: enough memory to matter, no CPU, no disk traffic. An app that is working is never a row.
            guard bytes >= t.appMin, avgCPU(app.pid, h, t.idle) < 0.05, maxCPU(app.pid, h, 60) < 0.5,
                  ioRate(app.pid, h, t.idle) < t.busyIO else { return nil }
            return Finding(id: "app:\(app.bundleID)", keepKey: app.bundleID, group: .running, name: app.name, why: Copy.whyIdleApp(since: last), bytes: bytes,
                           action: .quitApp(pid: app.pid, bundleID: app.bundleID, url: app.url), undoLabel: Copy.reopen,
                           link: nil, iconPath: app.url?.path, symbol: "app")
        }
    }

    /// R5: Docker Desktop or OrbStack with no containers, untouched for an hour. Quitting stops the virtual machine.
    static func idleVMs(_ s: Sample, _ h: [Sample], keep: Set<String>, _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return s.apps.filter { vmActionable.contains($0.bundleID) }.compactMap { app in
            guard let p = s.procs[app.pid], s.containersIdle[app.bundleID] == true,
                  Safety.refusal(p, app: app, in: s, history: h, keep: keep, tuning: t) == nil,
                  let launched = app.launched, s.at.timeIntervalSince(launched) >= t.appIdle,
                  avgCPU(app.pid, h, t.idle) < 0.03 else { return nil }
            var bytes = s.footprint(of: app.pid)
            if app.bundleID == "dev.kdrag0n.MacVirt" {
                // OrbStack's machine is a launchd agent, not a child of the app.
                bytes += s.procs.values.filter { $0.uid == Sampler.me && $0.ppid == 1 && $0.name == "OrbStack Helper" }
                    .reduce(0) { $0 + s.footprint(of: $1.pid) }
            }
            return Finding(id: "vm:\(app.bundleID)", keepKey: app.bundleID, group: .running, name: app.name, why: Copy.whyIdleVM, bytes: bytes,
                           action: .quitApp(pid: app.pid, bundleID: app.bundleID, url: app.url), undoLabel: Copy.reopen,
                           link: nil, iconPath: app.url?.path, symbol: "shippingbox.circle")
        }
    }

    /// Our own processes that launchd adopted: parent pid 1, not an app, not a launchd job, not inside a bundle.
    static func orphans(_ s: Sample) -> [Sample.Proc] {
        s.procs.values.filter { p in
            p.uid == Sampler.me && p.ppid == 1 && s.app(p.pid) == nil && !s.managedPids.contains(p.pid)
                && !Safety.neverPaths.contains(where: { p.path.hasPrefix($0) }) && !p.path.contains(".app/")
        }
    }

    /// R3: a node/bun/deno server nobody owns any more, and nothing is connected to.
    static func devServers(_ s: Sample, _ h: [Sample], _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return orphans(s).filter { devServers.contains($0.name) }.compactMap { p in
            let tree = s.tree(p.pid)
            guard tree.contains(where: { s.listening.contains($0.pid) }),
                  !tree.contains(where: { (s.established[$0.pid] ?? 0) > 0 }),
                  s.at.timeIntervalSince(p.start) >= 900, avgCPU(p.pid, h, t.idle) < 0.02 else { return nil }
            let bytes = s.footprint(of: p.pid)
            guard bytes >= 150 << 20 else { return nil }
            return Finding(id: "orphan:\(p.pid):\(Int(p.start.timeIntervalSince1970))", keepKey: p.path, group: .running,
                           name: command(s.args[p.pid], fallback: p.name), why: Copy.whyDevServer, bytes: bytes,
                           action: .sigterm(pid: p.pid, start: p.start), undoLabel: nil, link: nil, iconPath: nil, symbol: "terminal")
        }
    }

    /// "node …/.bin/expo start --port 8081" reads as "expo start".
    static func command(_ args: [String]?, fallback: String) -> String {
        guard let args, args.count > 1 else { return fallback }
        let script = (args[1] as NSString).lastPathComponent
        let verb = args.dropFirst(2).first.flatMap { $0.hasPrefix("-") ? nil : $0 }
        return [script, verb].compactMap { $0 }.joined(separator: " ")
    }

    static func isHeadless(_ a: [String]) -> Bool {
        a.contains { $0.hasPrefix("--headless") || $0.hasPrefix("--remote-debugging-port") }
    }

    static func hasTempProfile(_ a: [String]) -> Bool {
        a.contains { arg in
            guard arg.hasPrefix("--user-data-dir=") else { return false }
            let dir = String(arg.dropFirst("--user-data-dir=".count))
            return tempProfileDirs.contains { dir.hasPrefix($0) }
        }
    }

    /// R4: a headless browser a script started and forgot. It holds no tabs of the user's.
    static func testBrowsers(_ s: Sample, _ h: [Sample], _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return s.procs.values.filter { $0.uid == Sampler.me && $0.ppid == 1 && Sampler.browserNames.contains($0.name) }.compactMap { p in
            guard let args = s.args[p.pid], isHeadless(args), hasTempProfile(args) else { return nil }
            // Headless Chrome still registers hidden windows with the window server; only being active counts.
            if let app = s.app(p.pid), app.active { return nil }
            guard s.at.timeIntervalSince(p.start) >= 900, avgCPU(p.pid, h, t.idle) < 0.02 else { return nil }
            return Finding(id: "browser:\(p.pid):\(Int(p.start.timeIntervalSince1970))", keepKey: "headless:\(p.path)", group: .running, name: "\(p.name) (test copy)",
                           why: Copy.whyTestBrowser, bytes: s.footprint(of: p.pid), action: .sigterm(pid: p.pid, start: p.start),
                           undoLabel: nil, link: nil, iconPath: nil, symbol: "globe")
        }
    }

    // MARK: - Taking up space

    static func space(_ d: DiskScan, _ s: Sample, _ t: Tuning) -> [Finding] {
        let xcodeBusy = s.procs.values.contains { ["Xcode", "xcodebuild", "SWBBuildService", "XCBBuildService"].contains($0.name) }
        let simBooted = s.procs.values.contains { $0.name == "launchd_sim" }
        var out: [Finding] = []
        func row(_ item: DiskScan.Item, _ why: String, _ symbol: String) {
            out.append(Finding(id: "path:\(item.path)", keepKey: item.path, group: .space, name: item.name, why: why, bytes: item.bytes,
                               action: .trash(path: item.path), undoLabel: Copy.putBack, link: nil, iconPath: nil, symbol: symbol))
        }
        func know(_ id: String, _ item: DiskScan.Item, _ why: String, _ symbol: String, link: Finding.Link? = nil) {
            out.append(Finding(id: "know:\(id)", keepKey: "know:\(id)", group: .know, name: item.name, why: why, bytes: item.bytes, action: nil,
                               undoLabel: nil, link: link, iconPath: nil, symbol: symbol))
        }
        for item in d.items where item.bytes >= t.diskMin {
            switch item.kind {
            case .derivedData: if !xcodeBusy, !item.busy, item.bytes >= 1 << 30 { row(item, Copy.whyDerivedData(item.bytes), "hammer") }
            case .deviceSupport: if !xcodeBusy, !item.busy, item.bytes >= 1 << 30 { row(item, Copy.whyDeviceSupport, "iphone.and.arrow.forward") }
            case .previews: if !xcodeBusy, !item.busy { row(item, Copy.whyDerivedData(item.bytes), "eye") }
            case .simCache: if !simBooted, !item.busy { row(item, Copy.whyDevCache, "iphone") }
            case .devCache: if !item.busy { row(item, Copy.whyDevCache, "shippingbox") }
            case .otherCache: know("cache:\(item.path)", item, Copy.otherCache(item.bytes), "shippingbox")
            case .orphanCache:
                // A folder named after an app nothing runs from, and nothing wrote into for a month.
                let tail = item.name.components(separatedBy: ".").last ?? item.name
                let alive = tail.count >= 5 && s.procs.values.contains { ($0.path as NSString).lastPathComponent.range(of: tail, options: .caseInsensitive) != nil }
                if !item.busy, !alive { row(item, Copy.whyOrphanCache, "archivebox") }
            case .installer: row(item, Copy.whyInstaller(item.bytes), "arrow.down.circle")
            case .trash: know("trash", item, Copy.trashSize(item.bytes), "trash", link: Finding.Link(title: Copy.trashLink, url: "trash"))
            case .runtime: know("runtime:\(item.path)", item, Copy.oldRuntime(item.name, item.bytes), "iphone")
            case .oldDevice: know("device:\(item.path)", item, Copy.oldDevice(item.name, item.bytes), "iphone")
            }
        }
        if d.unavailableSims > 0 {
            out.append(Finding(id: "sims:unavailable", keepKey: "sims:unavailable", group: .space, name: "\(d.unavailableSims) unusable test \(d.unavailableSims == 1 ? "iPhone" : "iPhones")",
                               why: Copy.whyUnavailableSims, bytes: 0, action: .deleteUnavailableSims, undoLabel: nil, link: nil, iconPath: nil, symbol: "iphone.slash"))
        }
        if d.totalBytes > 0, d.freeBytes < min(d.totalBytes / 10, 20 << 30) {
            out.append(Finding(id: "know:disk", keepKey: "know:disk", group: .know, name: "Space", why: Copy.lowDisk(d.freeBytes), bytes: 0, action: nil,
                               undoLabel: nil, link: nil, iconPath: nil, symbol: "internaldrive"))
        }
        return out
    }

    // MARK: - Good to know

    static func insights(_ s: Sample, _ h: [Sample], _ t: Tuning) -> [Finding] {
        var out: [Finding] = []
        func know(_ id: String, _ name: String, _ why: String, _ symbol: String, link: Finding.Link? = nil, bytes: UInt64 = 0) {
            out.append(Finding(id: "know:\(id)", keepKey: "know:\(id)", group: .know, name: name, why: why, bytes: bytes, action: nil, undoLabel: nil,
                               link: link, iconPath: nil, symbol: symbol))
        }
        if avgCPU(named: ["mds_stores", "mds", "mdworker_shared", "mdworker"], h, 300) >= 0.2 {
            know("spotlight", "Spotlight", Copy.spotlight, "magnifyingglass",
                 link: Finding.Link(title: Copy.spotlightLink, url: "x-apple.systempreferences:com.apple.Spotlight-Settings.extension"))
        }
        if avgCPU(named: ["photoanalysisd", "mediaanalysisd"], h, 300) >= 0.2 { know("photos", "Photos", Copy.photos, "photo") }
        if avgCPU(named: ["backupd"], h, t.sustain) >= 0.1 { know("backup", "Time Machine", Copy.timeMachine, "clock.arrow.circlepath") }
        if avgCPU(named: ["softwareupdated", "nsurlsessiond"], h, t.sustain) >= 0.1 { know("update", "Software Update", Copy.update, "arrow.down.circle") }

        for app in s.apps {
            let renderers: [Sample.Proc]
            if chromeFamily.contains(app.bundleID) {
                renderers = s.tree(app.pid).filter { $0.name.hasSuffix("Helper (Renderer)") }
            } else if app.bundleID == "com.apple.Safari" {
                renderers = s.procs(named: "com.apple.WebKit.WebContent")
            } else { continue }
            let bytes = renderers.reduce(0) { $0 + $1.footprint }
            if renderers.count >= 25 || bytes >= 3 << 30 {
                know("tabs:\(app.bundleID)", app.name, Copy.tabs(app.name, renderers.count, bytes), "safari", bytes: bytes)
            }
        }

        let sessions = s.procs.values.filter { $0.path.hasSuffix("/claude.app/Contents/MacOS/claude") }
        let sessionBytes = sessions.reduce(0) { $0 + $1.footprint }
        if sessions.count >= 4 || sessionBytes >= 2 << 30 {
            know("claude", "Claude", Copy.claude(sessions.count, sessionBytes), "bubble.left.and.text.bubble.right", bytes: sessionBytes)
        }

        // G13: virtual machines that only get explained.
        for app in s.apps where vmExplain.contains(app.bundleID) {
            let bytes = s.footprint(of: app.pid)
            if bytes >= 1 << 30 { know("vm:\(app.bundleID)", app.name, Copy.vmApp(app.name, bytes), "desktopcomputer", bytes: bytes) }
        }

        // G14: Homebrew services. launchd started them, no app owns them, and they are not a dev server someone left behind.
        let services = s.procs.values.filter { p in
            p.uid == Sampler.me && brewPrefixes.contains(where: { p.path.hasPrefix($0) }) && !Sampler.serverNames.contains(p.name)
                && (s.root(of: p.pid).map { $0.ppid == 1 && s.app($0.pid) == nil } ?? false)
        }
        if !services.isEmpty {
            let roots = Set(services.compactMap { s.root(of: $0.pid)?.pid })
            let bytes = roots.reduce(0) { $0 + s.footprint(of: $1) }
            if bytes >= 200 << 20 {
                know("brew", "Homebrew services", Copy.brewServices(Array(Set(services.map(\.name))).sorted(), bytes), "server.rack", bytes: bytes)
            }
        }

        // G15: menu bar apps, which the idle-app rule never looks at.
        let bar = s.apps.filter { app in
            app.accessory && app.bundleID != "com.freeman.youfixit" && !vmActionable.contains(app.bundleID) && !vmExplain.contains(app.bundleID)
                && (app.url.map { !$0.path.hasPrefix("/System/") } ?? false)
        }.map { ($0.name, s.footprint(of: $0.pid)) }.sorted { $0.1 > $1.1 }
        let barBytes = bar.reduce(0) { $0 + $1.1 }
        if barBytes >= 1536 << 20 {
            know("menubar", "Menu bar apps", Copy.menuBarApps(bar.prefix(3).map(\.0), barBytes), "menubar.rectangle", bytes: barBytes)
        }

        // G16: the busiest thing in the background, once it has been at it for a while. The app in front is expected to work.
        let frontRoot = s.root(of: s.frontmost)?.pid
        let roots = s.procs.values.filter { p in
            p.uid == Sampler.me && (s.procs[p.ppid].map { $0.uid != Sampler.me } ?? true)
                && p.pid != frontRoot && p.name != "launchd_sim" && !Safety.neverNames.contains(p.name)
        }
        if spans(window(h, t.sustain), t.sustain),
           let busiest = roots.map({ ($0, avgCPU($0.pid, h, t.sustain)) }).max(by: { $0.1 < $1.1 }), busiest.1 >= 0.5 {
            let p = busiest.0
            let name = s.app(p.pid)?.name ?? command(s.args[p.pid], fallback: p.name)
            know("busy:\(p.pid)", name, Copy.busyProgram(name), "gauge.with.needle", bytes: s.footprint(of: p.pid))
        }

        if held(h, 60, { $0.pressure >= 2 }) || s.compressed >= s.memTotal / 4 || s.swapUsed >= 2 << 30 {
            know("memory", "Memory", Copy.memorySqueeze, "memorychip")
        }
        if held(h, t.sustain, { $0.load1 / Double(max(1, $0.cores)) > 2 && $0.cpuBusy < 0.6 }) {
            know("backlog", "Waiting programs", Copy.backlog, "hourglass")
        }
        if avgCPU(named: ["WindowServer"], h, t.sustain) >= 0.3 { know("windowserver", "Windows", Copy.drawing, "macwindow.on.rectangle") }
        if s.thermal >= 2 { know("thermal", "Temperature", Copy.warm, "thermometer.medium") }

        if let login = s.loggedIn {
            let n = s.apps.filter { app in
                app.regular && (app.launched.map { $0.timeIntervalSince(login) >= -5 && $0.timeIntervalSince(login) <= 120 } ?? false)
            }.count
            if n >= 8 {
                know("login", "Login Items", Copy.loginLaunches(n), "power",
                     link: Finding.Link(title: Copy.loginLink, url: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"))
            }
        }
        if s.uptime >= 14 * 86_400, s.swapUsed >= 1 << 30 { know("uptime", "Restart", Copy.longUptime(Int(s.uptime / 86_400)), "restart") }

        for p in orphans(s) where otherLeftovers.contains(p.name) {
            let bytes = s.footprint(of: p.pid)
            guard bytes >= 150 << 20, s.at.timeIntervalSince(p.start) >= 900 else { continue }
            know("leftover:\(p.pid)", command(s.args[p.pid], fallback: p.name), Copy.otherLeftover(p.name, bytes), "terminal", bytes: bytes)
        }
        // G17: node leftovers R3 will not touch: watchers with no listener, and servers something is still connected to.
        for p in orphans(s) where devServers.contains(p.name) {
            let tree = s.tree(p.pid)
            let bytes = s.footprint(of: p.pid)
            guard bytes >= 150 << 20, s.at.timeIntervalSince(p.start) >= 900 else { continue }
            let listens = tree.contains { s.listening.contains($0.pid) }
            let connected = tree.contains { (s.established[$0.pid] ?? 0) > 0 }
            if !listens {
                know("leftover-watcher:\(p.pid)", command(s.args[p.pid], fallback: p.name), Copy.leftoverWatcher(bytes), "terminal", bytes: bytes)
            } else if connected {
                know("leftover-server:\(p.pid)", command(s.args[p.pid], fallback: p.name), Copy.connectedServer, "terminal", bytes: bytes)
            }
        }
        for p in s.procs.values where p.uid == Sampler.me && p.ppid != 1 && Sampler.browserNames.contains(p.name) {
            guard let args = s.args[p.pid], isHeadless(args), s.footprint(of: p.pid) >= 300 << 20 else { continue }
            know("testbrowser:\(p.pid)", "\(p.name) (test copy)", Copy.liveTestBrowser, "globe", bytes: s.footprint(of: p.pid))
        }
        return out
    }
}

/// Sustained trouble, with hysteresis so one busy moment never nags.
struct Spike: Sendable {
    private(set) var active = false
    private var clearSince: Date?

    /// Returns true on the sample that turns the spike on.
    mutating func update(_ h: [Sample], tuning t: Tuning) -> Bool {
        guard let s = h.last else { return false }
        let pressure = Rules.held(h, 60) { $0.pressure >= 2 }
        let backlog = Rules.held(h, t.sustain) { $0.load1 / Double(max(1, $0.cores)) > 2 }
        let hog = s.apps.contains { app in
            app.regular && !app.active && app.pid != s.frontmost && !Safety.essential(app.bundleID)
                && Rules.held(h, t.sustain) { $0.cpu(of: app.pid) > 1.0 }
        }
        if pressure || backlog || hog {
            clearSince = nil
            if !active { active = true; return true }
        } else if active {
            if clearSince == nil { clearSince = s.at }
            if let since = clearSince, s.at.timeIntervalSince(since) >= 300 { active = false; clearSince = nil }
        }
        return false
    }
}
