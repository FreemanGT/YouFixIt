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
        var managed: Set<pid_t> = []
        var args: [pid_t: [String]] = [:]
        var listening: Set<pid_t> = []
        var established: [pid_t: Int] = [:]
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
            return Sample(at: at, procs: procs, children: children, apps: spec.apps, sims: spec.sims, managedPids: spec.managed,
                          args: spec.args, listening: spec.listening, established: spec.established, containersIdle: spec.containersIdle,
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

    /// Nine Claude Code sessions holding 4.5 GB: explained, never touched.
    static var claude9: Spec {
        var s = quiet
        s.procs += (0..<9).map { proc(60_000 + pid_t($0), 2646, "claude", path: "/Users/me/Library/Application Support/Claude/claude-code/2.1.289/x/claude.app/Contents/MacOS/claude", ago: 18_000, mb: 500) }
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

    /// mysql (through mysqld_safe), postgres and redis started by launchd from Homebrew.
    static var brewServices: Spec {
        var s = quiet
        s.procs += [
            proc(8300, 1, "sh", path: "/bin/sh", ago: 29_000, mb: 2),
            proc(8301, 8300, "mysqld", path: "/opt/homebrew/opt/mysql/bin/mysqld", ago: 29_000, mb: 400),
            proc(8302, 1, "postgres", path: "/opt/homebrew/opt/postgresql@16/bin/postgres", ago: 29_000, mb: 150),
            proc(8303, 1, "redis-server", path: "/opt/homebrew/opt/redis/bin/redis-server", ago: 29_000, mb: 60),
        ]
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
        s.procs += dockerIdle.procs.filter { $0.pid >= 8000 && $0.pid < 8100 }
        s.apps.append(contentsOf: dockerIdle.apps.filter { $0.pid == 8000 })
        s.containersIdle = dockerIdle.containersIdle
        s.procs += brewServices.procs.filter { $0.pid >= 8300 && $0.pid < 8400 }
        s.procs += menuBarApps.procs.filter { $0.pid >= 8200 && $0.pid < 8300 }
        s.apps.append(contentsOf: menuBarApps.apps)
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
        case "heavy": heavy
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
    let t = Tuning.standard
    func ids(_ spec: Fixtures.Spec, keep: Set<String> = [], disk: DiskScan? = nil, tweak: (Int, inout Fixtures.Spec) -> Void = { _, _ in }) -> [Finding] {
        Rules.findings(history: Fixtures.history(spec, tweak: tweak), disk: disk, keep: keep, tuning: t)
    }
    func acts(_ f: [Finding]) -> [String] { f.filter(\.actionable).map(\.id).sorted() }
    func knows(_ f: [Finding], _ prefix: String) -> Bool { f.contains { !$0.actionable && $0.id.hasPrefix(prefix) } }

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
    check(acts(ids(Fixtures.expoOrphan) { _, s in
        s.procs.append(Fixtures.proc(61_356, 2646, "claude", ago: 12_000))
        s.procs = s.procs.map { $0.pid == 36644 ? Fixtures.proc(36644, 61_356, "node", path: $0.path, ago: 10_800, mb: 300) : $0 }
    }).isEmpty, "a server whose Claude session is alive is in use")
    check(acts(ids(Fixtures.expoOrphan) { _, s in s.managed.insert(36644) }).isEmpty, "a launchd job is not an orphan")
    check(acts(ids(Fixtures.expoOrphan) { _, s in s.procs = s.procs.map { $0.pid == 36644 ? Fixtures.proc(36644, 1, "node", path: "/Applications/Stremio.app/Contents/MacOS/node", ago: 10_800, mb: 300) : $0 } }).isEmpty, "node inside an app bundle belongs to that app")
    let watcher = ids(Fixtures.expoOrphan) { _, s in s.listening = [] }
    check(acts(watcher).isEmpty && knows(watcher, "know:leftover-watcher:36644"), "no listening socket, no server: a watcher is explained only")
    let connected = ids(Fixtures.expoOrphan) { _, s in s.established = [36677: 1] }
    check(acts(connected).isEmpty && knows(connected, "know:leftover-server:36644"), "a server something is connected to is explained, not stopped")
    let py = ids(Fixtures.expoOrphan) { _, s in s.procs = s.procs.map { $0.pid == 36644 ? Fixtures.proc(36644, 1, "python3", ago: 10_800, mb: 900) : $0 } }
    check(acts(py).isEmpty && knows(py, "know:leftover:36644"), "a python leftover is explained, not stopped")

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
    check(acts(claude).isEmpty && knows(claude, "know:claude"), "nine Claude sessions are explained, never closed")

    print("idle app")
    let ff = ids(Fixtures.freeflowIdle)
    check(acts(ff) == ["app:com.freemans.freeflow"], "FreeFlow untouched for three hours is the finding: \(acts(ff))")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, modal: true) : $0 } }).isEmpty, "an app with a dialog stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, audio: true) : $0 } }).isEmpty, "an app playing audio stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, activatedAgo: 1200) : $0 } }).isEmpty, "touched twenty minutes ago stays")
    check(acts(ids(Fixtures.freeflowIdle) { _, s in s.apps = s.apps.map { $0.pid == 7000 ? Fixtures.app(7000, $0.bundleID, $0.name, windows: 1) : $0 } }).isEmpty, "a window on screen stays")
    check(acts(ids(Fixtures.freeflowIdle, keep: ["com.freemans.freeflow"])).isEmpty, "a kept app stays")
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

    print("background services and menu bar apps")
    let brew = ids(Fixtures.brewServices)
    check(acts(brew).isEmpty && brew.contains { $0.id == "know:brew" && $0.why.contains("mysqld") && $0.why.contains("redis-server") }, "Homebrew services are explained: \(brew.filter { $0.id == "know:brew" }.map(\.why))")
    let bar = ids(Fixtures.menuBarApps)
    check(acts(bar).isEmpty && bar.contains { $0.id == "know:menubar" && $0.why.contains("Raycast") }, "menu bar apps holding memory are explained")
    check(!knows(ids(Fixtures.menuBarApps) { _, s in s.procs = s.procs.map { $0.pid == 8201 ? Fixtures.proc(8201, 1, "Raycast", path: $0.path, ago: 20_000, mb: 200) : $0 } }, "know:menubar"), "under a gigabyte and a half is not worth a row")

    print("busy programs")
    let busy = ids(Fixtures.busyProgram)
    check(acts(busy).isEmpty && knows(busy, "know:busy:9000"), "a java tree at 90% for minutes is explained: \(busy.map(\.id).filter { $0.hasPrefix("know:busy") })")
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

    print("wording")
    check(Format.size(1300 << 20) == "1.3 GB" && Format.size(900 << 20) == "900 MB" && Format.size(22 << 30) == "22 GB" && Format.size(9 << 30) == "9 GB",
          "sizes read as people say them: \(Format.size(1300 << 20)) \(Format.size(900 << 20)) \(Format.size(22 << 30)) \(Format.size(9 << 30))")
    check(Copy.frees(memory: 3400 << 20, space: 9 << 30) == "Frees about 3.3 GB of memory and 9 GB of space", "button caption: \(Copy.frees(memory: 3400 << 20, space: 9 << 30))")
    for f in ids(Fixtures.heavy, disk: Fixtures.disk) + ids(Fixtures.busyProgram) {
        check(!f.why.contains("—") && !f.why.contains("!") && f.why.count < 140, "plain why line for \(f.id) (\(f.why.count))")
    }

    print(failures == 0 ? "selftest passed" : "selftest FAILED: \(failures)")
    exit(failures == 0 ? 0 : 1)
}
