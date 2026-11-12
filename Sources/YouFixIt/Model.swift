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
        let diskIO: UInt64      // bytes read plus written so far (rusage); 0 for other users' processes
    }

    struct App: Sendable {
        let pid: pid_t
        let bundleID: String
        let name: String
        let url: URL?
        let regular: Bool       // NSApplication.ActivationPolicy.regular (shows in the Dock)
        let accessory: Bool     // .accessory: a menu bar app
        let hidden: Bool
        let active: Bool
        let launched: Date?
        let lastActivated: Date?
        let windows: Int        // normal windows (layer 0) on any Space, minimized ones included
        let hasModal: Bool      // an on-screen modal panel (layer 8)
        let audio: Bool         // CoreAudio reports it is producing output right now
    }

    /// A power assertion that keeps the Mac from sleeping, credited to the process it is held for.
    struct Assertion: Sendable {
        let pid: pid_t          // the on-behalf-of process when there is one (runningboardd, coreaudiod hold them for apps)
        let type: String        // "PreventUserIdleSystemSleep", "NoIdleSleepAssertion", …
        let name: String
        let since: Date
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
    let jobs: [pid_t: String]       // launchd jobs by pid, with their label (only gathered when orphan or Homebrew candidates exist)
    let args: [pid_t: [String]]     // only for candidate pids (our user, parent pid 1)
    let cwd: [pid_t: String]        // working directory, only for Claude coding sessions
    let listening: Set<pid_t>       // candidate pids with a listening TCP socket
    let ports: [pid_t: [Int]]       // candidate pids: the TCP ports they listen on
    let clients: [pid_t: Int]       // candidate pids: connections from outside their tree to one of its listening ports
    let containersIdle: [String: Bool]  // VM app bundle id: true when its Docker socket reports no containers
    let assertions: [Assertion]     // sleep-preventing power assertions, read once a minute
    let quietSince: [pid_t: Date]   // Claude coding sessions: when their tree last used CPU (or when watching began)
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
    func io(of pid: pid_t) -> UInt64 { tree(pid).reduce(0) { $0 + $1.diskIO } }
    func app(_ pid: pid_t) -> App? { apps.first { $0.pid == pid } }
    func app(bundle id: String) -> App? { apps.first { $0.bundleID == id } }
    func procs(named name: String) -> [Proc] { procs.values.filter { $0.name == name } }
    var uptime: TimeInterval { at.timeIntervalSince(booted) }

    /// The topmost ancestor below launchd that we own; nil when the chain leaves our user.
    func root(of pid: pid_t) -> Proc? {
        guard var p = procs[pid], p.uid == Sampler.me else { return nil }
        while p.ppid != 1, let parent = procs[p.ppid], parent.uid == Sampler.me { p = parent }
        return p
    }
}

/// What the AppKit side knows about a running app; built on the main actor and handed to the sampler.
struct AppSeed: Sendable {
    let pid: pid_t
    let bundleID: String
    let name: String
    let url: URL?
    let regular: Bool
    let accessory: Bool
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
    var appMin: UInt64 = 250 << 20        // idle apps under this footprint are left alone
    var busyIO: Double = 1_048_576        // bytes per second of disk traffic that means "working"
    var orphanAge: TimeInterval = 900     // leftovers: adopted by launchd at least this long ago
    var sessionQuiet: TimeInterval = 1800 // Claude sessions: no CPU for this long counts as quiet
    var awakeHold: TimeInterval = 3600    // sleep blockers: held this long before they are mentioned
    var barAppMin: UInt64 = 400 << 20     // menu bar apps under this footprint are not mentioned
    /// "Close quiet ones" on the Claude row. Off until a live check shows Claude picks an ended session up again.
    var closeQuietSessions = false
    static let standard = Tuning()
}

/// Something the app can do, or just say, about one thing on the Mac.
struct Finding: Identifiable, Sendable, Equatable {
    enum Group: Sendable { case running, space, know }

    /// One process to signal, pinned by its start time so a reused pid is never hit.
    struct Target: Sendable, Equatable {
        let pid: pid_t
        let start: Date
        var bytes: UInt64 = 0
    }

    /// One folder to move to the Trash, what it holds, and what to re-check right before it moves.
    struct TrashTarget: Sendable, Equatable {
        enum Check: Sendable, Equatable {
            case written    // nothing written inside in the last ten minutes
            case worktree   // a git worktree: still clean, quiet, nothing running inside
            case unused     // nothing running from it (npx packages)
        }
        let path: String
        let bytes: UInt64
        let check: Check
    }

    enum Action: Sendable, Equatable {
        case shutdownSim(udid: String)
        case quitApp(pid: pid_t, bundleID: String, url: URL?)
        case sigterm(pid: pid_t, start: Date)
        case sigtermAll([Target])
        case endSessions([Target])
        case stopService(formula: String, pid: pid_t, start: Date)
        case trash(path: String)
        case trashAll([TrashTarget])
        case deleteUnavailableSims
        case stopBackup
        case restart
        case emptyTrash
        case deleteRuntime(id: String)
        case deleteDevice(udid: String)

        /// Gone for good once done: asked about once, inline, before it runs.
        var irreversible: Bool {
            switch self {
            case .emptyTrash, .deleteRuntime, .deleteDevice: true
            default: false
            }
        }
    }

    let id: String                  // stable across scans: "sim:UDID", "app:bundle", "vm:bundle", "orphan:pid:start", "brew:formula", "path:/…", "know:kind"
    let keepKey: String             // what "Keep" remembers: a bundle id, an executable path, a folder, a device UDID
    let group: Group
    let name: String                // "Saves Store 6.9", "FreeFlow", "Xcode build cache"
    let why: String                 // one plain line
    let bytes: UInt64               // memory it holds, or disk it takes
    let action: Action?             // nil = explain only
    let undoLabel: String?          // "Boot again", "Reopen", "Put back"
    let link: Link?                 // for explain-only rows: where to go (a URL is opened, a bare path is shown in Finder)
    let iconPath: String?           // app bundle path for the icon; nil = SF Symbol by group
    let symbol: String              // SF Symbol name when there is no app icon

    struct Link: Sendable, Equatable {
        let title: String
        let url: String
    }

    /// A Tidy up row: selected by default, counted in the menu bar, part of the mood and the nudge.
    var actionable: Bool { action != nil && group != .know }
    /// A Good to know row with a button of its own: never selected, never counted, only done when pressed.
    var offer: Bool { action != nil && group == .know }

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
    enum Kind: Sendable { case derivedData, deviceSupport, previews, simCache, devCache, otherCache, orphanCache, installer, trash, runtime, oldDevice,
                          worktree, npx, claudeTemp, appCache }
    /// A Claude worktree that has been quiet for a day with nothing running inside: what its git state allows.
    enum Worktree: Sendable { case finished, unmerged, dirty }
    struct Item: Sendable {
        let kind: Kind
        let path: String
        let name: String
        let bytes: UInt64
        let modified: Date?
        var busy = false    // something wrote inside it recently (10 min for caches, 30 days for orphan caches)
        var owner: String? = nil        // worktrees: the project folder; app caches: the app's bundle id
        var state: Worktree? = nil      // worktrees only
    }
    let at: Date
    let items: [Item]
    let unavailableSims: Int
    let freeBytes: UInt64
    let totalBytes: UInt64
}
