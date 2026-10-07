import AppKit
import Observation

/// When a nudge may interrupt. Pure, so the self-test can pin it down.
enum Nudge {
    enum Mode: String { case struggling, daily, never }
    nonisolated static let modeKey = "nudgeMode"
    nonisolated static let lastKey = "lastNudgeAt"

    static func allowed(now: Date, lastNudge: Date?, launchedAt: Date, wokeAt: Date?, fullscreen: Bool, paused: Bool, mode: Mode) -> Bool {
        guard mode != .never, !paused, !fullscreen else { return false }
        guard now.timeIntervalSince(launchedAt) >= 120 else { return false }
        if let wokeAt, now.timeIntervalSince(wokeAt) < 120 { return false }
        let gap: TimeInterval = mode == .daily ? 86_400 : 1800
        if let lastNudge, now.timeIntervalSince(lastNudge) < gap { return false }
        return true
    }
}

/// The app's state: samples in, findings and mood out, actions on request.
@MainActor @Observable
final class Engine {
    enum Mood: Equatable { case scanning, calm, light, heavy, working, done, paused }

    struct Row: Identifiable, Equatable {
        let finding: Finding
        let outcome: Outcome
        var id: String { finding.id }
    }

    struct Result: Equatable {
        let freedMemory: UInt64
        let freedSpace: UInt64
        let rows: [Row]
        var freed: UInt64 { freedMemory + freedSpace }
        var closed: Int { rows.filter { $0.outcome == .done }.count }
    }

    private(set) var mood: Mood = .scanning
    private(set) var findings: [Finding] = []
    var selected: Set<String> = []
    private(set) var lastScan: Date?
    private(set) var isWorking = false
    private(set) var progress: [String: Outcome] = [:]     // while working: what already finished
    private(set) var result: Result?
    private(set) var undoUntil: Date?
    private(set) var pausedUntil: Date?
    private(set) var keep: [String: String] = [:]           // keepKey → name
    private(set) var kept: (key: String, name: String)?     // the 5 s "Won't suggest X again. Undo" line
    private(set) var spike = Spike()
    var popoverOpen = false {
        didSet {
            guard popoverOpen != oldValue else { return }
            restartLoop()
            if popoverOpen, !mock, disk.map({ Date().timeIntervalSince($0.at) > 3600 }) ?? true { scanDisk() }
        }
    }
    var tuning = Tuning.standard
    private(set) var mock = false

    private var history: [Sample] = []
    private var disk: DiskScan?
    private let sampler = Sampler()
    private var lastActivated: [String: Date] = [:]
    private var loop: Task<Void, Never>?
    private var undoRecords: [UndoRecord] = []
    private var skipUntil: [String: Date] = [:]
    private var nudgedIDs: [String: Date] = [:]
    private let launchedAt = Date()
    private var wokeAt: Date?
    private var pressureSource: DispatchSourceMemoryPressure?
    private var diskTask: Task<Void, Never>?

    nonisolated static let pausedKey = "pausedUntil"
    nonisolated static let activatedKey = "lastActive"

    var running: [Finding] { findings.filter { $0.group == .running && $0.actionable } }
    var space: [Finding] { findings.filter { $0.group == .space && $0.actionable } }
    var know: [Finding] { findings.filter { $0.group == .know } }
    var actionable: [Finding] { findings.filter(\.actionable) }
    var selectedFindings: [Finding] { actionable.filter { selected.contains($0.id) } }
    var selectedMemory: UInt64 { selectedFindings.filter { $0.group == .running }.reduce(0) { $0 + $1.bytes } }
    var selectedSpace: UInt64 { selectedFindings.filter { $0.group == .space }.reduce(0) { $0 + $1.bytes } }
    var canUndo: Bool { (undoUntil.map { $0 > Date() } ?? false) && (!undoRecords.isEmpty || mock) }
    var paused: Bool { pausedUntil.map { $0 > Date() } ?? false }
    var latestSample: Sample? { history.last }

    // MARK: - Life cycle

