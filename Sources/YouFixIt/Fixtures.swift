import Foundation

/// Hand-written Macs, with today's numbers, so every rule has a case that must fire and cases that must not.
/// `--selftest` runs them; `--mock NAME` feeds one to the UI.
enum Fixtures {
    static let now = Date(timeIntervalSince1970: 1_791_400_000)
    static let simUDID = "7E77307F-4739-4BBA-819C-D9D9B45E1E1F"

    struct Spec {
        var procs: [Sample.Proc] = []
        var apps: [Sample.App] = []
        var sims: [Sample.Sim] = []
        var jobs: [pid_t: String] = [:]
        var args: [pid_t: [String]] = [:]
        var cwd: [pid_t: String] = [:]
        var listening: Set<pid_t> = []
        var ports: [pid_t: [Int]] = [:]
        var clients: [pid_t: Int] = [:]
        var assertions: [Sample.Assertion] = []
        var quietSince: [pid_t: Date] = [:]
        var containersIdle: [String: Bool] = [:]
        var frontmost: pid_t = 0
        var pressure = 1
        var load1 = 3.0
        var cpuBusy = 0.2
        var memUsed: UInt64 = 30 << 30
        var compressed: UInt64 = 4 << 30
        var swap: UInt64 = 0
        var thermal = 0
        var loggedIn: Date? = now.addingTimeInterval(-30_000)
        var booted = now.addingTimeInterval(-30_020)
    }

    static func proc(_ pid: pid_t, _ ppid: pid_t, _ name: String, path: String? = nil, uid: uid_t = Sampler.me,
                     ago: TimeInterval, cpu: Double = 0, mb: UInt64 = 10, io: UInt64 = 0) -> Sample.Proc {
        Sample.Proc(pid: pid, ppid: ppid, uid: uid, name: name, path: path ?? "/Users/me/bin/\(name)",
                    start: now.addingTimeInterval(-ago), cpu: cpu, footprint: mb << 20, diskIO: io)
    }

    static func app(_ pid: pid_t, _ bundle: String, _ name: String, activatedAgo: TimeInterval = 10_800, windows: Int = 0,
                    hidden: Bool = false, active: Bool = false, modal: Bool = false, audio: Bool = false, launchedAgo: TimeInterval = 20_000,
                    accessory: Bool = false) -> Sample.App {
        Sample.App(pid: pid, bundleID: bundle, name: name, url: URL(fileURLWithPath: "/Applications/\(name).app"), regular: !accessory,
                   accessory: accessory, hidden: hidden, active: active, launched: now.addingTimeInterval(-launchedAgo),
                   lastActivated: now.addingTimeInterval(-activatedAgo), windows: windows, hasModal: modal, audio: audio)
    }

    /// `count` samples `cadence` seconds apart ending at `now`. `tweak` edits the spec for one sample (0 = oldest).
    static func history(_ base: Spec, count: Int = 31, cadence: TimeInterval = 20, tweak: (Int, inout Spec) -> Void = { _, _ in }) -> [Sample] {
        (0..<count).map { i in
            var spec = base
            tweak(i, &spec)
            let at = now.addingTimeInterval(-cadence * Double(count - 1 - i))
            var procs: [pid_t: Sample.Proc] = [:]
            var children: [pid_t: [pid_t]] = [:]
            for p in spec.procs where procs[p.pid] == nil {
                procs[p.pid] = p
                children[p.ppid, default: []].append(p.pid)
            }
            return Sample(at: at, procs: procs, children: children, apps: spec.apps, sims: spec.sims, jobs: spec.jobs,
                          args: spec.args, cwd: spec.cwd, listening: spec.listening, ports: spec.ports, clients: spec.clients, containersIdle: spec.containersIdle,
                          assertions: spec.assertions, quietSince: spec.quietSince,
                          frontmost: spec.frontmost, fullscreen: false,
                          cpuBusy: spec.cpuBusy, load1: spec.load1, cores: 16, memUsed: spec.memUsed, memTotal: 48 << 30,
                          compressed: spec.compressed, swapUsed: spec.swap, pressure: spec.pressure, thermal: spec.thermal,
                          booted: spec.booted, loggedIn: spec.loggedIn)
        }
    }

    // MARK: - Today's Mac, piece by piece

    /// The booted "Saves Store 6.9" device with no window, idle log stream, idle Claude helper.
    static var simIdle: Spec {
        var s = Spec()
        s.procs = [
            proc(1, 0, "launchd", path: "/sbin/launchd", uid: 0, ago: 30_020),
            proc(2646, 1, "Claude", path: "/Applications/Claude.app/Contents/MacOS/Claude", ago: 26_000, mb: 500),
            proc(29335, 1, "launchd_sim", path: "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/launchd_sim", ago: 7200),
            proc(29341, 29335, "SpringBoard", ago: 7190, cpu: 0.003, mb: 470),
            proc(37472, 29335, "Saves", ago: 7000, mb: 500),
            proc(58347, 1, "com.apple.CoreSimulator.CoreSimulatorService", ago: 20_000),
            proc(58547, 1, "SimulatorTrampoline", ago: 20_000),
            proc(58298, 2646, "disclaimer", ago: 20_000),
            proc(58299, 58298, "claude-ios-sim", ago: 20_000, mb: 94),
            proc(38206, 2646, "disclaimer", ago: 1560),
            proc(38215, 38206, "simctl", path: "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl", ago: 1560),
            proc(31542, 1, "Stremio", path: "/Applications/Stremio.app/Contents/MacOS/Stremio", ago: 9000, cpu: 0.3, mb: 1500),
        ] + (0..<20).map { proc(30_000 + pid_t($0), 29335, "simdaemon\($0)", ago: 7100) }
        s.apps = [
            app(2646, "com.anthropic.claudefordesktop", "Claude", activatedAgo: 120, windows: 2),
            app(31542, "com.stremio.app", "Stremio", activatedAgo: 0, windows: 1, active: true, audio: true),
        ]
        s.sims = [Sample.Sim(udid: simUDID, name: "Saves Store 6.9", runtime: "iOS 26.5", launchdPid: 29335, lastUsed: nil)]
        s.args = [29335: ["launchd_sim", "/Users/me/Library/Developer/CoreSimulator/Devices/\(simUDID)/data/var/run/launchd_bootstrap.plist"]]
        s.frontmost = 31542
        return s
    }

    /// The same Mac with the simulator shut down: the base for everything else.
    static var quiet: Spec {
        var s = simIdle
        s.sims = []
        s.procs.removeAll { $0.name == "launchd_sim" || $0.ppid == 29335 }
        return s
    }

    /// An `expo start` whose shell and Claude session are gone: npm exec (node) adopted by launchd, child node listening on 8081.
    static var expoOrphan: Spec {
        var s = quiet
        s.procs += [
            proc(36644, 1, "node", path: "/Users/me/.nvm/versions/node/v22/bin/node", ago: 10_800, mb: 300),
            proc(36677, 36644, "node", path: "/Users/me/.nvm/versions/node/v22/bin/node", ago: 10_790, cpu: 0.005, mb: 1000),
        ]
        s.args[36644] = ["node", "/Users/me/Saves/node_modules/.bin/expo", "start", "--port", "8081"]
        s.listening = [36677]
        return s
    }

    /// A headless Chrome a screenshot script left behind, data dir under /private/tmp, parent gone.
    static var headlessChrome: Spec {
        var s = quiet
        s.procs += [
            proc(19996, 1, "Google Chrome", path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", ago: 17_000, mb: 400),
            proc(19997, 19996, "Google Chrome Helper (Renderer)", path: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)", ago: 16_990, mb: 200),
        ]
        s.args[19996] = ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "--headless=new", "--remote-debugging-port=9333",
                         "--user-data-dir=/private/tmp/claude-501/scratchpad/qa/cdp"]
        return s
    }

    /// Chrome Beta with 40 renderers, untouched for hours: explained, never touched.
    static var chrome40: Spec {
        var s = quiet
        s.procs.append(proc(5000, 1, "Google Chrome Beta", path: "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta", ago: 20_000, mb: 600))
        s.procs += (0..<40).map { proc(5100 + pid_t($0), 5000, "Google Chrome Beta Helper (Renderer)", path: "/Applications/Google Chrome Beta.app/Contents/Frameworks/x/Google Chrome Beta Helper (Renderer)", ago: 15_000, mb: 200) }
        s.apps.append(app(5000, "com.google.Chrome.beta", "Google Chrome Beta"))
        return s
    }

    /// FreeFlow at 1.3 GB, no window, untouched for three hours.
    static var freeflowIdle: Spec {
        var s = quiet
        s.procs.append(proc(7000, 1, "FreeFlow", path: "/Applications/FreeFlow.app/Contents/MacOS/FreeFlow", ago: 20_000, mb: 1300))
        s.apps.append(app(7000, "com.freemans.freeflow", "FreeFlow"))
        return s
    }

    /// Nine Claude Code sessions holding 4.5 GB: explained, never touched. Three have a known project folder.
    static var claude9: Spec {
        var s = quiet
        s.procs += (0..<9).map { proc(60_000 + pid_t($0), 2646, "claude", path: "/Users/me/Library/Application Support/Claude/claude-code/2.1.289/x/claude.app/Contents/MacOS/claude", ago: 18_000, mb: 500) }
        s.cwd = [60_000: "/Users/me/Saves", 60_001: "/Users/me/Saves", 60_002: "/Users/me/Ai Projects/YouFixIT"]
        return s
    }

