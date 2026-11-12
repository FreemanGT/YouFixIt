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

    /// The 5 s "Won't suggest X again. Undo" line. `know` says it came from a Good to know row, which reads "mention".
    struct Kept: Equatable {
        let key: String
        let name: String
        let know: Bool
    }

    /// The line under Good to know after one of its buttons: what happened, with Undo while it can still be taken back.
    struct Acted: Equatable {
        let id: String
        let text: String
        let undoable: Bool
        let token = UUID()
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
    private(set) var kept: Kept?
    private(set) var spike = Spike()
    /// The Good to know row whose button is running. One at a time, and never while Tidy up runs.
    private(set) var acting: String?
    /// What a Good to know button did, shown on its row for a minute in place of the button.
    private(set) var knowOutcome: [String: Outcome] = [:]
    private(set) var acted: Acted?
    /// A row whose button can't be undone, waiting for its inline confirm.
    var confirming: String?
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
    private var actUndo: [UndoRecord] = []
    private var skipUntil: [String: Date] = [:]
    private var nudgedIDs: [String: Date] = [:]
    /// What YouFixIt itself put in the Trash: its path in the Trash → [bytes, when]. Measuring ~/.Trash needs Full Disk
    /// Access, so this is how the Trash row knows there is space waiting there.
    private var ledger: [String: [Double]] = [:]
    private var lastPrune = Date.distantPast
    private let launchedAt = Date()
    private var wokeAt: Date?
    private var pressureSource: DispatchSourceMemoryPressure?
    private var diskTask: Task<Void, Never>?

    nonisolated static let pausedKey = "pausedUntil"
    nonisolated static let activatedKey = "lastActive"
    nonisolated static let ledgerKey = "trashLedger"

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
    /// The samples the rules judge by, oldest first (for `--scan --explain`).
    var samples: [Sample] { history }
    var trashed: UInt64 { UInt64(ledger.values.reduce(0.0) { $0 + ($1.first ?? 0) }) }

    // MARK: - Life cycle

    func start() {
        keep = UserDefaults.standard.dictionary(forKey: Safety.keepKey) as? [String: String] ?? [:]
        if let stored = UserDefaults.standard.dictionary(forKey: Self.activatedKey) as? [String: Double] {
            lastActivated = stored.mapValues { Date(timeIntervalSince1970: $0) }
        }
        if let until = UserDefaults.standard.object(forKey: Self.pausedKey) as? Date, until > Date() { pausedUntil = until }
        // Thirty days on, Finder may have emptied it on its own, and the user has surely looked.
        let stored = UserDefaults.standard.dictionary(forKey: Self.ledgerKey) as? [String: [Double]] ?? [:]
        ledger = stored.filter { Date().timeIntervalSince1970 - ($0.value.last ?? 0) < 30 * 86_400 }
        pruneLedger()
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
        disk = Fixtures.disk(named: name)
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

    /// Running apps as the rules see them. A plain program that merely talked to the window server (next dev does) is
    /// listed by AppKit as a nameless background "app"; it is judged as the program it is.
    private func seeds() -> [AppSeed] {
        NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier != nil || $0.activationPolicy != .prohibited }.map { app in
            let id = app.bundleIdentifier ?? ""
            return AppSeed(pid: app.processIdentifier, bundleID: id, name: app.localizedName ?? id, url: app.bundleURL,
                           regular: app.activationPolicy == .regular, accessory: app.activationPolicy == .accessory,
                           hidden: app.isHidden, active: app.isActive,
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
        if s.at.timeIntervalSince(lastPrune) >= 60 { pruneLedger() }
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
        let all = Rules.findings(history: history, disk: disk, keep: Set(keep.keys), tuning: tuning, trashed: trashed)
            .filter { skipUntil[$0.id].map { $0 < now } ?? true }
        let known = Set(findings.map(\.id))
        for f in all where f.actionable && !known.contains(f.id) { selected.insert(f.id) }
        selected = selected.filter { id in all.contains { $0.id == id } }
        if let id = confirming, !all.contains(where: { $0.id == id }) { confirming = nil }
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
        guard !isWorking, acting == nil else { return }
        let targets = selectedFindings
        guard !targets.isEmpty else { return }
        isWorking = true
        confirming = nil
        progress = [:]
        result = nil
        undoRecords = []
        updateMood()
        var rows: [Row] = []
        var space: UInt64 = 0
        var memory: UInt64 = 0
        for f in targets {
            let r: ActResult
            if mock {
                try? await Task.sleep(for: .milliseconds(700))
                r = ActResult(outcome: .done, freed: f.bytes)
            } else {
                r = await Actions.perform(f, history: history, keep: Set(keep.keys), tuning: tuning)
                undoRecords += r.undo
            }
            record(r, of: f)
            // What the closed things held is the honest number; a whole-machine before/after is swamped by everything else.
            if r.outcome == .done, f.group == .running { memory += r.freed }
            if r.outcome == .done, f.group == .space { space += r.freed }
            if r.outcome == .askedToSave || r.outcome == .stillRunning { skipUntil[f.id] = Date().addingTimeInterval(86_400) }
            progress[f.id] = r.outcome
            rows.append(Row(finding: f, outcome: r.outcome))
        }
        if !mock {
            try? await Task.sleep(for: .seconds(3))
            await sample()
        }
        result = Result(freedMemory: memory, freedSpace: space, rows: rows)
        undoUntil = Date().addingTimeInterval(Theme.undoWindow)
        isWorking = false
        if mock { findings.removeAll { f in rows.contains { $0.id == f.id } } }
        updateMood()
        if result?.closed ?? 0 > 0 { Sound.play(.done) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.undoWindow + 1))
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
        guard canUndo, acting == nil, !isWorking else { return }
        let records = undoRecords
        // The user took these back, so they are not suggested again for a day.
        let undone = result?.rows.filter { $0.outcome == .done }.map(\.id) ?? []
        undoRecords = []
        undoUntil = nil
        result = nil
        var any = false
        for r in records {
            if await Actions.undo(r) {
                putBack(r)
                any = true
            }
        }
        let until = Date().addingTimeInterval(86_400)
        for id in undone { skipUntil[id] = until }
        if any || mock { Sound.play(.undo) }
        updateMood()
        if mock { recompute() } else { scanNow() }
    }

    // MARK: - Good to know buttons

    /// The first press on a button that can't be undone only asks; the row turns into its confirm.
    func press(_ f: Finding) async {
        guard f.offer, acting == nil, !isWorking else { return }
        if f.action?.irreversible == true, confirming != f.id {
            confirming = f.id
            return
        }
        await act(f)
    }

    /// Runs one Good to know row's button. The user picked it, so busy and recently used no longer hold it back; every
    /// other safety check still does. The row says how it went for a minute; the line under the card offers Undo.
    func act(_ f: Finding) async {
        guard f.offer, let action = f.action, acting == nil, !isWorking else { return }
        confirming = nil
        acting = f.id
        knowOutcome[f.id] = nil
        let r: ActResult
        if mock {
            try? await Task.sleep(for: .milliseconds(700))
            r = ActResult(outcome: .done, freed: f.bytes)
        } else {
            r = await Actions.perform(f, history: history, keep: Set(keep.keys), tuning: tuning, explicit: true)
        }
        record(r, of: f)
        acting = nil
        knowOutcome[f.id] = r.outcome
        if r.outcome == .done {
            actUndo = r.undo
            let line = Acted(id: f.id, text: Copy.acted(action, name: f.name, freed: r.freed), undoable: !r.undo.isEmpty || (mock && f.undoLabel != nil))
            acted = line
            Sound.play(.done)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(line.undoable ? Theme.undoWindow : 10))
                if self?.acted?.token == line.token { self?.acted = nil; self?.actUndo = [] }
            }
        }
        let outcome = r.outcome
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.undoWindow))
            if self?.knowOutcome[f.id] == outcome { self?.knowOutcome[f.id] = nil }
        }
        if mock {
            if outcome == .done { findings.removeAll { $0.id == f.id } }
            updateMood()
        } else {
            try? await Task.sleep(for: .seconds(2))
            await sample()
        }
    }

    func undoAct() async {
        guard acting == nil, !isWorking, let line = acted, line.undoable else { return }
        let records = actUndo
        actUndo = []
        acted = nil
        knowOutcome[line.id] = nil
        var any = false
        for r in records {
            if await Actions.undo(r) {
                putBack(r)
                any = true
            }
        }
        skipUntil[line.id] = Date().addingTimeInterval(86_400)
        if any || mock { Sound.play(.undo) }
        if mock { recompute() } else { scanNow() }
    }

    // MARK: - Bookkeeping after an action

    /// What the disk scan and the Trash ledger learn from an action that went through.
    private func record(_ r: ActResult, of f: Finding) {
        guard r.outcome == .done else { return }
        // Moves into the Trash join the ledger, each with what it held.
        var sizes: [String: UInt64] = [:]
        switch f.action {
        case .trash(let path): sizes[path] = f.bytes
        case .trashAll(let targets): for t in targets { sizes[t.path] = t.bytes }
        case .emptyTrash:
            // What was in the Trash is gone for good now, so nothing from it can be put back.
            ledger = [:]
            undoRecords.removeAll { if case .putBack = $0 { return true } else { return false } }
            actUndo.removeAll { if case .putBack = $0 { return true } else { return false } }
            if let line = acted, line.undoable, actUndo.isEmpty { acted = nil }
        default: break
        }
        let now = Date().timeIntervalSince1970
        for case .putBack(let from, let to) in r.undo {
            ledger[from.path] = [Double(sizes[to.path] ?? 0), now]
        }
        saveLedger()
        forget(f, r)
    }

    /// A Put back that worked takes its entry out of the ledger.
    private func putBack(_ record: UndoRecord) {
        guard case .putBack(let from, _) = record else { return }
        ledger.removeValue(forKey: from.path)
        saveLedger()
    }

    /// Entries whose folder has left the Trash (emptied in Finder, or put back by hand) stop counting. A known path can be
    /// checked without Full Disk Access, even though ~/.Trash itself cannot be listed.
    private func pruneLedger() {
        lastPrune = Date()
        let fm = FileManager.default
        let left = ledger.filter { fm.fileExists(atPath: $0.key) }
        guard left.count != ledger.count else { return }
        ledger = left
        saveLedger()
    }

    private func saveLedger() {
        if !mock { UserDefaults.standard.set(ledger, forKey: Self.ledgerKey) }
    }

    /// Drops what went from the last disk scan, so its rows go now rather than at the next scan hours later. Moving to
    /// the Trash frees nothing until the Trash is emptied, so only emptying and removing add to the free space.
    private func forget(_ f: Finding, _ r: ActResult) {
        guard let d = disk else { return }
        var items = d.items
        var free = d.freeBytes
        var unavailable = d.unavailableSims
        switch f.action {
        case .trash(let path):
            items.removeAll { $0.path == path }
        case .trashAll(let targets):
            let moved = Set(r.undo.compactMap { record -> String? in
                if case .putBack(_, let to) = record { return to.path }
                return nil
            })
            let gone = Set(targets.map(\.path)).filter { moved.contains($0) || !FileManager.default.fileExists(atPath: $0) }
            items.removeAll { gone.contains($0.path) }
        case .emptyTrash:
            items.removeAll { $0.kind == .trash }
            free += r.freed
        case .deleteRuntime(let id):
            items.removeAll { $0.path == id }
            free += r.freed
        case .deleteDevice(let udid):
            items.removeAll { $0.path == udid }
            free += r.freed
        case .deleteUnavailableSims:
            unavailable = 0
        default:
            return
        }
        disk = DiskScan(at: d.at, items: items, unavailableSims: unavailable, freeBytes: free, totalBytes: d.totalBytes)
    }

    // MARK: - Keep, pause

    func keep(_ f: Finding) {
        keep[f.keepKey] = f.name
        if !mock { UserDefaults.standard.set(keep, forKey: Safety.keepKey) }
        let line = Kept(key: f.keepKey, name: f.name, know: f.group == .know)
        kept = line
        if confirming == f.id { confirming = nil }
        recompute()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if self?.kept == line { self?.kept = nil }
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