    func start() {
        keep = UserDefaults.standard.dictionary(forKey: Safety.keepKey) as? [String: String] ?? [:]
        if let stored = UserDefaults.standard.dictionary(forKey: Self.activatedKey) as? [String: Double] {
            lastActivated = stored.mapValues { Date(timeIntervalSince1970: $0) }
        }
        if let until = UserDefaults.standard.object(forKey: Self.pausedKey) as? Date, until > Date() { pausedUntil = until }
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier { lastActivated[front] = Date() }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.noteActivation(id) }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.wokeAt = Date() }
        }
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.scanNow() } }
        source.resume()
        pressureSource = source
        restartLoop()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            self?.scanDisk()
        }
    }

    /// Measures the disk side in the background; rows appear when it is done.
    func scanDisk() {
        guard !mock, diskTask == nil else { return }
        diskTask = Task { [weak self] in
            let scan = await Task.detached { await DiskScanner.scan() }.value
            guard let self else { return }
            self.disk = scan
            self.diskTask = nil
            self.recompute()
        }
    }

    /// A fixture instead of the Mac: the UI with real-looking rows and pretend actions.
    func startMock(named name: String) {
        mock = true
        guard let spec = Fixtures.spec(named: name) else { return }
        history = Fixtures.history(spec)
        disk = name == "heavy" ? Fixtures.disk : nil
        lastScan = Date()
        _ = spike.update(history, tuning: tuning)
        recompute()
    }

    private func noteActivation(_ id: String) {
        lastActivated[id] = Date()
        UserDefaults.standard.set(lastActivated.mapValues(\.timeIntervalSince1970), forKey: Self.activatedKey)
    }

    private func restartLoop() {
        guard !mock else { return }
        loop?.cancel()
        loop = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.sample()
                let seconds: TimeInterval = (self.popoverOpen || self.isWorking) ? 5 : 20
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }

    func scanNow() {
        guard !mock else { return }
        Task { await sample() }
    }

    private func seeds() -> [AppSeed] {
        NSWorkspace.shared.runningApplications.map { app in
            let id = app.bundleIdentifier ?? ""
            return AppSeed(pid: app.processIdentifier, bundleID: id, name: app.localizedName ?? id, url: app.bundleURL,
                           regular: app.activationPolicy == .regular, hidden: app.isHidden, active: app.isActive,
                           launched: app.launchDate, lastActivated: lastActivated[id] ?? launchedAt)
        }
    }

    private func sample() async {
        let apps = seeds()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        let s = await sampler.take(apps: apps, frontmost: front)
        history.append(s)
        trimHistory()
        lastScan = s.at
        if let disk, s.at.timeIntervalSince(disk.at) > 6 * 3600 { scanDisk() }
        let spiked = spike.update(history, tuning: tuning)
        recompute()
        if spiked || (mood == .heavy && !running.isEmpty) { maybeNudge() }
    }

    /// Keep every sample from the last minute and one per twenty seconds for fifteen minutes before that.
    private func trimHistory() {
        guard let now = history.last?.at else { return }
        var kept: [Sample] = []
        for s in history {
            let age = now.timeIntervalSince(s.at)
            if age > 900 { continue }
            if age > 60, let last = kept.last, s.at.timeIntervalSince(last.at) < 19 { continue }
            kept.append(s)
        }
        history = kept
    }

    private func recompute() {
        let now = Date()
        let all = Rules.findings(history: history, disk: disk, keep: Set(keep.keys), tuning: tuning)
            .filter { skipUntil[$0.id].map { $0 < now } ?? true }
        let known = Set(findings.map(\.id))
        for f in all where f.actionable && !known.contains(f.id) { selected.insert(f.id) }
        selected = selected.filter { id in all.contains { $0.id == id } }
        findings = all
        updateMood()
    }

    private func updateMood() {
        if isWorking { mood = .working; return }
        if let until = undoUntil, until > Date(), result != nil { mood = .done; return }
        if paused { mood = .paused; return }
        if history.count < 2 { mood = .scanning; return }
        if actionable.isEmpty { mood = .calm; return }
        mood = spike.active ? .heavy : .light
    }

    private func maybeNudge() {
        let now = Date()
        let mode = Nudge.Mode(rawValue: UserDefaults.standard.string(forKey: Nudge.modeKey) ?? "") ?? .struggling
        let last = UserDefaults.standard.object(forKey: Nudge.lastKey) as? Date
        guard Nudge.allowed(now: now, lastNudge: last, launchedAt: launchedAt, wokeAt: wokeAt,
                            fullscreen: history.last?.fullscreen ?? false, paused: paused, mode: mode) else { return }
        let fresh = running.filter { nudgedIDs[$0.id].map { now.timeIntervalSince($0) > 6 * 3600 } ?? true }
        guard !fresh.isEmpty else { return }
        for f in fresh { nudgedIDs[f.id] = now }
        UserDefaults.standard.set(now, forKey: Nudge.lastKey)
        Sound.play(.nudge)
        Notifier.shared.post(Copy.noteTitle, Copy.noteBody(running.count, running.reduce(0) { $0 + $1.bytes }))
    }

    // MARK: - The button

    func clean() async {
        guard !isWorking else { return }
        let targets = selectedFindings
        guard !targets.isEmpty else { return }
        isWorking = true
        progress = [:]
        result = nil
        undoRecords = []
        updateMood()
        var rows: [Row] = []
        var space: UInt64 = 0
        var memory: UInt64 = 0
        for f in targets {
            let outcome: Outcome
            if mock {
                try? await Task.sleep(for: .milliseconds(700))
                outcome = .done
            } else {
                let (o, undo) = await Actions.perform(f, sample: history.last, keep: Set(keep.keys), tuning: tuning)
                outcome = o
                if let undo { undoRecords.append(undo) }
            }
            // What the closed things held is the honest number; a whole-machine before/after is swamped by everything else.
            if outcome == .done, f.group == .running { memory += f.bytes }
            if outcome == .done, f.group == .space {
                space += f.bytes
                if let d = disk, case .trash(let path) = f.action {
                    disk = DiskScan(at: d.at, items: d.items.filter { $0.path != path }, unavailableSims: d.unavailableSims, freeBytes: d.freeBytes + f.bytes, totalBytes: d.totalBytes)
                }
                if let d = disk, f.action == .deleteUnavailableSims {
                    disk = DiskScan(at: d.at, items: d.items, unavailableSims: 0, freeBytes: d.freeBytes, totalBytes: d.totalBytes)
                }
            }
            if outcome == .askedToSave || outcome == .stillRunning { skipUntil[f.id] = Date().addingTimeInterval(86_400) }
            progress[f.id] = outcome
            rows.append(Row(finding: f, outcome: outcome))
        }
        if !mock {
            try? await Task.sleep(for: .seconds(3))
            await sample()
        }
        result = Result(freedMemory: memory, freedSpace: space, rows: rows)
        undoUntil = Date().addingTimeInterval(TimeInterval(60))
        isWorking = false
        if mock { history = history.map { $0 }; findings.removeAll { f in rows.contains { $0.id == f.id } } }
        updateMood()
        if result?.closed ?? 0 > 0 { Sound.play(.done) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(61))
            self?.expireUndo()
        }
    }

    private func expireUndo() {
        guard let until = undoUntil, until <= Date() else { return }
        undoUntil = nil
        undoRecords = []
        updateMood()
    }

    func undo() async {
        guard canUndo else { return }
        let records = undoRecords
        undoRecords = []
        undoUntil = nil
        result = nil
        for r in records { _ = await Actions.undo(r) }
        Sound.play(.undo)
        updateMood()
        if !mock { scanNow() }
    }

    // MARK: - Keep, pause

    func keep(_ f: Finding) {
        keep[f.keepKey] = f.name
        if !mock { UserDefaults.standard.set(keep, forKey: Safety.keepKey) }
        kept = (f.keepKey, f.name)
        recompute()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if self?.kept?.key == f.keepKey { self?.kept = nil }
        }
    }

    func unkeep(_ key: String) {
        keep.removeValue(forKey: key)
        if !mock { UserDefaults.standard.set(keep, forKey: Safety.keepKey) }
        if kept?.key == key { kept = nil }
        recompute()
    }

    func pause(for seconds: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(seconds)
        if !mock { UserDefaults.standard.set(pausedUntil, forKey: Self.pausedKey) }
        updateMood()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds + 1))
            self?.updateMood()
        }
    }

    func resume() {
        pausedUntil = nil
        UserDefaults.standard.removeObject(forKey: Self.pausedKey)
        updateMood()
    }
}