    /// Docker Desktop with its 3.3 GB machine up and no container running, untouched for hours.
    static var dockerIdle: Spec {
        var s = quiet
        s.procs += [
            proc(8000, 1, "Docker", path: "/Applications/Docker.app/Contents/MacOS/Docker", ago: 20_000, mb: 200),
            proc(8001, 8000, "com.docker.backend", path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend", ago: 19_990, mb: 300),
            proc(8002, 8001, "com.docker.virtualization", path: "/Applications/Docker.app/Contents/MacOS/com.docker.virtualization", ago: 19_980, mb: 3300),
        ]
        s.apps.append(app(8000, "com.docker.docker", "Docker", accessory: true))
        s.containersIdle = ["com.docker.docker": true]
        return s
    }

    /// mysql (through mysqld_safe), postgres (with two helpers) and redis, started by launchd from Homebrew at login.
    static var brewServices: Spec {
        var s = quiet
        s.procs += [
            proc(8300, 1, "sh", path: "/bin/sh", ago: 29_000, mb: 2),
            proc(8301, 8300, "mysqld", path: "/opt/homebrew/opt/mysql/bin/mysqld", ago: 29_000, mb: 400),
            proc(8302, 1, "postgres", path: "/opt/homebrew/opt/postgresql@16/bin/postgres", ago: 29_000, mb: 150),
            proc(8310, 8302, "postgres", path: "/opt/homebrew/opt/postgresql@16/bin/postgres", ago: 28_990, mb: 20),
            proc(8311, 8302, "postgres", path: "/opt/homebrew/opt/postgresql@16/bin/postgres", ago: 28_990, mb: 20),
            proc(8303, 1, "redis-server", path: "/opt/homebrew/opt/redis/bin/redis-server", ago: 29_000, mb: 60),
        ]
        // Both label namings Homebrew has used: sh.brew.* is what brew services writes today, homebrew.mxcl.* what it wrote before.
        s.jobs = [8300: "homebrew.mxcl.mysql", 8302: "sh.brew.postgresql@16", 8303: "homebrew.mxcl.redis"]
        return s
    }

    /// Three menu bar apps holding 1.8 GB between them.
    static var menuBarApps: Spec {
        var s = quiet
        s.procs += [
            proc(8201, 1, "Raycast", path: "/Applications/Raycast.app/Contents/MacOS/Raycast", ago: 20_000, mb: 900),
            proc(8202, 1, "Setapp", path: "/Applications/Setapp.app/Contents/MacOS/Setapp", ago: 20_000, mb: 500),
            proc(8203, 1, "CleanShot X", path: "/Applications/CleanShot X.app/Contents/MacOS/CleanShot X", ago: 20_000, mb: 400),
        ]
        s.apps += [
            app(8201, "com.raycast.macos", "Raycast", accessory: true),
            app(8202, "com.setapp.DesktopClient", "Setapp", accessory: true),
            app(8203, "pl.maketheweb.cleanshotx", "CleanShot X", accessory: true),
        ]
        return s
    }

    /// A Gradle daemon at 90% of a core for the last hour while the user is in Stremio.
    static var busyProgram: Spec {
        var s = quiet
        s.procs.append(proc(9000, 1, "java", path: "/Library/Java/JavaVirtualMachines/jdk/Contents/Home/bin/java", ago: 3000, cpu: 0.9, mb: 800))
        return s
    }

    /// `npm exec next dev --port 3120` from a finished worktree session, as it really runs: the npm root adopted by launchd,
    /// `next dev` under it, next-server listening on 3120 and a worker it talks to over loopback (not a client).
    static var nextOrphan: Spec {
        var s = quiet
        let node = "/Users/me/.nvm/versions/node/v22/bin/node"
        s.procs += [
            proc(3100, 1, "node", path: node, ago: 400_000, mb: 7),
            proc(3101, 3100, "node", path: node, ago: 400_000, mb: 7),
            proc(3102, 3101, "node", path: node, ago: 399_990, mb: 5800),
            proc(3103, 3102, "node", path: node, ago: 399_000, mb: 400),
        ]
        s.args[3100] = ["npm exec next dev --port 3120", "", "", "", "", ""]   // npm's retitled command line, as it really reads
        s.cwd[3100] = "/Users/me/Ai Projects/Real Woo AI/.claude/worktrees/agent-afe14/platform/app"
        s.listening = [3102]
        s.ports = [3102: [3120]]
        return s
    }

    /// Twenty-two `php -S` servers a store tool left behind, 40 MB each, plus a Jupyter notebook server.
    static var phpSwarm: Spec {
        var s = quiet
        for i in 0..<22 {
            let pid = pid_t(4000 + i)
            s.procs.append(proc(pid, 1, "php", path: "/opt/homebrew/Cellar/php/8.4.1/bin/php", ago: 200_000, mb: 40))
            s.args[pid] = ["php", "-S", "127.0.0.1:\(8900 + i)", "-t", "stores/site\(i)/source"]
            s.cwd[pid] = "/Users/me/Ai Projects/Real Woo AI"
            s.listening.insert(pid)
            s.ports[pid] = [8900 + i]
        }
        s.procs.append(proc(4100, 1, "python3", path: "/opt/homebrew/bin/python3", ago: 90_000, mb: 600))
        s.args[4100] = ["python3", "-m", "jupyter", "lab", "--port", "8888"]
        s.listening.insert(4100)
        s.ports[4100] = [8888]
        return s
    }

    /// A mysqld a store tool started by hand and left: parent launchd, no launchd job, its config under ~/.cache.
    static var mysqlOrphan: Spec {
        var s = quiet
        s.procs.append(proc(4500, 1, "mysqld", path: "/opt/homebrew/opt/mysql@8.0/bin/mysqld", ago: 340_000, mb: 780))
        s.args[4500] = ["mysqld", "--defaults-file=/Users/me/.cache/kli-local/alizab-live-8880/mysql/my.cnf"]
        return s
    }

    /// An idle Gradle daemon nothing has built with for hours.
    static var gradleDaemon: Spec {
        var s = quiet
        s.procs.append(proc(4600, 1, "java", path: "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home/bin/java", ago: 50_000, mb: 900))
        s.args[4600] = ["java", "-Xmx2048m", "-cp", "/Users/me/.gradle/wrapper/dists/gradle-8.10/lib/gradle-launcher-8.10.jar",
                        "org.gradle.launcher.daemon.bootstrap.GradleDaemon", "8.10"]
        return s
    }

    /// Who keeps the Mac awake: Vorssaint for 23 hours, a forgotten caffeinate, Claude while it works, powerd, and an app
    /// that started holding twenty minutes ago.
    static var sleepBlocker: Spec {
        var s = quiet
        s.procs += [
            proc(4700, 1, "Vorssaint", path: "/Applications/Vorssaint.app/Contents/MacOS/Vorssaint", ago: 90_000, mb: 120),
            proc(4701, 1, "caffeinate", path: "/usr/bin/caffeinate", ago: 20_000, mb: 1),
            proc(4702, 1, "Amphetamine", path: "/Applications/Amphetamine.app/Contents/MacOS/Amphetamine", ago: 5000, mb: 50),
            proc(90, 1, "powerd", path: "/System/Library/CoreServices/powerd.bundle/powerd", uid: 0, ago: 30_000),
        ]
        s.apps += [app(4700, "com.example.vorssaint", "Vorssaint", accessory: true), app(4702, "com.if.Amphetamine", "Amphetamine", accessory: true)]
        func hold(_ pid: pid_t, _ type: String, _ ago: TimeInterval) -> Sample.Assertion {
            Sample.Assertion(pid: pid, type: type, name: "held", since: now.addingTimeInterval(-ago))
        }
        s.assertions = [
            hold(4700, "PreventUserIdleSystemSleep", 23 * 3600), hold(4700, "PreventUserIdleDisplaySleep", 23 * 3600),
            hold(4701, "PreventUserIdleSystemSleep", 5 * 3600), hold(2646, "PreventUserIdleSystemSleep", 2 * 3600),
            hold(90, "PreventSystemSleep", 8 * 3600), hold(4702, "PreventUserIdleSystemSleep", 1200),
        ]
        return s
    }

    /// Only Good to know rows with buttons, for the UI: an old simulator, the Trash, a menu bar app, a leftover database,
    /// an app keeping the Mac awake.
    static var offers: Spec {
        var s = quiet
        s.procs += mysqlOrphan.procs.filter { $0.pid == 4500 }
        s.args.merge(mysqlOrphan.args) { a, _ in a }
        s.procs += sleepBlocker.procs.filter { $0.pid == 4700 }
        s.apps += sleepBlocker.apps.filter { $0.pid == 4700 }
        s.assertions = sleepBlocker.assertions.filter { $0.pid == 4700 }
        s.procs += menuBarApps.procs.filter { $0.pid == 8201 }
        s.apps += menuBarApps.apps.filter { $0.pid == 8201 }
        return s
    }

    static var offersDisk: DiskScan {
        DiskScan(at: now, items: [
            DiskScan.Item(kind: .trash, path: "/Users/me/.Trash", name: "Trash", bytes: 3100 << 20, modified: nil),
            DiskScan.Item(kind: .runtime, path: "com.apple.CoreSimulator.SimRuntime.iOS-17-5", name: "iOS 17.5", bytes: 7 << 30, modified: nil),
        ], unavailableSims: 0, freeBytes: 255 << 30, totalBytes: 926 << 30)
    }

    /// The disk side a mock runs with.
    static func disk(named name: String) -> DiskScan? {
        switch name {
        case "heavy": disk
        case "offers": offersDisk
        default: nil
        }
    }

    /// Everything at once, for the UI.
    static var heavy: Spec {
        var s = freeflowIdle
        s.sims = simIdle.sims
        s.procs += simIdle.procs.filter { $0.name == "launchd_sim" || $0.ppid == 29335 }
        s.procs += expoOrphan.procs.filter { $0.name == "node" }
        s.args.merge(expoOrphan.args) { a, _ in a }
        s.listening = expoOrphan.listening
        s.procs += headlessChrome.procs.filter { $0.pid == 19996 || $0.pid == 19997 }
        s.args.merge(headlessChrome.args) { a, _ in a }
        s.procs += chrome40.procs.filter { $0.pid >= 5000 && $0.pid < 5200 }
        s.apps.append(contentsOf: chrome40.apps.filter { $0.pid == 5000 })
        s.procs += claude9.procs.filter { $0.name == "claude" }
        s.cwd.merge(claude9.cwd) { a, _ in a }
        s.procs += dockerIdle.procs.filter { $0.pid >= 8000 && $0.pid < 8100 }
        s.apps.append(contentsOf: dockerIdle.apps.filter { $0.pid == 8000 })
        s.containersIdle = dockerIdle.containersIdle
        s.procs += brewServices.procs.filter { $0.pid >= 8300 && $0.pid < 8400 }
        s.jobs.merge(brewServices.jobs) { a, _ in a }
        s.procs += menuBarApps.procs.filter { $0.pid >= 8200 && $0.pid < 8300 }
        s.apps.append(contentsOf: menuBarApps.apps)
        s.procs += mysqlOrphan.procs.filter { $0.pid == 4500 }
        s.args.merge(mysqlOrphan.args) { a, _ in a }
        s.procs += sleepBlocker.procs.filter { $0.pid == 4700 }
        s.apps.append(contentsOf: sleepBlocker.apps.filter { $0.pid == 4700 })
        s.assertions = sleepBlocker.assertions.filter { $0.pid == 4700 }
        s.procs += [proc(400, 1, "mds_stores", path: "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", uid: 0, ago: 30_000, cpu: 0.25, mb: 600)]
        s.pressure = 2
        s.load1 = 175
        s.memUsed = 47 << 30
        s.compressed = 12 << 30
        return s
    }

    static var disk: DiskScan {
        DiskScan(at: now, items: [
            DiskScan.Item(kind: .derivedData, path: "/Users/me/Library/Developer/Xcode/DerivedData", name: "Xcode build cache", bytes: 1600 << 20, modified: nil),
            DiskScan.Item(kind: .devCache, path: "/Users/me/.npm/_cacache", name: "npm download cache", bytes: 22 << 30, modified: nil),
            DiskScan.Item(kind: .orphanCache, path: "/Users/me/Library/Caches/com.example.goneapp", name: "com.example.goneapp", bytes: 600 << 20, modified: nil),
            DiskScan.Item(kind: .devCache, path: "/Users/me/Library/Caches/pip", name: "pip cache", bytes: 8 << 20, modified: nil),
            DiskScan.Item(kind: .otherCache, path: "/Users/me/.cache/huggingface", name: "huggingface cache", bytes: 20 << 30, modified: nil),
            DiskScan.Item(kind: .worktree, path: "\(worktrees)/agent-a1", name: "agent-a1", bytes: 26 << 30, modified: nil, owner: project, state: .finished),
            DiskScan.Item(kind: .worktree, path: "\(worktrees)/agent-a2", name: "agent-a2", bytes: 16 << 30, modified: nil, owner: project, state: .finished),
            DiskScan.Item(kind: .npx, path: "/Users/me/.npm/_npx/0a1b2c", name: "0a1b2c", bytes: 5600 << 20, modified: nil),
            DiskScan.Item(kind: .trash, path: "/Users/me/.Trash", name: "Trash", bytes: 3100 << 20, modified: nil),
        ], unavailableSims: 0, freeBytes: 255 << 30, totalBytes: 926 << 30)
    }

    static let project = "/Users/me/Ai Projects/Real Woo AI"
    static let worktrees = "\(project)/.claude/worktrees"

    /// Every newer disk kind: worktrees in each state, npx, Claude's scratch folders, a big app cache, an old simulator.
    static var diskMore: DiskScan {
        func item(_ kind: DiskScan.Kind, _ path: String, _ mb: UInt64, busy: Bool = false, owner: String? = nil, state: DiskScan.Worktree? = nil) -> DiskScan.Item {
            DiskScan.Item(kind: kind, path: path, name: (path as NSString).lastPathComponent, bytes: mb << 20, modified: nil, busy: busy, owner: owner, state: state)
        }
        return DiskScan(at: now, items: [
            item(.worktree, "\(worktrees)/agent-a1", 900, owner: project, state: .finished),
            item(.worktree, "\(worktrees)/agent-a2", 700, owner: project, state: .finished),
            item(.worktree, "\(worktrees)/agent-a3", 800, owner: project, state: .finished),
            item(.worktree, "\(worktrees)/brand-b1", 800, owner: project, state: .unmerged),
            item(.worktree, "\(worktrees)/brand-b2", 300, owner: project, state: .unmergedLocal),
            item(.worktree, "\(worktrees)/env-d1", 700, owner: project, state: .finishedLocal),
            item(.worktree, "\(worktrees)/fix-c1", 600, owner: project, state: .dirty),
            item(.npx, "/Users/me/.npm/_npx/0a1b", 400),
            item(.npx, "/Users/me/.npm/_npx/2c3d", 300),
            item(.npx, "/Users/me/.npm/_npx/4e5f", 900, busy: true),
            item(.claudeTemp, "/private/tmp/claude-501/-Users-me-Saves/s1", 700),
            DiskScan.Item(kind: .appCache, path: "/Users/me/Library/Caches/com.spotify.client", name: "Spotify", bytes: 4700 << 20, modified: nil, owner: "com.spotify.client"),
            DiskScan.Item(kind: .runtime, path: "com.apple.CoreSimulator.SimRuntime.iOS-17-5", name: "iOS 17.5", bytes: 7 << 30, modified: nil),
            DiskScan.Item(kind: .oldDevice, path: "0F2C9A51-OLD", name: "iPhone 12", bytes: 2 << 30, modified: nil),
        ], unavailableSims: 0, freeBytes: 255 << 30, totalBytes: 926 << 30)
    }

    /// The same disk while something writes into the Xcode build cache.
    static var diskBusy: DiskScan {
        let d = disk
        return DiskScan(at: d.at, items: d.items.map { $0.kind == .derivedData ? DiskScan.Item(kind: $0.kind, path: $0.path, name: $0.name, bytes: $0.bytes, modified: nil, busy: true) : $0 },
                        unavailableSims: 0, freeBytes: d.freeBytes, totalBytes: d.totalBytes)
    }

    static func spec(named name: String) -> Spec? {
        switch name {
        case "simIdle": simIdle
        case "expoOrphan": expoOrphan
        case "headlessChrome": headlessChrome
        case "chrome40": chrome40
        case "freeflowIdle": freeflowIdle
        case "claude9": claude9
        case "dockerIdle": dockerIdle
        case "brewServices": brewServices
        case "menuBarApps": menuBarApps
        case "busyProgram": busyProgram
        case "nextOrphan": nextOrphan
        case "phpSwarm": phpSwarm
        case "mysqlOrphan": mysqlOrphan
        case "gradleDaemon": gradleDaemon
        case "sleepBlocker": sleepBlocker
        case "heavy": heavy
        case "offers": offers
        case "calm": quiet
        default: nil
        }
    }
}

// MARK: - Self test

@MainActor
func runSelfTest() {
    var failures = 0
    func check(_ ok: Bool, _ what: String) {
        if !ok { failures += 1 }
        print((ok ? "  ok   " : "  FAIL ") + what)
    }
    // Everything on, "Close quiet ones" included, so every rule is exercised; the shipped default is checked on its own.
    let t = { var t = Tuning.standard; t.closeQuietSessions = true; return t }()
    func ids(_ spec: Fixtures.Spec, keep: Set<String> = [], disk: DiskScan? = nil, tweak: (Int, inout Fixtures.Spec) -> Void = { _, _ in }) -> [Finding] {
        Rules.findings(history: Fixtures.history(spec, tweak: tweak), disk: disk, keep: keep, tuning: t)
    }
    func acts(_ f: [Finding]) -> [String] { f.filter(\.actionable).map(\.id).sorted() }
    func knows(_ f: [Finding], _ prefix: String) -> Bool { f.contains { !$0.actionable && $0.id.hasPrefix(prefix) } }
    func offers(_ f: [Finding], _ prefix: String) -> Bool { f.contains { $0.offer && $0.id.hasPrefix(prefix) } }
    func row(_ f: [Finding], _ prefix: String) -> Finding? { f.first { $0.id.hasPrefix(prefix) } }

    print("simulator")
    let sim = ids(Fixtures.simIdle)
    check(acts(sim) == ["sim:\(Fixtures.simUDID)"], "idle booted device is the one finding: \(acts(sim))")
    check((sim.first { $0.id.hasPrefix("sim:") }?.bytes ?? 0) >= 1 << 30, "estimate counts the whole tree")
    check(acts(ids(Fixtures.simIdle) { _, s in s.procs.append(Fixtures.proc(90_000, 1, "xcodebuild", ago: 60)) }).isEmpty, "a fresh xcodebuild means in use")
    check(acts(ids(Fixtures.simIdle) { _, s in s.apps.append(Fixtures.app(91_000, "com.apple.dt.Devices", "DeviceHub", activatedAgo: 0, windows: 1, active: true)) }).isEmpty, "DeviceHub in front means in use")
    check(acts(ids(Fixtures.simIdle) { i, s in
        if i >= 29 { s.procs = s.procs.map { $0.pid == 29341 ? Fixtures.proc(29341, 29335, "SpringBoard", ago: 7190, cpu: 0.4, mb: 470) : $0 } }
    }).isEmpty, "SpringBoard busy in the last minute means in use")
    check(acts(ids(Fixtures.simIdle) { _, s in s.procs = s.procs.map { $0.pid == 29335 ? Fixtures.proc(29335, 1, "launchd_sim", ago: 240) : $0 } }).isEmpty, "booted four minutes ago is too soon")
    check(acts(ids(Fixtures.simIdle, keep: [Fixtures.simUDID])).isEmpty, "a kept device is never suggested")
    check(Rules.findings(history: Array(Fixtures.history(Fixtures.simIdle).suffix(3)), disk: nil, keep: [], tuning: t).filter(\.actionable).isEmpty, "a minute of history is not enough to judge idleness")

    print("dev server")
    let expo = ids(Fixtures.expoOrphan)
    check(acts(expo).count == 1 && acts(expo)[0].hasPrefix("orphan:36644:"), "orphaned expo root is the finding: \(acts(expo))")
    check(expo.first { $0.id.hasPrefix("orphan:") }?.name == "expo start", "named after its command")
    check(Rules.command(["node", "--liftoff-only", "/Users/me/lib/codegraph.js"], fallback: "node") == "codegraph.js"
          && Rules.command(["node", "server.js"], fallback: "node") == "server.js" && Rules.command(["node"], fallback: "node") == "node",
          "flags before the script do not become the name")
    check(Rules.command(["node", "-e", "require('http').createServer().listen(8998)"], fallback: "node") == "node"
          && Rules.command(["python3", "-c", "import time; time.sleep(9)"], fallback: "python3") == "python3"
          && Rules.command(["python3", "-u", "manage.py", "runserver"], fallback: "python3") == "manage.py runserver",
          "inline code is never a name")
    let framework = "/opt/homebrew/Cellar/python@3.14/3.14.7/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python"
    check(Sampler.programName(framework) == "python3" && !Rules.insideApp(framework) && Rules.insideApp("/Applications/Stremio.app/Contents/MacOS/node"),
          "Homebrew's Python is python3, not part of an app")
    check(acts(ids(Fixtures.expoOrphan) { _, s in
        s.procs.append(Fixtures.proc(61_356, 2646, "claude", ago: 12_000))
        s.procs = s.procs.map { $0.pid == 36644 ? Fixtures.proc(36644, 61_356, "node", path: $0.path, ago: 10_800, mb: 300) : $0 }
    }).isEmpty, "a server whose Claude session is alive is in use")
    check(acts(ids(Fixtures.expoOrphan) { _, s in s.jobs[36644] = "com.example.job" }).isEmpty, "a launchd job is not an orphan")
    check(acts(ids(Fixtures.expoOrphan) { _, s in s.procs = s.procs.map { $0.pid == 36644 ? Fixtures.proc(36644, 1, "node", path: "/Applications/Stremio.app/Contents/MacOS/node", ago: 10_800, mb: 300) : $0 } }).isEmpty, "node inside an app bundle belongs to that app")
    let watcher = ids(Fixtures.expoOrphan) { _, s in s.listening = [] }
    check(acts(watcher).isEmpty && offers(watcher, "know:leftover-watcher:36644"), "no listening socket, no server: a watcher is offered a Stop, never selected")
    let connected = ids(Fixtures.expoOrphan) { _, s in s.clients = [36677: 1] }
    check(acts(connected).isEmpty && offers(connected, "know:leftover-server:36644"), "a server something is connected to is offered a Stop, never selected")
    let py = ids(Fixtures.expoOrphan) { _, s in s.procs = s.procs.map { $0.pid == 36644 ? Fixtures.proc(36644, 1, "python3", ago: 10_800, mb: 900) : $0 } }
    check(acts(py).count == 1 && acts(py)[0].hasPrefix("orphan:36644:"), "a python server nobody uses is a row too: \(acts(py))")
    let pyScript = ids(Fixtures.expoOrphan) { _, s in
        s.listening = []
        s.procs = s.procs.map { $0.pid == 36644 ? Fixtures.proc(36644, 1, "python3", ago: 10_800, mb: 900) : $0 }
    }
    check(acts(pyScript).isEmpty && offers(pyScript, "know:leftover:36644"), "a python program serving nothing is offered a Stop")

    print("leftover servers")
    let next = ids(Fixtures.nextOrphan)
    let nextRow = row(next, "orphan:3100:")
    check(acts(next).count == 1 && nextRow?.name == "next dev" && (nextRow?.bytes ?? 0) == 6214 << 20,
          "next dev whose only connections are its own workers is a Tidy up row: \(acts(next)) \(nextRow?.name ?? "")")
    check(nextRow?.why == "Port 3120 in Real Woo AI, from a finished coding session", "its why line names the port and the project: \(nextRow?.why ?? "")")
    let nextUsed = ids(Fixtures.nextOrphan) { _, s in s.clients = [3102: 1] }
    check(acts(nextUsed).isEmpty && offers(nextUsed, "know:leftover-server:3100"), "a browser connected to it makes it a Good to know row with Stop")
    let loopback: [pid_t: Sampler.Sockets] = [
        3102: Sampler.Sockets(listening: [3120], connections: [.init(local: 3120, foreign: 50_001, loopback: true), .init(local: 50_500, foreign: 5432, loopback: true)]),
        3103: Sampler.Sockets(listening: [], connections: [.init(local: 50_001, foreign: 3120, loopback: true)]),
    ]
    check(Sampler.clients(loopback).isEmpty, "its own worker and its own trip to a database are not clients")
    var browsed = loopback
    browsed[3102]?.connections.append(.init(local: 3120, foreign: 51_000, loopback: true))
    browsed[3102]?.connections.append(.init(local: 3120, foreign: 443, loopback: false))
    check(Sampler.clients(browsed) == [3102: 2], "a browser tab on this Mac and a phone on the network are: \(Sampler.clients(browsed))")
    let php = ids(Fixtures.phpSwarm)
    let group = row(php, "orphans:small")
    if case .sigtermAll(let targets) = group?.action {
        check(targets.count == 22 && group?.bytes == 880 << 20 && group?.name == "22 leftover servers", "22 small php servers share one row: \(targets.count) \(group?.name ?? "")")
    } else {
        check(false, "22 small php servers share one row")
    }
    check(group?.why == "Ports 8900 to 8921, from finished coding sessions", "the shared row names the ports: \(group?.why ?? "")")
    if case .sigtermAll(let targets) = row(ids(Fixtures.phpSwarm) { _, s in s.clients = [4005: 1] }, "orphans:small")?.action {
        check(targets.count == 21 && !targets.contains { $0.pid == 4005 }, "one with a client is left out of the group")
    } else {
        check(false, "one with a client is left out of the group")
    }
    check(!acts(php).contains { $0.contains("4100") } && offers(php, "know:leftover-server:4100") && row(php, "know:leftover-server:4100")?.why == Copy.notebook,
          "a notebook server is never a Tidy up row")
    let site = Fixtures.history(Fixtures.phpSwarm).last!
    check(Rules.place(of: site.procs[4000]!, in: site) == "site0" && Rules.serverKey(site.procs[4000]!, in: site) == "server:/Users/me/Ai Projects/Real Woo AI/stores/site0/source",
          "a relative document root is read against the working directory: \(Rules.place(of: site.procs[4000]!, in: site) ?? "nil")")
    check(Rules.serverName(["php", "-S", "127.0.0.1:8902", "-t", "x"], fallback: "php") == "php -S :8902"
          && Rules.serverName(["node", "/opt/homebrew/bin/npm", "run", "dev"], fallback: "node") == "npm run dev"
          && Rules.serverName(["npx", "vite"], fallback: "node") == "vite",
          "launchers read as what they run")

    print("databases and build daemons")
    let db = ids(Fixtures.mysqlOrphan)
    let dbRow = row(db, "know:db:4500:")
    check(acts(db).isEmpty && dbRow?.offer == true && dbRow?.action == .sigterm(pid: 4500, start: Fixtures.now.addingTimeInterval(-340_000)),
          "a leftover mysqld is offered a Stop, never selected: \(db.map(\.id))")
    check(dbRow?.why.contains("alizab-live-8880") == true, "it names the project its data belongs to: \(dbRow?.why ?? "")")
    let dbJob = ids(Fixtures.mysqlOrphan) { _, s in s.jobs[4500] = "homebrew.mxcl.mysql@8.0" }
    check(!knows(dbJob, "know:db:") && acts(dbJob) == ["brew:mysql@8.0"], "one launchd runs is a Homebrew service instead: \(acts(dbJob))")
    check(!knows(ids(Fixtures.mysqlOrphan) { _, s in s.clients = [4500: 1] }, "know:db:"), "one with a client is not mentioned")
    let gradle = ids(Fixtures.gradleDaemon)
    check(acts(gradle).count == 1 && acts(gradle)[0].hasPrefix("daemon:4600:") && row(gradle, "daemon:4600:")?.name == "Gradle daemon" && !knows(gradle, "know:leftover"),
          "an idle Gradle daemon is a Tidy up row, and only that: \(gradle.map(\.id))")
    check(acts(ids(Fixtures.gradleDaemon) { _, s in s.procs = s.procs.map { $0.pid == 4600 ? Fixtures.proc(4600, 1, "java", path: $0.path, ago: 50_000, cpu: 0.6, mb: 900) : $0 } }).isEmpty,
          "a building one is not")
    check(acts(ids(Fixtures.gradleDaemon) { _, s in s.clients = [4600: 1] }).isEmpty, "one an IDE is connected to is not")

    print("sleep")
    let awake = ids(Fixtures.sleepBlocker)
    let vorssaint = row(awake, "know:awake:com.example.vorssaint")
    check(vorssaint?.offer == true && vorssaint?.why == "Vorssaint has kept your Mac awake for 23 hours, so it can't sleep to save power.",
          "an app keeping the Mac awake for a day is offered a Quit: \(vorssaint?.why ?? "nil")")
    check(offers(awake, "know:awake:/usr/bin/caffeinate"), "a forgotten caffeinate is offered a Stop")
    let nameless = ids(Fixtures.sleepBlocker) { _, s in s.apps = s.apps.map { $0.pid == 4700 ? Fixtures.app(4700, "", $0.name, accessory: true) : $0 } }
    check(!nameless.contains { if case .quitApp(let pid, _, _) = $0.action { pid == 4700 } else { false } }, "nor one keeping the Mac awake")
    check(awake.filter { $0.id.hasPrefix("know:awake:") }.count == 2, "Claude, powerd and a twenty-minute hold are not mentioned: \(awake.filter { $0.id.hasPrefix("know:awake:") }.map(\.id))")

    print("test browser")
    let chrome = ids(Fixtures.headlessChrome)
    check(acts(chrome).count == 1 && acts(chrome)[0].hasPrefix("browser:19996:"), "orphaned headless Chrome is the finding: \(acts(chrome))")
    let live = ids(Fixtures.headlessChrome) { _, s in s.procs = s.procs.map { $0.pid == 19996 ? Fixtures.proc(19996, 2646, "Google Chrome", path: $0.path, ago: 17_000, mb: 400) : $0 } }
    check(acts(live).isEmpty && knows(live, "know:testbrowser:19996"), "a script's live browser is explained only")
    check(acts(ids(Fixtures.headlessChrome) { _, s in s.args[19996] = ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "--headless=new", "--user-data-dir=/Users/me/Library/Application Support/Google/Chrome"] }).isEmpty, "a real profile is never touched")

