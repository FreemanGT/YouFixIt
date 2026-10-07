import Foundation

/// One snapshot of the Mac. Plain data built off the main actor, read by the rules.
struct Sample: Sendable {
    struct Proc: Sendable {
        let pid: pid_t
        let ppid: pid_t
        let uid: uid_t
        let name: String        // last path component, or the kernel's short name
        let path: String        // "" when unreadable
        let start: Date
        let cpu: Double         // fraction of one core since the previous sample (0.25 = 25%); 0 on the first sample
        let footprint: UInt64   // ri_phys_footprint for our own processes, resident size for others
    }

    struct App: Sendable {
        let pid: pid_t
        let bundleID: String
        let name: String
        let url: URL?
        let regular: Bool       // NSApplication.ActivationPolicy.regular (shows in the Dock)
        let hidden: Bool
        let active: Bool
        let launched: Date?
        let lastActivated: Date?
        let windows: Int        // normal windows (layer 0) on any Space, minimized ones included
        let hasModal: Bool      // an on-screen modal panel (layer 8)
        let audio: Bool         // CoreAudio reports it is producing output right now
    }

    struct Sim: Sendable {
        let udid: String
        let name: String
        let runtime: String     // "iOS 26.5"
        let launchdPid: pid_t?
        let lastUsed: Date?
    }

    let at: Date
    let procs: [pid_t: Proc]
    let children: [pid_t: [pid_t]]
    let apps: [App]
    let sims: [Sim]
    let managedPids: Set<pid_t>     // launchd-managed jobs (only gathered when orphan candidates exist)
    let args: [pid_t: [String]]     // only for candidate pids (our user, parent pid 1)
    let listening: Set<pid_t>       // candidate pids with a listening TCP socket
    let frontmost: pid_t
    let fullscreen: Bool            // the frontmost app covers the main display
    let cpuBusy: Double             // 0...1, system wide
    let load1: Double
    let cores: Int
    let memUsed: UInt64
    let memTotal: UInt64
    let compressed: UInt64
    let swapUsed: UInt64
    let pressure: Int               // kern.memorystatus_vm_pressure_level: 1 normal, 2 warn, 4 critical
    let thermal: Int                // ProcessInfo.ThermalState.rawValue
    let booted: Date
    let loggedIn: Date?

    /// A process and all its descendants.
    func tree(_ pid: pid_t) -> [Proc] {
        var out: [Proc] = []
        var queue = [pid]
        while let next = queue.popLast() {
            if let p = procs[next] { out.append(p) }
            queue.append(contentsOf: children[next] ?? [])
        }
        return out
    }

    func footprint(of pid: pid_t) -> UInt64 { tree(pid).reduce(0) { $0 + $1.footprint } }
    func cpu(of pid: pid_t) -> Double { tree(pid).reduce(0) { $0 + $1.cpu } }
    func app(_ pid: pid_t) -> App? { apps.first { $0.pid == pid } }
    func app(bundle id: String) -> App? { apps.first { $0.bundleID == id } }
    func procs(named name: String) -> [Proc] { procs.values.filter { $0.name == name } }
    var uptime: TimeInterval { at.timeIntervalSince(booted) }
}

/// What the AppKit side knows about a running app; built on the main actor and handed to the sampler.
struct AppSeed: Sendable {
    let pid: pid_t
    let bundleID: String
    let name: String
    let url: URL?
    let regular: Bool
    let hidden: Bool
    let active: Bool
    let launched: Date?
    let lastActivated: Date?
}

/// Everything the rules can be tuned with. `--scan --window N` scales the idle thresholds.
struct Tuning: Sendable {
    var idle: TimeInterval = 600          // simulators, dev servers: quiet for this long
    var appIdle: TimeInterval = 3600      // apps: not activated for this long
    var sustain: TimeInterval = 120       // spike conditions must hold this long
    var diskMin: UInt64 = 500 << 20       // disk rows under this are not worth a row
    var appMin: UInt64 = 400 << 20        // idle apps under this footprint are left alone
    static let standard = Tuning()
}

/// Something the app can do, or just say, about one thing on the Mac.
struct Finding: Identifiable, Sendable, Equatable {
    enum Group: Sendable { case running, space, know }

    enum Action: Sendable, Equatable {
        case shutdownSim(udid: String)
        case quitApp(pid: pid_t, bundleID: String, url: URL?)
        case sigterm(pid: pid_t, start: Date)
        case trash(path: String)
        case deleteUnavailableSims
    }

    let id: String                  // stable across scans: "sim:UDID", "app:bundle", "orphan:pid:start", "path:/…", "know:kind"
    let keepKey: String             // what "Keep" remembers: a bundle id, an executable path, a folder, a device UDID
    let group: Group
    let name: String                // "Saves Store 6.9", "FreeFlow", "Xcode build cache"
    let why: String                 // one plain line
    let bytes: UInt64               // memory it holds, or disk it takes
    let action: Action?             // nil = explain only
    let undoLabel: String?          // "Boot again", "Reopen", "Put back"
    let link: Link?                 // for explain-only rows: where to go
    let iconPath: String?           // app bundle path for the icon; nil = SF Symbol by group
    let symbol: String              // SF Symbol name when there is no app icon

    struct Link: Sendable, Equatable {
        let title: String
        let url: String
    }

    var actionable: Bool { action != nil }

    static func == (a: Finding, b: Finding) -> Bool { a.id == b.id && a.bytes == b.bytes && a.why == b.why }
}

/// What happened to one finding after the button.
enum Outcome: Sendable, Equatable {
    case done
    case askedToSave      // the app opened a dialog instead of quitting; left alone
    case stillRunning     // did not go away in time; left alone
    case refused(String)  // the safety re-check said no
    case failed(String)
}

/// What the disk side knows. Measured slowly and rarely; nil until the first measurement lands.
struct DiskScan: Sendable {
    enum Kind: Sendable { case derivedData, deviceSupport, devCache, orphanCache, installer, trash, runtime, oldDevice }
    struct Item: Sendable {
        let kind: Kind
        let path: String
        let name: String
        let bytes: UInt64
        let modified: Date?
    }
    let at: Date
    let items: [Item]
    let unavailableSims: Int
    let freeBytes: UInt64
    let totalBytes: UInt64
}
