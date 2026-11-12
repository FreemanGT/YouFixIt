import Foundation

/// Pure functions from samples to findings. Nothing here touches the Mac.
enum Rules {
    static let simGUIBundles: Set<String> = ["com.apple.dt.Devices", "com.apple.iphonesimulator"]
    /// Processes that drive simulators. Freshly started, or busy, means a build or test is going on.
    static let simDrivers: Set<String> = [
        "Xcode", "xcodebuild", "xctest", "xctrace", "simctl", "xcrun", "claude-ios-sim", "Simulator", "DevicesTrampoline",
        "SimRenderServer", "SimStreamProcessorService", "SimMetalHost", "SimAudioProcessorService",
    ]
    /// Interpreters whose orphaned trees that listen, with nobody connected, are leftover dev servers (R3).
    static let devServers: Set<String> = ["node", "bun", "deno", "php", "python", "python3", "ruby"]
    /// Orphans of these that R3 does not take are explained, with a Stop button (G12, G17).
    static let leftoverNames: Set<String> = ["node", "bun", "deno", "php", "python", "python3", "ruby", "java"]
    static let chromeFamily: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "com.brave.Browser",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "org.chromium.Chromium",
    ]
    static let tempProfileDirs = ["/private/tmp/", "/tmp/", "/var/folders/", "/private/var/folders/"]
    /// Virtual machine apps that may be quit when their Docker socket says nothing runs inside.
    static let vmActionable: Set<String> = ["com.docker.docker", "dev.kdrag0n.MacVirt"]
    /// Virtual machine apps that are only explained: a guest may hold unsaved state.
    static let vmExplain: Set<String> = ["com.parallels.desktop.console", "com.vmware.fusion", "com.utmapp.UTM", "org.virtualbox.app.VirtualBox"]
    /// Build daemons that come back on the next build (B4): the class in their arguments, and what people call them.
    static let buildDaemons: [(marker: String, name: String)] = [("GradleDaemon", "Gradle daemon"), ("KotlinCompileDaemon", "Kotlin daemon")]
    /// Power assertions that keep the whole Mac awake, not just the display.
    static let sleepTypes: Set<String> = ["PreventUserIdleSystemSleep", "PreventSystemSleep", "NoIdleSleepAssertion"]
    /// Tails of a path that say nothing about whose it is.
    static let genericFolders: Set<String> = ["mysql", "postgres", "postgresql", "redis", "data", "db", "database", "var", "etc", "conf", "config", "run", "tmp",
                                              "source", "src", "public", "www", "htdocs", "dist"]

    /// A link that brings a running app to the front (LaunchServices activates it; our own window closes).
    static func show(_ app: Sample.App) -> Finding.Link? {
        app.url.map { Finding.Link(title: Copy.showApp(app.name), url: $0.absoluteString) }
    }
    static let activityMonitor = Finding.Link(title: Copy.activityMonitorLink,
                                              url: URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app").absoluteString)

    /// The formula of a Homebrew service: a launchd job with a Homebrew label whose tree runs a Homebrew binary (mysql's
    /// job root is its mysqld_safe shell wrapper; the server is the child).
    static func service(_ root: Sample.Proc, in s: Sample) -> String? {
        guard let label = s.jobs[root.pid], let prefix = Sampler.brewLabels.first(where: { label.hasPrefix($0) }),
              s.tree(root.pid).contains(where: { p in Sampler.brewPrefixes.contains(where: { p.path.hasPrefix($0) }) }) else { return nil }
        return String(label.dropFirst(prefix.count))
    }

    /// `trashed` is what YouFixIt itself moved to the Trash lately, for when the Trash cannot be measured directly.
    static func findings(history: [Sample], disk: DiskScan?, keep: Set<String>, tuning: Tuning, trashed: UInt64 = 0) -> [Finding] {
        guard let s = history.last else { return [] }
        var out: [Finding] = []
        out += idleSimulators(s, history, tuning)
        out += idleApps(s, history, keep: keep, tuning)
        out += idleVMs(s, history, keep: keep, tuning)
        out += services(s, history, tuning)
        out += devServers(s, history, keep: keep, tuning)
        out += daemons(s, history, tuning)
        out += testBrowsers(s, history, tuning)
        out += databases(s, history, tuning)
        if let disk { out += space(disk, s, tuning) }
        out += trashLedger(disk, trashed: trashed)
        // A process with a row already is not explained a second time.
        let covered = Set(out.flatMap { f -> [pid_t] in
            switch f.action {
            case .sigterm(let pid, _), .stopService(_, let pid, _), .quitApp(let pid, _, _): [pid]
            case .sigtermAll(let targets): targets.map(\.pid)
            default: []
            }
        })
        out += insights(s, history, tuning, covered: covered)
        let kept = out.filter { !keep.contains($0.keepKey) }
        // Good to know reads biggest first. 100 MB buckets keep rows from swapping places as memory wobbles between samples.
        let know = kept.filter { $0.group == .know }.sorted { a, b in
            let (x, y) = (a.bytes / (100 << 20), b.bytes / (100 << 20))
            return x != y ? x > y : a.id < b.id
        }
        return kept.filter { $0.group != .know } + know
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

    // MARK: - Names and places

    /// A folder as people know it: a Claude worktree reads as its project, a generic tail (mysql, data) as what holds it.
    /// nil for places that name nobody's project ("/", the home folder).
    static func project(_ path: String) -> String? {
        var parts = path.split(separator: "/").map(String.init)
        if let i = parts.firstIndex(of: ".claude"), i > 0, parts.indices.contains(i + 1), parts[i + 1] == "worktrees" { return parts[i - 1] }
        while let last = parts.last, genericFolders.contains(last.lowercased()) { parts.removeLast() }
        guard parts.count > 2 else { return nil }
        return parts.last
    }

    /// A php server's document root, made whole against its working directory ("-t stores/kli/source" is relative).
    static func docroot(_ p: Sample.Proc, in s: Sample) -> String? {
        let args = s.args[p.pid] ?? []
        guard args.contains("-S"), let i = args.firstIndex(of: "-t"), args.indices.contains(i + 1) else { return nil }
        let root = args[i + 1]
        if root.hasPrefix("/") { return root }
        return s.cwd[p.pid].map { ($0 as NSString).appendingPathComponent(root) } ?? root
    }

    /// Where a leftover came from: a php server's document root, a database's data folder, else its working directory.
    static func place(of p: Sample.Proc, in s: Sample) -> String? {
        let args = s.args[p.pid] ?? []
        if let root = docroot(p, in: s) { return project(root) }
        for a in args {
            for key in ["--defaults-file=", "--datadir=", "--dbpath=", "--dir="] where a.hasPrefix(key) {
                let value = String(a.dropFirst(key.count))
                return project(key == "--defaults-file=" ? (value as NSString).deletingLastPathComponent : value)
            }
        }
        if let i = args.firstIndex(of: "-D"), args.indices.contains(i + 1) { return project(args[i + 1]) }
        return s.cwd[p.pid].flatMap(project)
    }

    /// What Keep remembers for a leftover: where it runs, so one project's server is kept rather than every node.
    static func serverKey(_ p: Sample.Proc, in s: Sample) -> String {
        if let root = docroot(p, in: s) { return "server:\(root)" }
        return "server:\(s.cwd[p.pid] ?? p.path)"
    }

    /// The TCP ports a process tree listens on, lowest first.
    static func ports(of tree: [Sample.Proc], in s: Sample) -> [Int] {
        Array(Set(tree.flatMap { s.ports[$0.pid] ?? [] })).sorted()
    }

    /// Jupyter keeps live kernels with unsaved work in them; it is never stopped on its own.
    static func notebook(_ args: [String]?) -> Bool {
        args?.contains { $0.contains("jupyter") || $0.contains("ipykernel") } ?? false
    }

    /// "npm exec next dev --port 3120" reads as "next dev", "php -S 127.0.0.1:8902 -t …" as "php -S :8902",
    /// "npm run dev" as itself; anything else as `command` names it.
    static func serverName(_ args: [String]?, fallback: String) -> String {
        // A tool that renames itself (npm sets its title) leaves one argument holding the whole line, then empty ones.
        guard var words = args?.filter({ !$0.isEmpty }), !words.isEmpty else { return fallback }
        if words.count == 1, words[0].contains(" ") { words = words[0].split(separator: " ").map(String.init) }
        if let i = words.firstIndex(of: "-S"), words.indices.contains(i + 1) {
            return "php -S :\(words[i + 1].split(separator: ":").last.map(String.init) ?? words[i + 1])"
        }
        let launchers: [String: String] = ["npm": "npm", "npm-cli.js": "npm", "pnpm": "pnpm", "pnpm.cjs": "pnpm", "yarn": "yarn", "yarn.js": "yarn",
                                           "npx": "npx", "npx-cli.js": "npx", "pnpx": "pnpx", "bunx": "bunx"]
        if let i = words.firstIndex(where: { launchers[($0 as NSString).lastPathComponent] != nil }),
           let launcher = launchers[(words[i] as NSString).lastPathComponent] {
            var rest = Array(words.dropFirst(i + 1).filter { !$0.hasPrefix("-") })
            if ["npx", "pnpx", "bunx"].contains(launcher) { rest.insert("exec", at: 0) }
            guard let verb = rest.first else { return launcher }
            switch verb {
            case "exec", "dlx", "x":
                let tool = rest.dropFirst().prefix(2).map { ($0 as NSString).lastPathComponent }
                return tool.isEmpty ? launcher : tool.joined(separator: " ")
            case "run", "run-script":
                return ([launcher, "run"] + rest.dropFirst().prefix(1)).joined(separator: " ")
            default:
                return "\(launcher) \(verb)"
            }
        }
        return command(words, fallback: fallback)
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
        return s.apps.filter { $0.regular && !$0.bundleID.isEmpty }.compactMap { app in
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

    /// R6: a Homebrew service launchd keeps alive since login, quiet and with nothing connected to it. Stopped through
    /// brew services, the one stop launchd does not undo on the spot (every Homebrew job has KeepAlive); Undo starts it again.
    /// launchd sends SIGTERM, SIGKILLs only a job that ignores it for 5 s, and SIGTERMs the rest of its process group:
    /// mysql behind its signal-ignoring mysqld_safe wrapper logged a clean shutdown this way (checked 2026-10-11).
    /// One that is in use is explained instead, with a Stop button for when the user knows better.
    static func services(_ s: Sample, _ h: [Sample], _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return s.procs.values.sorted { $0.pid < $1.pid }.compactMap { root in
            guard root.uid == Sampler.me, let formula = service(root, in: s), s.at.timeIntervalSince(root.start) >= t.idle else { return nil }
            let bytes = s.footprint(of: root.pid)
            guard bytes >= 150 << 20 else { return nil }
            let tree = s.tree(root.pid)
            // TCP clients only. A unix-socket client is invisible, but postgres forks a child per client, so a
            // child younger than the idle window counts as one; an idle unix client older than that is the known ceiling.
            let connected = tree.contains { (s.clients[$0.pid] ?? 0) > 0 }
                || tree.contains { $0.pid != root.pid && s.at.timeIntervalSince($0.start) < t.idle }
            let busy = avgCPU(root.pid, h, t.idle) >= 0.05 || maxCPU(root.pid, h, 60) >= 0.5 || ioRate(root.pid, h, t.idle) >= t.busyIO
            let stop = Finding.Action.stopService(formula: formula, pid: root.pid, start: root.start)
            if connected || busy {
                return Finding(id: "know:brew:\(formula)", keepKey: "brew:\(formula)", group: .know, name: formula,
                               why: connected ? Copy.serviceConnected : Copy.serviceBusy, bytes: bytes, action: stop, undoLabel: Copy.startAgain,
                               link: nil, iconPath: nil, symbol: "server.rack")
            }
            return Finding(id: "brew:\(formula)", keepKey: "brew:\(formula)", group: .running, name: formula, why: Copy.whyServiceIdle, bytes: bytes,
                           action: stop, undoLabel: Copy.startAgain, link: nil, iconPath: nil, symbol: "server.rack")
        }
    }

    /// Part of an app bundle, so it belongs to that app. Framework Python's Python.app is only how Python runs on a Mac.
    static func insideApp(_ path: String) -> Bool {
        path.contains(".app/") && !path.hasSuffix(Sampler.pythonApp)
    }

    /// Our own processes that launchd adopted: parent pid 1, not an app, not a launchd job, not inside a bundle.
    static func orphans(_ s: Sample) -> [Sample.Proc] {
        s.procs.values.filter { p in
            p.uid == Sampler.me && p.ppid == 1 && s.app(p.pid) == nil && s.jobs[p.pid] == nil
                && !Safety.neverPaths.contains(where: { p.path.hasPrefix($0) }) && !insideApp(p.path)
        }
    }

    /// R3: dev servers nobody owns any more and nobody is connected to. A big one is a row of its own; small ones,
    /// which add up (twenty php -S servers), share one row.
    static func devServers(_ s: Sample, _ h: [Sample], keep: Set<String>, _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        var out: [Finding] = []
        var small: [(proc: Sample.Proc, bytes: UInt64, ports: [Int])] = []
        for p in orphans(s).sorted(by: { $0.pid < $1.pid }) where devServers.contains(p.name) {
            let tree = s.tree(p.pid)
            guard tree.contains(where: { s.listening.contains($0.pid) }),
                  !tree.contains(where: { (s.clients[$0.pid] ?? 0) > 0 }),
                  !notebook(s.args[p.pid]), !keep.contains(serverKey(p, in: s)), !Safety.holdsTerminals(p, in: s),
                  s.at.timeIntervalSince(p.start) >= t.orphanAge, avgCPU(p.pid, h, t.idle) < 0.02 else { continue }
            let bytes = s.footprint(of: p.pid)
            let listened = ports(of: tree, in: s)
            if bytes >= 150 << 20 {
                out.append(Finding(id: "orphan:\(p.pid):\(Int(p.start.timeIntervalSince1970))", keepKey: serverKey(p, in: s), group: .running,
                                   name: serverName(s.args[p.pid], fallback: p.name), why: Copy.whyDevServer(port: listened.first, place: place(of: p, in: s)),
                                   bytes: bytes, action: .sigterm(pid: p.pid, start: p.start), undoLabel: nil, link: nil, iconPath: nil, symbol: "terminal"))
            } else if bytes >= 20 << 20 {
                small.append((p, bytes, listened))
            }
        }
        let total = small.reduce(0) { $0 + $1.bytes }
        if small.count >= 2, total >= 150 << 20 {
            let all = small.flatMap(\.ports).sorted()
            out.append(Finding(id: "orphans:small", keepKey: "orphans:small", group: .running, name: Copy.serverGroup(small.count),
                               why: Copy.whyServerGroup(low: all.first, high: all.last), bytes: total,
                               action: .sigtermAll(small.map { Finding.Target(pid: $0.proc.pid, start: $0.proc.start, bytes: $0.bytes) }),
                               undoLabel: nil, link: nil, iconPath: nil, symbol: "terminal"))
        }
        return out
    }

    /// B4: a Gradle or Kotlin build daemon left idle. The next build starts a fresh one.
    static func daemons(_ s: Sample, _ h: [Sample], _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return orphans(s).filter { $0.name == "java" }.sorted { $0.pid < $1.pid }.compactMap { p in
            guard let args = s.args[p.pid], let daemon = buildDaemons.first(where: { d in args.contains { $0.contains(d.marker) } }),
                  s.at.timeIntervalSince(p.start) >= t.idle, avgCPU(p.pid, h, t.idle) < 0.02, maxCPU(p.pid, h, 60) < 0.2,
                  !s.tree(p.pid).contains(where: { (s.clients[$0.pid] ?? 0) > 0 }) else { return nil }   // an IDE still talks to it
            let bytes = s.footprint(of: p.pid)
            guard bytes >= 150 << 20 else { return nil }
            return Finding(id: "daemon:\(p.pid):\(Int(p.start.timeIntervalSince1970))", keepKey: "daemon:\(daemon.marker)", group: .running,
                           name: daemon.name, why: Copy.whyDaemon(daemon.name), bytes: bytes, action: .sigterm(pid: p.pid, start: p.start),
                           undoLabel: nil, link: nil, iconPath: nil, symbol: "hammer")
        }
    }

    /// B3: a database a coding session started and left behind (orphaned, or behind an orphaned wrapper), quiet, with no
    /// TCP client. Unix-socket clients are invisible, so it is only offered, never selected. SIGTERM is each one's clean shutdown.
    static func databases(_ s: Sample, _ h: [Sample], _ t: Tuning) -> [Finding] {
        guard spans(h, t.idle) else { return [] }
        return s.procs.values.sorted { $0.pid < $1.pid }.compactMap { p in
            guard p.uid == Sampler.me, Sampler.dbNames.contains(p.name), s.procs[p.ppid]?.name != p.name,
                  let root = s.root(of: p.pid), root.ppid == 1, s.app(root.pid) == nil, s.jobs[root.pid] == nil,
                  !Safety.system(p.path), !insideApp(root.path), !insideApp(p.path),
                  s.at.timeIntervalSince(p.start) >= t.orphanAge, avgCPU(root.pid, h, t.idle) < 0.02,
                  !s.tree(root.pid).contains(where: { (s.clients[$0.pid] ?? 0) > 0 }) else { return nil }
            let bytes = s.footprint(of: root.pid)
            guard bytes >= 100 << 20 else { return nil }
            let home = place(of: p, in: s)
            return Finding(id: "know:db:\(p.pid):\(Int(p.start.timeIntervalSince1970))", keepKey: "db:\(home ?? p.path)", group: .know, name: p.name,
                           why: Copy.leftoverDatabase(place: home), bytes: bytes, action: .sigterm(pid: p.pid, start: p.start), undoLabel: nil,
                           link: nil, iconPath: nil, symbol: "cylinder.split.1x2")
        }
    }

    /// "node …/.bin/expo start --port 8081" reads as "expo start"; "node --liftoff-only …/codegraph.js" as "codegraph.js".
    static func command(_ args: [String]?, fallback: String) -> String {
        guard let args = args?.filter({ !$0.isEmpty }) else { return fallback }
        let rest = args.dropFirst()
        // Code given inline (node -e, python3 -c) is not a name; nor is anything after it.
        let inline: Set<String> = ["-e", "-c", "--eval", "-p", "--print"]
        let named = rest.prefix { !inline.contains($0) }
        // The script is the first path-like argument, else the first that is not a flag; an option's bare value can still win.
        guard let i = named.firstIndex(where: { !$0.hasPrefix("-") && ($0.contains("/") || $0.contains(".")) })
                ?? named.firstIndex(where: { !$0.hasPrefix("-") }) else { return fallback }
        let script = (args[i] as NSString).lastPathComponent
        let verb = args.dropFirst(i + 1).first.flatMap { $0.hasPrefix("-") ? nil : $0 }
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
            guard s.at.timeIntervalSince(p.start) >= t.orphanAge, avgCPU(p.pid, h, t.idle) < 0.02 else { return nil }
            return Finding(id: "browser:\(p.pid):\(Int(p.start.timeIntervalSince1970))", keepKey: "headless:\(p.path)", group: .running, name: Copy.testCopy(p.name),
                           why: Copy.whyTestBrowser, bytes: s.footprint(of: p.pid), action: .sigterm(pid: p.pid, start: p.start),
                           undoLabel: nil, link: nil, iconPath: nil, symbol: "globe")
        }
    }

    // MARK: - Taking up space

    static func space(_ d: DiskScan, _ s: Sample, _ t: Tuning) -> [Finding] {
        let xcodeBusy = s.procs.values.contains { ["Xcode", "xcodebuild", "SWBBuildService", "XCBBuildService"].contains($0.name) }
        let simBooted = s.procs.values.contains { $0.name == "launchd_sim" }
        var rows: [Finding] = []
        var out: [Finding] = []
        func row(_ item: DiskScan.Item, _ why: String, _ symbol: String) {
            rows.append(Finding(id: "path:\(item.path)", keepKey: item.path, group: .space, name: item.name, why: why, bytes: item.bytes,
                                action: .trash(path: item.path), undoLabel: Copy.putBack, link: nil, iconPath: nil, symbol: symbol))
        }
        func know(_ id: String, _ name: String, _ why: String, _ symbol: String, bytes: UInt64, link: Finding.Link? = nil,
                  action: Finding.Action? = nil, undo: String? = nil) {
            out.append(Finding(id: "know:\(id)", keepKey: "know:\(id)", group: .know, name: name, why: why, bytes: bytes, action: action,
                               undoLabel: undo, link: link, iconPath: nil, symbol: symbol))
        }
        func folder(_ path: String) -> Finding.Link { Finding.Link(title: Copy.showFolder, url: path) }
        for item in d.items where item.bytes >= t.diskMin {
            switch item.kind {
            case .derivedData: if !xcodeBusy, !item.busy, item.bytes >= 1 << 30 { row(item, Copy.whyDerivedData(item.bytes), "hammer") }
            case .deviceSupport: if !xcodeBusy, !item.busy, item.bytes >= 1 << 30 { row(item, Copy.whyDeviceSupport, "iphone.and.arrow.forward") }
            case .previews: if !xcodeBusy, !item.busy { row(item, Copy.whyDerivedData(item.bytes), "eye") }
            case .simCache: if !simBooted, !item.busy { row(item, Copy.whyDevCache, "iphone") }
            case .devCache: if !item.busy { row(item, Copy.whyDevCache, "shippingbox") }
            case .otherCache:
                know("cache:\(item.path)", item.name, Copy.otherCache(item.bytes), "shippingbox", bytes: item.bytes, link: folder(item.path),
                     action: .trash(path: item.path), undo: Copy.putBack)
            case .orphanCache:
                // A folder named after an app nothing runs from, and nothing wrote into for a month.
                let tail = item.name.components(separatedBy: ".").last ?? item.name
                let alive = tail.count >= 5 && s.procs.values.contains { ($0.path as NSString).lastPathComponent.range(of: tail, options: .caseInsensitive) != nil }
                if !item.busy, !alive { row(item, Copy.whyOrphanCache, "archivebox") }
            case .installer: row(item, Copy.whyInstaller(item.bytes), "arrow.down.circle")
            case .trash:
                know("trash", item.name, Copy.trashSize(item.bytes), "trash", bytes: item.bytes,
                     link: Finding.Link(title: Copy.trashLink, url: URL(fileURLWithPath: item.path).absoluteString), action: .emptyTrash)
            case .runtime:
                know("runtime:\(item.path)", item.name, Copy.oldRuntime(item.name, item.bytes), "iphone", bytes: item.bytes, action: .deleteRuntime(id: item.path))
            case .oldDevice:
                know("device:\(item.path)", item.name, Copy.oldDevice(item.name, item.bytes), "iphone", bytes: item.bytes, action: .deleteDevice(udid: item.path))
            case .appCache:
                // B10: a big cache of an installed app; it refills, so it may go while the app is closed.
                guard item.bytes >= 2 << 30, let id = item.owner else { break }
                let open = s.app(bundle: id) != nil
                know("appcache:\(id)", Copy.appCacheName(item.name), open ? Copy.appCacheOpen(item.name) : Copy.appCache(item.name), "archivebox",
                     bytes: item.bytes, link: folder(item.path), action: open ? nil : .trash(path: item.path), undo: open ? nil : Copy.putBack)
            case .worktree, .npx, .claudeTemp: break
            }
        }

        // B7: Claude worktrees, one row per project and state. The scan only reports ones git has not touched for a day
        // with nothing running inside; a session sitting in one now keeps it.
        let live = Array(s.cwd.values)
        let trees = d.items.filter { item in item.kind == .worktree && !live.contains { $0 == item.path || $0.hasPrefix(item.path + "/") } }
        func sum(_ items: [DiskScan.Item]) -> UInt64 { items.reduce(0) { $0 + $1.bytes } }
        func targets(_ items: [DiskScan.Item], _ check: Finding.TrashTarget.Check) -> [Finding.TrashTarget] {
            items.map { Finding.TrashTarget(path: $0.path, bytes: $0.bytes, check: check) }
        }
        for (project, group) in Dictionary(grouping: trees, by: { $0.owner ?? "" }).sorted(by: { $0.key < $1.key }) where !project.isEmpty {
            let name = Self.project(project) ?? (project as NSString).lastPathComponent
            let finished = group.filter { $0.state == .finished }
            let local = group.filter { $0.state == .finishedLocal }
            let unmerged = group.filter { $0.state == .unmerged || $0.state == .unmergedLocal }
            let dirty = group.filter { $0.state == .dirty }
            if !finished.isEmpty, sum(finished) >= t.diskMin {
                rows.append(Finding(id: "worktrees:\(project)", keepKey: "worktrees:\(project)", group: .space, name: Copy.finishedWorktrees(name),
                                    why: Copy.whyFinishedWorktrees(finished.count), bytes: sum(finished), action: .trashAll(targets(finished, .mergedWorktree)),
                                    undoLabel: Copy.putBack, link: nil, iconPath: nil, symbol: "arrow.triangle.branch"))
            }
            if !local.isEmpty, sum(local) >= t.diskMin {
                know("worktrees-local:\(project)", Copy.localWorktrees(name), Copy.whyLocalWorktrees(local.count), "arrow.triangle.branch",
                     bytes: sum(local), link: folder("\(project)/.claude/worktrees"), action: .trashAll(targets(local, .worktree)), undo: Copy.putBack)
            }
            if !unmerged.isEmpty, sum(unmerged) >= t.diskMin {
                let why = Copy.whyUnmergedWorktrees(unmerged.count, local: unmerged.contains { $0.state == .unmergedLocal })
                know("worktrees-unmerged:\(project)", Copy.unmergedWorktrees(name), why, "arrow.triangle.branch",
                     bytes: sum(unmerged), link: folder("\(project)/.claude/worktrees"), action: .trashAll(targets(unmerged, .worktree)), undo: Copy.putBack)
            }
            if !dirty.isEmpty, sum(dirty) >= t.diskMin {
                know("worktrees-dirty:\(project)", Copy.dirtyWorktrees(name), Copy.whyDirtyWorktrees(dirty.count), "arrow.triangle.branch",
                     bytes: sum(dirty), link: folder("\(project)/.claude/worktrees"))
            }
        }

        // B8: npx's old downloads; B9: Claude's scratch folders from sessions that ended days ago. One row each.
        let npx = d.items.filter { $0.kind == .npx && !$0.busy }
        if sum(npx) >= t.diskMin {
            rows.append(Finding(id: "npx", keepKey: "npx", group: .space, name: Copy.npxName, why: Copy.whyNpx(npx.count), bytes: sum(npx),
                                action: .trashAll(targets(npx, .unused)), undoLabel: Copy.putBack, link: nil, iconPath: nil, symbol: "shippingbox"))
        }
        let temp = d.items.filter { $0.kind == .claudeTemp && !$0.busy }
        if sum(temp) >= t.diskMin {
            rows.append(Finding(id: "claude-temp", keepKey: "claude-temp", group: .space, name: Copy.claudeTempName, why: Copy.whyClaudeTemp(temp.count),
                                bytes: sum(temp), action: .trashAll(targets(temp, .written)), undoLabel: Copy.putBack, link: nil, iconPath: nil, symbol: "folder"))
        }

        if d.unavailableSims > 0 {
            rows.append(Finding(id: "sims:unavailable", keepKey: "sims:unavailable", group: .space, name: "\(d.unavailableSims) unusable test \(d.unavailableSims == 1 ? "iPhone" : "iPhones")",
                                why: Copy.whyUnavailableSims, bytes: 0, action: .deleteUnavailableSims, undoLabel: nil, link: nil, iconPath: nil, symbol: "iphone.slash"))
        }
        if d.totalBytes > 0, d.freeBytes < min(d.totalBytes / 10, 20 << 30) {
            out.append(Finding(id: "know:disk", keepKey: "know:disk", group: .know, name: "Space", why: Copy.lowDisk(d.freeBytes), bytes: 0, action: nil,
                               undoLabel: nil, link: nil, iconPath: nil, symbol: "internaldrive"))
        }
        // Biggest first, so the rows that matter most lead.
        return rows.sorted { $0.bytes > $1.bytes } + out
    }

    /// The Trash, when only YouFixIt's own record says what is in it (measuring ~/.Trash needs Full Disk Access).
    static func trashLedger(_ d: DiskScan?, trashed: UInt64) -> [Finding] {
        guard trashed >= 500 << 20, !(d?.items.contains { $0.kind == .trash } ?? false) else { return [] }
        return [Finding(id: "know:trash", keepKey: "know:trash", group: .know, name: "Trash", why: Copy.trashMoved(trashed), bytes: trashed,
                        action: .emptyTrash, undoLabel: nil,
                        link: Finding.Link(title: Copy.trashLink, url: URL(fileURLWithPath: DiskScanner.home + "/.Trash").absoluteString),
                        iconPath: nil, symbol: "trash")]
    }

    // MARK: - Good to know

    /// `covered` holds the processes that already have a row, so none is explained twice.
    static func insights(_ s: Sample, _ h: [Sample], _ t: Tuning, covered: Set<pid_t> = []) -> [Finding] {
        var out: [Finding] = []
        var covered = covered
        func know(_ id: String, _ name: String, _ why: String, _ symbol: String, link: Finding.Link? = nil, bytes: UInt64 = 0,
                  action: Finding.Action? = nil, undo: String? = nil, keepKey: String? = nil) {
            out.append(Finding(id: "know:\(id)", keepKey: keepKey ?? "know:\(id)", group: .know, name: name, why: why, bytes: bytes, action: action,
                               undoLabel: undo, link: link, iconPath: nil, symbol: symbol))
        }
        if avgCPU(named: ["mds_stores", "mds", "mdworker_shared", "mdworker"], h, 300) >= 0.2 {
            know("spotlight", "Spotlight", Copy.spotlight, "magnifyingglass",
                 link: Finding.Link(title: Copy.spotlightLink, url: "x-apple.systempreferences:com.apple.Spotlight-Settings.extension"))
        }
        if avgCPU(named: ["photoanalysisd", "mediaanalysisd"], h, 300) >= 0.2 { know("photos", "Photos", Copy.photos, "photo") }
        if avgCPU(named: ["backupd"], h, t.sustain) >= 0.1 { know("backup", "Time Machine", Copy.timeMachine, "clock.arrow.circlepath", action: .stopBackup) }
        if avgCPU(named: ["softwareupdated", "nsurlsessiond"], h, t.sustain) >= 0.1 {
            know("update", "Software Update", Copy.update, "arrow.down.circle",
                 link: Finding.Link(title: Copy.updateLink, url: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"))
        }

        for app in s.apps {
            let renderers: [Sample.Proc]
            if chromeFamily.contains(app.bundleID) {
                renderers = s.tree(app.pid).filter { $0.name.hasSuffix("Helper (Renderer)") }
            } else if app.bundleID == "com.apple.Safari" {
                renderers = s.procs(named: "com.apple.WebKit.WebContent")
            } else { continue }
            let bytes = renderers.reduce(0) { $0 + $1.footprint }
            if renderers.count >= 25 || bytes >= 3 << 30 {
                know("tabs:\(app.bundleID)", app.name, Copy.tabs(app.name, renderers.count, bytes), "safari", link: show(app), bytes: bytes)
            }
        }

        // Claude coding sessions, the quiet ones by project folder. A session quiet for half an hour can be closed from
        // here (its conversation stays and picks up again when it is opened).
        let sessions = s.procs.values.filter { $0.path.hasSuffix(Sampler.claudeSession) }.sorted { $0.pid < $1.pid }
        let sessionBytes = sessions.reduce(0) { $0 + $1.footprint }
        if sessions.count >= 4 || sessionBytes >= 2 << 30 {
            let quiet = sessions.filter { s.at.timeIntervalSince(s.quietSince[$0.pid] ?? $0.start) >= t.sessionQuiet }
            let folders = Array(Set(quiet.compactMap { s.cwd[$0.pid].flatMap(project) })).sorted()
            let action: Finding.Action? = t.closeQuietSessions && !quiet.isEmpty
                ? .endSessions(quiet.map { Finding.Target(pid: $0.pid, start: $0.start, bytes: s.footprint(of: $0.pid)) }) : nil
            know("claude", "Claude", Copy.claude(sessions.count, sessionBytes, quiet: Array(folders.prefix(3)), more: folders.count > 3, closable: action != nil),
                 "bubble.left.and.text.bubble.right", link: s.app(bundle: "com.anthropic.claudefordesktop").flatMap(show), bytes: sessionBytes, action: action)
        }

        // G13: virtual machines that only get explained.
        for app in s.apps where vmExplain.contains(app.bundleID) {
            let bytes = s.footprint(of: app.pid)
            if bytes >= 1 << 30 { know("vm:\(app.bundleID)", app.name, Copy.vmApp(app.name, bytes), "desktopcomputer", link: show(app), bytes: bytes) }
        }

        // G14: Homebrew programs started by hand that launchd adopted, each the top of its own tree, so the row names what
        // Stop reaches. Not an app, not a launchd job (Stop would only see it respawn), not a server or database (R3 and B3
        // cover those), never a tree that holds someone's terminal (tmux, a shell). One row each.
        for p in s.procs.values.sorted(by: { $0.pid < $1.pid }) where p.uid == Sampler.me && p.ppid == 1
            && Sampler.brewPrefixes.contains(where: { p.path.hasPrefix($0) }) && !Sampler.serverNames.contains(p.name) && !Sampler.dbNames.contains(p.name) {
            guard s.app(p.pid) == nil, s.jobs[p.pid] == nil, service(p, in: s) == nil, !covered.contains(p.pid),
                  !Safety.holdsTerminals(p, in: s) else { continue }
            let bytes = s.footprint(of: p.pid)
            guard bytes >= 150 << 20, s.at.timeIntervalSince(p.start) >= t.orphanAge else { continue }
            know("brewprog:\(p.pid)", p.name, Copy.brewProgram, "server.rack", bytes: bytes,
                 action: Safety.system(p.path) ? nil : .sigterm(pid: p.pid, start: p.start), keepKey: "brewprog:\(p.path)")
            covered.insert(p.pid)
        }

        // G15: menu bar apps, which the idle-app rule never looks at. Each big, quiet one gets a row with Quit.
        if spans(h, t.idle) {
            for app in s.apps.sorted(by: { $0.pid < $1.pid }) where app.accessory && !app.bundleID.isEmpty && !Safety.essential(app.bundleID)
                && !vmActionable.contains(app.bundleID) && !vmExplain.contains(app.bundleID) && !covered.contains(app.pid)
                && (app.url.map { !$0.path.hasPrefix("/System/") } ?? false) {
                let bytes = s.footprint(of: app.pid)
                guard bytes >= t.barAppMin, avgCPU(app.pid, h, t.idle) < 0.05 else { continue }
                know("menubar:\(app.bundleID)", app.name, Copy.menuBarApp, "menubar.rectangle", bytes: bytes,
                     action: .quitApp(pid: app.pid, bundleID: app.bundleID, url: app.url), undo: Copy.reopen, keepKey: app.bundleID)
            }
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
            let app = s.app(p.pid)
            let name = app?.name ?? command(s.args[p.pid], fallback: p.name)
            var action: Finding.Action?
            if let app {
                if !Safety.essential(app.bundleID), !app.bundleID.isEmpty { action = .quitApp(pid: app.pid, bundleID: app.bundleID, url: app.url) }
            } else if !Safety.system(p.path), !insideApp(p.path), !Safety.holdsTerminals(p, in: s) {
                action = .sigterm(pid: p.pid, start: p.start)
            }
            know("busy:\(p.pid)", name, Copy.busyProgram(name), "gauge.with.needle", link: app.flatMap(show) ?? activityMonitor,
                 bytes: s.footprint(of: p.pid), action: action, undo: app != nil && action != nil ? Copy.reopen : nil,
                 keepKey: app.map(\.bundleID) ?? "busy:\(p.path)")
            covered.insert(p.pid)
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
        if s.uptime >= 14 * 86_400, s.swapUsed >= 1 << 30 { know("uptime", "Restart", Copy.longUptime(Int(s.uptime / 86_400)), "restart", action: .restart) }

        // B5: something of ours has kept the Mac from sleeping for an hour. Essentials (Claude while it works) are left out.
        var holds: [pid_t: Date] = [:]
        for a in s.assertions where sleepTypes.contains(a.type) { holds[a.pid] = min(holds[a.pid] ?? a.since, a.since) }
        for (pid, since) in holds.sorted(by: { $0.key < $1.key }) where s.at.timeIntervalSince(since) >= t.awakeHold {
            guard let p = s.procs[pid], p.uid == Sampler.me, !Safety.system(p.path), !Safety.neverNames.contains(p.name),
                  pid != ProcessInfo.processInfo.processIdentifier else { continue }
            let app = s.app(pid)
            if let app, Safety.essential(app.bundleID) || app.bundleID.isEmpty { continue }
            let name = app?.name ?? command(s.args[pid], fallback: p.name)
            let action: Finding.Action? = app.map { .quitApp(pid: $0.pid, bundleID: $0.bundleID, url: $0.url) }
                ?? (p.ppid == 1 && !insideApp(p.path) && !Safety.holdsTerminals(p, in: s) ? .sigterm(pid: pid, start: p.start) : nil)
            let key = "awake:\(app?.bundleID ?? p.path)"
            know(key, name, Copy.keepingAwake(name, for: s.at.timeIntervalSince(since)), "cup.and.saucer", link: app.flatMap(show),
                 bytes: s.footprint(of: pid), action: action, undo: app != nil ? Copy.reopen : nil, keepKey: key)
        }

        // G12, G17: leftovers R3 does not stop on its own: programs that serve nothing, servers something is connected to,
        // notebooks. Each with Stop.
        for p in orphans(s).sorted(by: { $0.pid < $1.pid }) where leftoverNames.contains(p.name) && !covered.contains(p.pid) {
            let bytes = s.footprint(of: p.pid)
            guard bytes >= 150 << 20, s.at.timeIntervalSince(p.start) >= t.orphanAge else { continue }
            let tree = s.tree(p.pid)
            let listens = tree.contains { s.listening.contains($0.pid) }
            let connected = tree.contains { (s.clients[$0.pid] ?? 0) > 0 }
            let id: String
            let why: String
            if notebook(s.args[p.pid]) {
                (id, why) = ("leftover-server", Copy.notebook)
            } else if listens && connected {
                (id, why) = ("leftover-server", Copy.connectedServer)
            } else if listens {
                continue    // a server nobody uses yet still working; R3 takes it once it settles
            } else if ["node", "bun", "deno"].contains(p.name) {
                (id, why) = ("leftover-watcher", Copy.leftoverWatcher(bytes))
            } else {
                (id, why) = ("leftover", Copy.otherLeftover(p.name, bytes))
            }
            let name = listens ? serverName(s.args[p.pid], fallback: p.name) : command(s.args[p.pid], fallback: p.name)
            know("\(id):\(p.pid)", name, why, "terminal", link: activityMonitor, bytes: bytes,
                 action: Safety.holdsTerminals(p, in: s) ? nil : .sigterm(pid: p.pid, start: p.start), keepKey: serverKey(p, in: s))
        }
        for p in s.procs.values.sorted(by: { $0.pid < $1.pid }) where p.uid == Sampler.me && p.ppid != 1 && Sampler.browserNames.contains(p.name) {
            guard let args = s.args[p.pid], isHeadless(args), s.footprint(of: p.pid) >= 300 << 20 else { continue }
            // Only a browser with a throwaway profile is ever stopped: a real profile with a debugging port is someone's browser.
            know("testbrowser:\(p.pid)", Copy.testCopy(p.name), Copy.liveTestBrowser, "globe", bytes: s.footprint(of: p.pid),
                 action: hasTempProfile(args) ? .sigterm(pid: p.pid, start: p.start) : nil)
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