    print("browser tabs and Claude sessions")
    let tabs = ids(Fixtures.chrome40)
    check(acts(tabs).isEmpty && knows(tabs, "know:tabs:com.google.Chrome.beta"), "forty tabs are explained, never closed")
    let claude = ids(Fixtures.claude9)
    check(acts(claude).isEmpty && offers(claude, "know:claude"), "nine Claude sessions are offered, never selected")
    let claudeWhy = claude.first { $0.id == "know:claude" }?.why ?? ""
    check(claudeWhy.contains("Saves") && claudeWhy.contains("YouFixIT") && claudeWhy.count < 140, "quiet sessions are named by project folder: \(claudeWhy)")
    check(ids(Fixtures.claude9) { _, s in s.cwd = [:] }.first { $0.id == "know:claude" }?.why.contains("quiet for half an hour") == true, "without folders the row still says some are quiet")
    let sessions = ids(Fixtures.claude9) { _, s in s.quietSince = [60_000: Fixtures.now.addingTimeInterval(-600)] }.first { $0.id == "know:claude" }
    if case .endSessions(let targets) = sessions?.action {
        check(targets.count == 8 && !targets.contains { $0.pid == 60_000 }, "Close quiet ones takes only sessions quiet for half an hour: \(targets.count)")
    } else {
        check(false, "the Claude row offers to close quiet sessions")
    }
    let shipped = Rules.findings(history: Fixtures.history(Fixtures.claude9), disk: nil, keep: [], tuning: .standard).first { $0.id == "know:claude" }
    check(shipped?.action == nil && shipped?.why.contains("sidebar") == true, "until Close quiet ones is switched on, the Claude row only explains")
    let allBusy = Dictionary(uniqueKeysWithValues: (0..<9).map { (60_000 + pid_t($0), Fixtures.now.addingTimeInterval(-60)) })
    let busySessions = ids(Fixtures.claude9) { _, s in s.quietSince = allBusy }.first { $0.id == "know:claude" }
    check(busySessions?.action == nil && busySessions?.why.contains("sidebar frees memory") == true, "with every session at work there is no button")
    check(claude.first { $0.id == "know:claude" }?.link?.title == Copy.showApp("Claude"), "the Claude row links to Claude")

    print("idle app")
    let ff = ids(Fixtures.freeflowIdle)
    check(acts(ff) == ["app:com.freemans.freeflow"], "FreeFlow untouched for three hours is the finding: \(acts(ff))")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, modal: true) : $0 } }).isEmpty, "an app with a dialog stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, audio: true) : $0 } }).isEmpty, "an app playing audio stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, activatedAgo: 1200) : $0 } }).isEmpty, "touched twenty minutes ago stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, windows: 1) : $0 } }).isEmpty, "a window on screen stays")
    check(acts(ids(Fixtures.freeflowIdle, keep: ["com.freemans.freeflow"])).isEmpty, "a kept app stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, "", $0.name) : $0 } }).isEmpty,
          "an app without a bundle id is never quit")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.frontmost = 7000 }).isEmpty, "the frontmost app stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.procs = s.procs.map { $0.pid == 7000 ? Fixtures.proc(7000, 1, "FreeFlow", path: $0.path, ago: 20_000, mb: 200) : $0 } }).isEmpty, "a small idle app is not worth a row")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.procs = s.procs.map { $0.pid == 7000 ? Fixtures.proc(7000, 1, "FreeFlow", path: $0.path, ago: 20_000, mb: 300) : $0 } }) == ["app:com.freemans.freeflow"], "300 MB idle is worth a row")

    print("working apps stay")
    func exporting(cpu: Double, writing: Bool) -> (Int, inout Fixtures.Spec) -> Void {
        { i, s in s.procs = s.procs.map { $0.pid == 7000 ? Fixtures.proc(7000, 1, "FreeFlow", path: $0.path, ago: 20_000, cpu: cpu, mb: 1300, io: writing ? UInt64(i) * (100 << 20) : 0) : $0 } }
    }
    check(acts(ids(Fixtures.freeflowIdle, tweak: exporting(cpu: 0.2, writing: true))).isEmpty, "an app exporting in the background is never a row")
    check(acts(ids(Fixtures.freeflowIdle, tweak: exporting(cpu: 0, writing: true))).isEmpty, "quiet CPU but heavy disk traffic still means working")
    check(acts(ids(Fixtures.freeflowIdle, tweak: exporting(cpu: 0.2, writing: false))).isEmpty, "steady CPU with no window still means working")
    let working = Fixtures.history(Fixtures.freeflowIdle, tweak: exporting(cpu: 0, writing: true))
    check(Safety.refusal(working.last!.procs[7000]!, app: working.last!.app(7000), in: working.last!, history: working, keep: [], tuning: t) == Copy.refusedBusy,
          "the safety check names the reason: busy")

    print("virtual machines")
    let docker = ids(Fixtures.dockerIdle)
    check(acts(docker) == ["vm:com.docker.docker"], "idle Docker with no containers is the finding: \(acts(docker))")
    check((docker.first { $0.id == "vm:com.docker.docker" }?.bytes ?? 0) >= 3 << 30, "estimate counts the whole machine")
    check(acts(ids(Fixtures.dockerIdle) { _, s in s.containersIdle["com.docker.docker"] = false }).isEmpty, "a running container means in use")
    check(acts(ids(Fixtures.dockerIdle) { _, s in s.containersIdle = [:] }).isEmpty, "no answer from Docker means in use")
    check(acts(ids(Fixtures.dockerIdle) { _, s in s.procs = s.procs.map { $0.pid == 8002 ? Fixtures.proc(8002, 8001, "com.docker.virtualization", path: $0.path, ago: 19_980, cpu: 0.1, mb: 3300) : $0 } }).isEmpty, "a busy machine stays")
    check(acts(ids(Fixtures.dockerIdle) { _, s in s.apps = s.apps.map { $0.pid == 8000 ? Fixtures.app(8000, $0.bundleID, $0.name, launchedAgo: 600, accessory: true) : $0 } }).isEmpty, "opened ten minutes ago is too soon")
    let parallels = ids(Fixtures.dockerIdle) { _, s in
        s.procs.append(Fixtures.proc(8100, 1, "prl_client_app", path: "/Applications/Parallels Desktop.app/Contents/MacOS/prl_client_app", ago: 20_000, mb: 4000))
        s.apps.append(Fixtures.app(8100, "com.parallels.desktop.console", "Parallels Desktop"))
    }
    check(!acts(parallels).contains("app:com.parallels.desktop.console") && knows(parallels, "know:vm:com.parallels.desktop.console"), "Parallels is explained, never quit")

    print("Homebrew services")
    let brew = ids(Fixtures.brewServices)
    check(acts(brew) == ["brew:mysql", "brew:postgresql@16"], "idle services are the findings, one behind a wrapper script included, a 60 MB one not: \(acts(brew))")
    check((brew.first { $0.id == "brew:postgresql@16" }?.bytes ?? 0) == 190 << 20 && (brew.first { $0.id == "brew:mysql" }?.bytes ?? 0) == 402 << 20, "estimates count the whole tree")
    check(brew.first { $0.id == "brew:mysql" }?.action == .stopService(formula: "mysql", pid: 8300, start: Fixtures.now.addingTimeInterval(-29_000)), "the stop names the formula and the job root")
    check(!brew.contains { $0.id == "know:brew" } && !knows(brew, "know:brew:"), "managed services are never explained a second time")
    func pg(_ f: [Finding]) -> (row: Bool, know: Bool) { (acts(f).contains("brew:postgresql@16"), knows(f, "know:brew:postgresql@16")) }
    let pgConnected = ids(Fixtures.brewServices) { _, s in s.clients = [8310: 1] }
    check(pg(pgConnected) == (false, true), "a service something is connected to is explained, not stopped")
    let pgClient = ids(Fixtures.brewServices) { _, s in s.procs.append(Fixtures.proc(8312, 8302, "postgres", path: "/opt/homebrew/opt/postgresql@16/bin/postgres", ago: 120, mb: 20)) }
    check(pg(pgClient) == (false, true), "a fresh child is a client on a unix socket: explained, not stopped")
    let pgBusy = ids(Fixtures.brewServices) { _, s in s.procs = s.procs.map { $0.pid == 8302 ? Fixtures.proc(8302, 1, "postgres", path: $0.path, ago: 29_000, cpu: 0.3, mb: 150) : $0 } }
    check(pg(pgBusy) == (false, true), "a busy service is explained, not stopped")
    let pgYoung = ids(Fixtures.brewServices) { _, s in s.procs = s.procs.map { $0.pid == 8302 ? Fixtures.proc(8302, 1, "postgres", path: $0.path, ago: 240, mb: 150) : $0 } }
    check(pg(pgYoung) == (false, false), "started four minutes ago is too soon")
    let pgKept = ids(Fixtures.brewServices, keep: ["brew:postgresql@16"])
    check(pg(pgKept) == (false, false) && acts(pgKept) == ["brew:mysql"], "a kept service is never mentioned, the others stay")
    let unmanaged = ids(Fixtures.brewServices) { _, s in s.jobs = [:] }
    check(acts(unmanaged).isEmpty && offers(unmanaged, "know:db:8301") && offers(unmanaged, "know:db:8302") && !knows(unmanaged, "know:brewprog"),
          "databases started by hand are offered a Stop each: \(unmanaged.filter { $0.group == .know }.map(\.id))")
    let ollama = ids(Fixtures.quiet) { _, s in s.procs.append(Fixtures.proc(8400, 1, "ollama", path: "/opt/homebrew/Cellar/ollama/0.5.7/bin/ollama", ago: 20_000, mb: 2000)) }
    check(offers(ollama, "know:brewprog:8400") && row(ollama, "know:brewprog:8400")?.why == Copy.brewProgram, "a Homebrew program started by hand gets its own row with Stop")
    check(!knows(ids(Fixtures.quiet) { _, s in
        s.procs.append(Fixtures.proc(8400, 1, "ollama", path: "/opt/homebrew/Cellar/ollama/0.5.7/bin/ollama", ago: 20_000, mb: 2000))
        s.jobs[8400] = "homebrew.mxcl.ollama"
    }, "know:brewprog"), "one launchd runs is left to the service rules")
    let tmux = ids(Fixtures.quiet) { _, s in
        s.procs.append(Fixtures.proc(8500, 1, "tmux", path: "/opt/homebrew/Cellar/tmux/3.5a/bin/tmux", ago: 20_000, mb: 300))
        s.procs.append(Fixtures.proc(8501, 8500, "zsh", path: "/bin/zsh", ago: 20_000, mb: 10))
    }
    check(row(tmux, "know:brewprog") == nil && tmux.allSatisfy { if case .sigterm(let pid, _) = $0.action { pid != 8500 } else { true } },
          "a tmux server holds someone's terminals: never a Stop")
    let launcher = ids(Fixtures.quiet) { _, s in
        s.procs.append(Fixtures.proc(8600, 1, "node", path: "/Users/me/.nvm/versions/node/v22/bin/node", ago: 20_000, mb: 40))
        s.procs.append(Fixtures.proc(8601, 8600, "ollama", path: "/opt/homebrew/Cellar/ollama/0.5.7/bin/ollama", ago: 20_000, mb: 2000))
    }
    check(row(launcher, "know:brewprog") == nil, "a Homebrew program under something else is not a Homebrew row")

    print("menu bar apps")
    let bar = ids(Fixtures.menuBarApps)
    let barRows = bar.filter { $0.id.hasPrefix("know:menubar:") }
    check(acts(bar).isEmpty && barRows.count == 3 && barRows.allSatisfy { if case .quitApp = $0.action { true } else { false } } && barRows.allSatisfy { $0.undoLabel == Copy.reopen },
          "each big quiet menu bar app gets its own row with Quit: \(barRows.map(\.id))")
    check(!knows(ids(Fixtures.menuBarApps) { _, s in s.procs = s.procs.map { $0.pid == 8201 ? Fixtures.proc(8201, 1, "Raycast", path: $0.path, ago: 20_000, mb: 200) : $0 } }, "know:menubar:com.raycast.macos"), "a small one is not mentioned")
    check(!knows(ids(Fixtures.menuBarApps) { _, s in s.procs = s.procs.map { $0.pid == 8201 ? Fixtures.proc(8201, 1, "Raycast", path: $0.path, ago: 20_000, cpu: 0.2, mb: 900) : $0 } }, "know:menubar:com.raycast.macos"), "a working one is not mentioned")
    check(!knows(ids(Fixtures.menuBarApps) { _, s in
        s.procs.append(Fixtures.proc(8204, 1, "Dropbox", path: "/Applications/Dropbox.app/Contents/MacOS/Dropbox", ago: 20_000, mb: 900))
        s.apps.append(Fixtures.app(8204, "com.getdropbox.dropbox", "Dropbox", accessory: true))
    }, "know:menubar:com.getdropbox.dropbox"), "an app you rely on is never offered")

    print("busy programs")
    let busy = ids(Fixtures.busyProgram)
    check(acts(busy).isEmpty && offers(busy, "know:busy:9000"), "a java tree at 90% for minutes is offered a Stop: \(busy.map(\.id).filter { $0.hasPrefix("know:busy") })")
    check(!knows(busy, "know:leftover"), "the busy row is the only row for that process")
    let shell = ids(Fixtures.busyProgram) { _, s in
        s.procs.append(Fixtures.proc(9600, 1, "fish", path: "/opt/homebrew/bin/fish", ago: 9000, mb: 10))
        s.procs = s.procs.map { $0.pid == 9000 ? Fixtures.proc(9000, 9600, "java", path: $0.path, ago: 3000, cpu: 0.9, mb: 800) : $0 }
    }
    check(row(shell, "know:busy:9600") != nil && row(shell, "know:busy:9600")?.action == nil, "a busy terminal is explained, never stopped")
    let building = ids(Fixtures.busyProgram) { _, s in
        s.procs.append(Fixtures.proc(9500, 1, "Xcode", path: "/Applications/Xcode.app/Contents/MacOS/Xcode", ago: 20_000, mb: 2000))
        s.procs = s.procs.map { $0.pid == 9000 ? Fixtures.proc(9000, 9500, "java", path: $0.path, ago: 3000, cpu: 0.9, mb: 800) : $0 }
        s.apps.append(Fixtures.app(9500, "com.apple.dt.Xcode", "Xcode", activatedAgo: 0, windows: 2, active: true))
        s.frontmost = 9500
    }
    check(!knows(building, "know:busy:"), "a build under the app in front is expected work")
    check(!knows(ids(Fixtures.quiet), "know:busy:"), "a quiet Mac has no busy row")

    print("safety")
    let hist = Fixtures.history(Fixtures.simIdle)
    let s = hist.last!
    check(Safety.refusal(Fixtures.proc(400, 1, "mds_stores", path: "/System/Library/x/mds_stores", uid: 0, ago: 100), app: nil, in: s, history: hist, keep: [], tuning: t) != nil, "root process refused")
    check(Safety.refusal(Fixtures.proc(401, 1, "thing", path: "/System/Library/CoreServices/thing", ago: 100), app: nil, in: s, history: hist, keep: [], tuning: t) != nil, "/System path refused")
    check(Safety.refusal(Fixtures.proc(402, 1, "WindowServer", ago: 100), app: nil, in: s, history: hist, keep: [], tuning: t) != nil, "WindowServer refused")
    check(Safety.refusal(s.procs[31542]!, app: s.app(31542), in: s, history: hist, keep: [], tuning: t) != nil, "frontmost app refused")
    check(Safety.refusal(Fixtures.proc(ProcessInfo.processInfo.processIdentifier, 1, "YouFixIt", ago: 100), app: nil, in: s, history: hist, keep: [], tuning: t) != nil, "our own process refused")
    check(Safety.refusal(s.procs[2646]!, app: s.app(2646), in: s, history: hist, keep: [], tuning: t) != nil, "Claude refused")
    check(Safety.refusal(Fixtures.proc(7100, 1, "WhatsApp", path: "/Applications/WhatsApp.app/Contents/MacOS/WhatsApp", ago: 100), app: Fixtures.app(7100, "net.whatsapp.WhatsApp", "WhatsApp"), in: s, history: hist, keep: [], tuning: t) == Copy.refusedEssential, "WhatsApp is essential")
    check(Safety.refusal(Fixtures.proc(7101, 1, "idea", path: "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea", ago: 100), app: Fixtures.app(7101, "com.jetbrains.intellij", "IntelliJ IDEA"), in: s, history: hist, keep: [], tuning: t) == Copy.refusedEssential, "JetBrains apps are essential by prefix")
    check(Safety.refusal(Fixtures.proc(7000, 1, "FreeFlow", path: "/Applications/FreeFlow.app/Contents/MacOS/FreeFlow", ago: 100), app: Fixtures.app(7000, "com.freemans.freeflow", "FreeFlow"), in: s, history: hist, keep: [], tuning: t) == nil, "an ordinary idle app may be acted on")

    print("spike")
    var spike = Spike()
    var fired: [Int] = []
    let pressured = Fixtures.history(Fixtures.simIdle, count: 47) { i, s in s.pressure = (25..<31).contains(i) ? 2 : 1 }
    for i in 1...pressured.count where spike.update(Array(pressured.prefix(i)), tuning: t) { fired.append(i) }
    check(fired == [29], "pressure held for a minute fires once, then stays quiet: \(fired)")
    check(!spike.active, "clears after five quiet minutes")
    check(Nudge.allowed(now: Fixtures.now, lastNudge: Fixtures.now.addingTimeInterval(-600), launchedAt: Fixtures.now.addingTimeInterval(-3600), wokeAt: nil, fullscreen: false, paused: false, mode: .struggling) == false, "no nudge within thirty minutes of the last")
    check(Nudge.allowed(now: Fixtures.now, lastNudge: nil, launchedAt: Fixtures.now.addingTimeInterval(-60), wokeAt: nil, fullscreen: false, paused: false, mode: .struggling) == false, "no nudge in the first two minutes")
    check(Nudge.allowed(now: Fixtures.now, lastNudge: nil, launchedAt: Fixtures.now.addingTimeInterval(-3600), wokeAt: Fixtures.now.addingTimeInterval(-30), fullscreen: false, paused: false, mode: .struggling) == false, "no nudge right after waking")
    check(Nudge.allowed(now: Fixtures.now, lastNudge: nil, launchedAt: Fixtures.now.addingTimeInterval(-3600), wokeAt: nil, fullscreen: true, paused: false, mode: .struggling) == false, "no nudge over a full-screen app")
    check(Nudge.allowed(now: Fixtures.now, lastNudge: Fixtures.now.addingTimeInterval(-7200), launchedAt: Fixtures.now.addingTimeInterval(-9000), wokeAt: nil, fullscreen: false, paused: false, mode: .struggling), "an idle hour later a nudge is fine")
    check(Nudge.allowed(now: Fixtures.now, lastNudge: Fixtures.now.addingTimeInterval(-7200), launchedAt: Fixtures.now.addingTimeInterval(-9000), wokeAt: nil, fullscreen: false, paused: false, mode: .daily) == false, "daily mode waits a day")

    print("disk")
    let space = ids(Fixtures.simIdle, disk: Fixtures.disk)
    check(acts(space).contains("path:/Users/me/Library/Developer/Xcode/DerivedData"), "build cache row")
    check(acts(space).contains("path:/Users/me/.npm/_cacache"), "npm cache row")
    check(acts(space).contains("path:/Users/me/Library/Caches/com.example.goneapp"), "orphan cache row")
    check(!acts(space).contains("path:/Users/me/Library/Caches/pip"), "a small cache is not worth a row")
    check(!acts(space).contains("path:/Users/me/.cache/huggingface") && knows(space, "know:cache:/Users/me/.cache/huggingface"), "a cache that needs reinstalling is explained, not trashed")
    check(!acts(ids(Fixtures.simIdle, disk: Fixtures.disk) { _, s in s.procs.append(Fixtures.proc(95_000, 1, "Xcode", path: "/Applications/Xcode.app/Contents/MacOS/Xcode", ago: 3000)) }).contains("path:/Users/me/Library/Developer/Xcode/DerivedData"), "Xcode open keeps its build cache")
    check(!acts(ids(Fixtures.simIdle, disk: Fixtures.diskBusy)).contains("path:/Users/me/Library/Developer/Xcode/DerivedData"), "a cache being written to is not a row")
    check(!acts(ids(Fixtures.simIdle, disk: Fixtures.disk) { _, s in s.procs.append(Fixtures.proc(95_001, 1, "GoneApp", path: "/Users/me/Applications/GoneApp.app/Contents/MacOS/GoneApp", ago: 3000)) }).contains("path:/Users/me/Library/Caches/com.example.goneapp"),
          "a cache whose program is running is not an orphan")

    print("good to know")
    let heavy = ids(Fixtures.heavy, disk: Fixtures.disk)
    let knowBuckets = heavy.filter { $0.group == .know }.map { $0.bytes / (100 << 20) }
    check(knowBuckets == knowBuckets.sorted(by: >), "Good to know reads biggest first: \(knowBuckets)")
    check(heavy.firstIndex { $0.group == .know }.map { i in heavy[..<i].allSatisfy { $0.group != .know } } == true, "explain-only rows come after the rows with a button")
    check(acts(heavy).contains("brew:postgresql@16"), "the heavy Mac has a service row: \(acts(heavy))")
    let tabsLink = heavy.first { $0.id == "know:tabs:com.google.Chrome.beta" }?.link
    check(tabsLink?.title == "Show Google Chrome Beta" && tabsLink?.url.contains("Google%20Chrome%20Beta.app") == true, "a browser row links to the browser: \(tabsLink?.url ?? "nil")")
    check(heavy.first { $0.id == "know:cache:/Users/me/.cache/huggingface" }?.link?.url == "/Users/me/.cache/huggingface", "a cache row links to its folder")
    check(heavy.first { $0.id == "know:trash" } == nil || heavy.first { $0.id == "know:trash" }?.link?.url.hasPrefix("file://") == true, "the Trash row opens the Trash")
    check(ids(Fixtures.busyProgram).first { $0.id == "know:busy:9000" }?.link?.title == Copy.activityMonitorLink, "a busy program that is not an app links to Activity Monitor")

    print("worktrees and downloads")
    let more = ids(Fixtures.simIdle, disk: Fixtures.diskMore) { _, s in s.cwd[60_000] = "\(Fixtures.worktrees)/agent-a3/platform" }
    let finished = row(more, "worktrees:")
    if case .trashAll(let targets) = finished?.action {
        check(finished?.actionable == true && targets.map(\.path) == ["\(Fixtures.worktrees)/agent-a1", "\(Fixtures.worktrees)/agent-a2"] && targets.allSatisfy { $0.check == .mergedWorktree },
              "finished worktrees are one Tidy up row, the one a session sits in left out: \(targets.map(\.path))")
    } else {
        check(false, "finished worktrees are one Tidy up row")
    }
    check(finished?.name == "Finished worktrees in Real Woo AI" && finished?.bytes == 1600 << 20, "named after the project, sized by what goes: \(finished?.name ?? "") \(finished?.bytes ?? 0)")
    check(offers(more, "know:worktrees-unmerged:"), "unmerged ones are offered, never selected")
    if case .trashAll(let targets) = row(more, "know:worktrees-unmerged:")?.action {
        check(targets.count == 2 && targets.allSatisfy { $0.check == .worktree }, "unmerged ones move as one, checked again when pressed")
    } else {
        check(false, "unmerged worktrees move as one")
    }
    check(row(more, "know:worktrees-unmerged:")?.why.contains("Local files") == true, "and the row says local files go with them")
    let localRow = row(more, "know:worktrees-local:")
    if case .trashAll(let targets) = localRow?.action {
        check(localRow?.offer == true && targets.map(\.path) == ["\(Fixtures.worktrees)/env-d1"] && targets.allSatisfy { $0.check == .worktree },
              "merged ones holding local files are offered, never selected: \(targets.map(\.path))")
    } else {
        check(false, "merged worktrees with local files are offered")
    }
    let never: (String) -> Bool = { _ in false }
    let empty: (String) -> [String]? = { _ in [] }
    func keeps(_ status: String, copy: (String) -> Bool = never, inside: (String) -> [String]? = empty) -> DiskScan.Keeps {
        DiskScanner.keeps(status, isCopy: copy, inside: inside)
    }
    check(keeps("") == .nothing && keeps("!! node_modules/\0!! .next/\0!! packages/web/dist/\0!! .DS_Store\0!! src/generated/\0") == .nothing
          && keeps("!! .claude/settings.local.json\0!! .claude/launch.json\0!! logs/dev.log\0!! tsconfig.tsbuildinfo\0") == .nothing,
          "build output, dependencies, generated code and logs regrow, so a worktree holding only them keeps nothing")
    check(keeps(" M src/app.ts\0") == .work && keeps("?? notes.md\0") == .work && keeps("R  new.ts\0old.ts\0") == .work
          && keeps("!! .env.local\0 M a.ts\0") == .work, "a change, a new file or a rename is work")
    check(keeps("!! .env.local\0") == .local && keeps("!! .env.local\0", copy: { $0 == ".env.local" }) == .nothing,
          "an ignored file is local unless the main checkout has the same one")
    check(keeps("!! .claude/\0", inside: { _ in ["settings.local.json", "launch.json", "skills/a.md"] }) == .local
          && keeps("!! .claude/\0", copy: { $0 == ".claude/skills/a.md" }, inside: { _ in ["settings.local.json", "skills/a.md"] }) == .nothing
          && keeps("!! .gstack/\0", inside: { _ in nil }) == .local,
          "an ignored folder is looked into, and one too big to look through counts as local")
    check(DiskScanner.worktreeProject("/Users/me/p/.claude/worktrees/a1") == "/Users/me/p" && DiskScanner.worktreeProject("/Users/me/p/a1") == nil,
          "a worktree's project is the folder that holds .claude/worktrees")
    check(knows(more, "know:worktrees-dirty:") && !offers(more, "know:worktrees-dirty:") && row(more, "know:worktrees-dirty:")?.link?.title == Copy.showFolder,
          "ones with uncommitted changes are only explained, with Show in Finder")
    if case .trashAll(let targets) = row(more, "npx")?.action {
        check(targets.count == 2 && targets.allSatisfy { $0.check == .unused } && row(more, "npx")?.actionable == true, "old npx downloads are one row, the recently used one left out")
    } else {
        check(false, "old npx downloads are one row")
    }
    check(row(more, "claude-temp")?.actionable == true, "Claude's old scratch folders are one row")
    check(offers(more, "know:appcache:com.spotify.client"), "a big app cache is offered while the app is closed")
    let spotify = ids(Fixtures.simIdle, disk: Fixtures.diskMore) { _, s in
        s.procs.append(Fixtures.proc(4800, 1, "Spotify", path: "/Applications/Spotify.app/Contents/MacOS/Spotify", ago: 9000, mb: 400))
        s.apps.append(Fixtures.app(4800, "com.spotify.client", "Spotify"))
    }
    check(knows(spotify, "know:appcache:") && !offers(spotify, "know:appcache:"), "and only explained while it runs")
    check(row(more, "know:runtime:")?.action?.irreversible == true && row(more, "know:device:")?.action?.irreversible == true, "removing a simulator asks first")
    let ledger = Rules.findings(history: Fixtures.history(Fixtures.quiet), disk: nil, keep: [], tuning: t, trashed: 4 << 30)
    check(row(ledger, "know:trash")?.action == .emptyTrash && row(ledger, "know:trash")?.bytes == 4 << 30, "what YouFixIt moved to the Trash brings the Trash row")
    check(Rules.findings(history: Fixtures.history(Fixtures.quiet), disk: Fixtures.disk, keep: [], tuning: t, trashed: 4 << 30).filter { $0.id == "know:trash" }.count == 1,
          "never two Trash rows")
    check(row(Rules.findings(history: Fixtures.history(Fixtures.quiet), disk: nil, keep: [], tuning: t, trashed: 100 << 20), "know:trash") == nil, "a little in the Trash is not worth a row")

    print("buttons")
    let everything = ids(Fixtures.heavy, disk: Fixtures.disk) + ids(Fixtures.simIdle, disk: Fixtures.diskMore) + ids(Fixtures.busyProgram) + ids(Fixtures.mysqlOrphan)
        + ids(Fixtures.sleepBlocker) + ids(Fixtures.phpSwarm) + ids(Fixtures.expoOrphan) { _, s in s.listening = [] }
    let withButton = ["know:claude", "know:menubar:", "know:busy:", "know:db:", "know:awake:", "know:cache:", "know:appcache:", "know:trash",
                      "know:runtime:", "know:device:", "know:worktrees-unmerged:", "know:worktrees-local:", "know:leftover"]
    let explainOnly = ["know:tabs:", "know:spotlight", "know:memory", "know:backlog", "know:worktrees-dirty:"]
    for prefix in withButton {
        let rows = everything.filter { $0.id.hasPrefix(prefix) }
        check(!rows.isEmpty && rows.allSatisfy(\.offer), "\(prefix) rows have a button (\(rows.count))")
    }
    for prefix in explainOnly {
        let rows = everything.filter { $0.id.hasPrefix(prefix) }
        check(!rows.isEmpty && rows.allSatisfy { $0.action == nil }, "\(prefix) rows only explain (\(rows.count))")
    }
    check(everything.filter(\.offer).allSatisfy { !$0.actionable }, "a row with a Good to know button is never a Tidy up row")
    let mock = Engine()
    mock.startMock(named: "heavy")
    check(!mock.know.filter(\.offer).isEmpty && mock.selected.allSatisfy { id in mock.findings.first { $0.id == id }?.group != .know }
          && mock.actionable.allSatisfy { $0.group != .know }, "Good to know rows are never selected or counted")

    print("explicit presses")
    let pressed = Fixtures.history(Fixtures.freeflowIdle, tweak: exporting(cpu: 0, writing: true))
    let last = pressed.last!
    check(Safety.refusal(last.procs[7000]!, app: last.app(7000), in: last, history: pressed, keep: [], tuning: t, strict: false) == nil, "a press skips the busy check")
    let recent = Fixtures.history(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, activatedAgo: 600) : $0 } }
    check(Safety.refusal(recent.last!.procs[7000]!, app: recent.last!.app(7000), in: recent.last!, history: recent, keep: [], tuning: t, strict: false) == nil, "and the used-within-the-hour check")
    func pressRefusal(_ tweak: @escaping (Int, inout Fixtures.Spec) -> Void) -> String? {
        let h = Fixtures.history(Fixtures.freeflowIdle, tweak: tweak)
        return Safety.refusal(h.last!.procs[7000]!, app: h.last!.app(7000), in: h.last!, history: h, keep: [], tuning: t, strict: false)
    }
    check(pressRefusal { _, s in s.frontmost = 7000 } == Copy.refusedInUse, "but never quits the app in front")
    check(pressRefusal { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, modal: true) : $0 } } == Copy.refusedDialog, "or one with a dialog open")
    check(pressRefusal { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, audio: true) : $0 } } == Copy.refusedAudio, "or one playing audio")
    check(Safety.refusal(Fixtures.proc(7100, 1, "WhatsApp", path: "/Applications/WhatsApp.app/Contents/MacOS/WhatsApp", ago: 100), app: Fixtures.app(7100, "net.whatsapp.WhatsApp", "WhatsApp"),
                         in: last, history: pressed, keep: [], tuning: t, strict: false) == Copy.refusedEssential, "or one you rely on")
    check(Safety.system("/usr/bin/caffeinate") == false && Safety.system("/usr/bin/ssh-agent") && Safety.system("/System/Library/x"), "only stateless system tools may be stopped")

    print("wording")
    check(Format.size(1300 << 20) == "1.3 GB" && Format.size(900 << 20) == "900 MB" && Format.size(22 << 30) == "22 GB" && Format.size(9 << 30) == "9 GB",
          "sizes read as people say them: \(Format.size(1300 << 20)) \(Format.size(900 << 20)) \(Format.size(22 << 30)) \(Format.size(9 << 30))")
    check(Copy.frees(memory: 3400 << 20, space: 9 << 30) == "Frees about 3.3 GB of memory and 9 GB of space", "button caption: \(Copy.frees(memory: 3400 << 20, space: 9 << 30))")
    for f in everything + ids(Fixtures.nextOrphan) + ids(Fixtures.gradleDaemon) + ids(Fixtures.claude9) + ids(Fixtures.brewServices) { _, s in s.jobs = [:] } {
        check(!f.why.contains("—") && !f.why.contains("!") && f.why.count < 140 && !f.name.contains("—"), "plain why line for \(f.id) (\(f.why.count))")
    }
    for action: Finding.Action in [.emptyTrash, .restart, .stopBackup, .deleteRuntime(id: "x"), .endSessions([]), .trashAll([]), .sigtermAll([])] {
        let line = Copy.acted(action, name: "mysqld", freed: 778 << 20)
        check(!line.contains("—") && !line.contains("!") && Copy.verb(action).count <= 18, "plain button and done line: \(Copy.verb(action)) / \(line)")
    }

    for action: Finding.Action in [.emptyTrash, .deleteRuntime(id: "x"), .deleteDevice(udid: "y")] {
        let note = Copy.confirmNote(action)
        check(note.hasSuffix("This can't be undone.") && !note.contains("—") && !note.contains("!") && note.count < 140, "plain confirm: \(note)")
    }

    print(failures == 0 ? "selftest passed" : "selftest FAILED: \(failures)")
    exit(failures == 0 ? 0 : 1)
}
