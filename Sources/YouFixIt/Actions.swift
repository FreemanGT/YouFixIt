import AppKit
import Darwin
import Foundation

/// What undoing one action takes.
enum UndoRecord: Sendable {
    case reopen(URL)
    case boot(udid: String, openGUI: Bool)
    case putBack(from: URL, to: URL)
    case startService(String)
}

/// What one press did: how it went, how to take it back, and what it really freed.
struct ActResult: Sendable {
    var outcome: Outcome
    var undo: [UndoRecord] = []
    var freed: UInt64 = 0
}

/// The only code that changes anything on the Mac. Every path re-checks safety first and never escalates.
enum Actions {
    /// `explicit` is a press on a Good to know button: the user picked this one, so "busy", "used within the hour" and
    /// "something is connected" no longer hold it back. Everything else is checked exactly as for Tidy up.
    @MainActor
    static func perform(_ f: Finding, history: [Sample], keep: Set<String>, tuning: Tuning, explicit: Bool = false) async -> ActResult {
        switch f.action {
        case .quitApp(let pid, let bundleID, let url):
            let (o, undo) = await quit(pid: pid, bundleID: bundleID, url: url, name: f.name, history: history, keep: keep, tuning: tuning, strict: !explicit)
            return ActResult(outcome: o, undo: undo.map { [$0] } ?? [], freed: o == .done ? f.bytes : 0)
        case .shutdownSim(let udid):
            let gui = NSWorkspace.shared.runningApplications.contains { Rules.simGUIBundles.contains($0.bundleIdentifier ?? "") && !$0.isHidden }
            guard let r = await Shell.run("/usr/bin/xcrun", ["simctl", "shutdown", udid], timeout: 20), r.status == 0 else {
                return ActResult(outcome: .failed(Copy.couldNotClose(f.name)))
            }
            return ActResult(outcome: .done, undo: [.boot(udid: udid, openGUI: gui)], freed: f.bytes)
        case .sigterm(let pid, let start):
            let o = await terminate(Finding.Target(pid: pid, start: start), name: f.name, checkClients: !explicit)
            return ActResult(outcome: o, freed: o == .done ? f.bytes : 0)
        case .sigtermAll(let targets):
            var outcomes: [Outcome] = []
            var freed: UInt64 = 0
            for t in targets {
                let o = await terminate(t, name: f.name, checkClients: !explicit)
                if o == .done { freed += t.bytes }
                outcomes.append(o)
            }
            return ActResult(outcome: merge(outcomes), freed: freed)
        case .endSessions(let targets):
            var outcomes: [Outcome] = []
            var freed: UInt64 = 0
            for t in targets {
                // Someone may have gone back to it since the row was made.
                if let since = history.last?.quietSince[t.pid], Date().timeIntervalSince(since) < tuning.sessionQuiet {
                    outcomes.append(.refused(Copy.refusedBusy))
                    continue
                }
                let o = await endSession(t, name: f.name)
                if o == .done { freed += t.bytes }
                outcomes.append(o)
            }
            return ActResult(outcome: merge(outcomes), freed: freed)
        case .stopService(let formula, let pid, let start):
            return await stopService(formula: formula, pid: pid, start: start, name: f.name, explicit: explicit, bytes: f.bytes)
        case .trash(let path):
            // An app refills its own cache while it runs; a tool may have started filling a folder since the scan.
            let folder = (path as NSString).lastPathComponent
            if (path as NSString).deletingLastPathComponent == DiskScanner.home + "/Library/Caches",
               let app = NSRunningApplication.runningApplications(withBundleIdentifier: folder).first {
                return ActResult(outcome: .refused(Copy.refusedAppOpen(app.localizedName ?? f.name)))
            }
            if DiskScanner.inUse(path, by: Sampler.usage()) { return ActResult(outcome: .refused(Copy.refusedInUse)) }
            if await DiskScanner.recentlyWritten(path, minutes: 10) { return ActResult(outcome: .refused(Copy.refusedBusy)) }
            return trashOne(path, bytes: f.bytes, name: f.name)
        case .trashAll(let targets):
            let usage = Sampler.usage()
            var result = ActResult(outcome: .done)
            var outcomes: [Outcome] = []
            for t in targets {
                if let why = await hold(t, usage: usage) {
                    outcomes.append(.refused(why))
                    continue
                }
                let r = trashOne(t.path, bytes: t.bytes, name: f.name)
                outcomes.append(r.outcome)
                result.undo += r.undo
                result.freed += r.freed
            }
            result.outcome = merge(outcomes)
            return result
        case .deleteUnavailableSims:
            let r = await Shell.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"], timeout: 60)
            return ActResult(outcome: r?.status == 0 ? .done : .failed(Copy.couldNotClose(f.name)))
        case .stopBackup:
            let r = await Shell.run("/usr/bin/tmutil", ["stopbackup"], timeout: 30)
            return ActResult(outcome: r?.status == 0 ? .done : .failed(Copy.backupFailed))
        case .restart:
            // loginwindow's own Restart window, with its Cancel button and countdown. Nothing restarts without it.
            let r = await Shell.run("/usr/bin/osascript", ["-e", "tell application \"loginwindow\" to «event aevtrrst»"], timeout: 30)
            return ActResult(outcome: r?.status == 0 ? .done : .failed(Copy.restartFailed))
        case .emptyTrash:
            // Apple Events give up after two minutes unless told otherwise, and a big Trash takes longer than that.
            let r = await Shell.run("/usr/bin/osascript", ["-e", "with timeout of 1800 seconds", "-e", "tell application \"Finder\" to empty trash",
                                                           "-e", "end timeout"], timeout: 1830)
            return r?.status == 0 ? ActResult(outcome: .done, freed: f.bytes) : ActResult(outcome: .failed(Copy.emptyTrashFailed))
        case .deleteRuntime(let id):
            let r = await Shell.run("/usr/bin/xcrun", ["simctl", "runtime", "delete", id], timeout: 300)
            return r?.status == 0 ? ActResult(outcome: .done, freed: f.bytes) : ActResult(outcome: .failed(Copy.removeFailed(f.name)))
        case .deleteDevice(let udid):
            let r = await Shell.run("/usr/bin/xcrun", ["simctl", "delete", udid], timeout: 120)
            return r?.status == 0 ? ActResult(outcome: .done, freed: f.bytes) : ActResult(outcome: .failed(Copy.removeFailed(f.name)))
        case nil:
            return ActResult(outcome: .refused(Copy.refusedSystem))
        }
    }

    static func undo(_ record: UndoRecord) async -> Bool {
        switch record {
        case .reopen(let url):
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            return await withCheckedContinuation { c in
                NSWorkspace.shared.openApplication(at: url, configuration: config) { app, _ in c.resume(returning: app != nil) }
            }
        case .boot(let udid, let openGUI):
            let r = await Shell.run("/usr/bin/xcrun", ["simctl", "boot", udid], timeout: 30)
            if openGUI { _ = await Shell.run("/usr/bin/open", ["-b", "com.apple.dt.Devices"], timeout: 10) }
            return r?.status == 0
        case .putBack(let from, let to):
            do {
                try FileManager.default.moveItem(at: from, to: to)
                return true
            } catch {
                return false
            }
        case .startService(let formula):
            guard let brew else { return false }
            return await Shell.run(brew, ["services", "start", formula], timeout: 60, env: brewEnv)?.status == 0
        }
    }

    /// One outcome for a group: done when anything went (what really went is in `freed`), else the first thing that held one back.
    private static func merge(_ outcomes: [Outcome]) -> Outcome {
        outcomes.contains(.done) || outcomes.isEmpty ? .done : outcomes[0]
    }

    /// The normal Quit request, so the app can save or refuse. Never force-quit.
    @MainActor
    private static func quit(pid: pid_t, bundleID: String, url: URL?, name: String, history: [Sample], keep: Set<String>, tuning: Tuning,
                             strict: Bool) async -> (Outcome, UndoRecord?) {
        // Without a bundle id there is no telling whether the pid still belongs to the app the row was made for.
        guard !bundleID.isEmpty else { return (.refused(Copy.refusedSystem), nil) }
        guard let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier == bundleID, !app.isTerminated else {
            return (.done, url.map { .reopen($0) })   // already gone
        }
        if let sample = history.last, let p = sample.procs[pid],
           let why = Safety.refusal(p, app: sample.app(pid), in: sample, history: history, keep: keep, tuning: tuning, strict: strict) {
            return (.refused(why), nil)
        }
        if Safety.essential(bundleID) { return (.refused(Copy.refusedEssential), nil) }
        if app.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { return (.refused(Copy.refusedInUse), nil) }
        let before = Sampler.windows()
        let windowsBefore = (before.normal[pid] ?? 0) + (before.modal.contains(pid) ? 1 : 0)
        guard app.terminate() else { return (.failed(Copy.couldNotClose(name)), nil) }
        for _ in 0..<32 {
            try? await Task.sleep(for: .milliseconds(250))
            if app.isTerminated { return (.done, url.map { .reopen($0) }) }
        }
        let after = Sampler.windows()
        let windowsAfter = (after.normal[pid] ?? 0) + (after.modal.contains(pid) ? 1 : 0)
        return (windowsAfter > windowsBefore ? .askedToSave : .stillRunning, nil)
    }

    /// Is this still the process the finding was made for? nil when it is gone, false when the pid now belongs to something else.
    private static func ours(pid: pid_t, start: Date) -> Bool? {
        var bsd = proc_bsdinfo()
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 else { return nil }
        let started = TimeInterval(bsd.pbi_start_tvsec) + TimeInterval(bsd.pbi_start_tvusec) / 1_000_000
        return abs(started - start.timeIntervalSince1970) < 1 && bsd.pbi_uid == Sampler.me
    }

    /// Waits up to five seconds for the process to go away.
    private static func gone(_ pid: pid_t) async -> Bool {
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(250))
            if kill(pid, 0) != 0 { return true }
        }
        return false
    }

    /// SIGTERM to a process of ours, re-checked right now: the same process (against pid reuse), not part of macOS, not an
    /// essential app, not someone's terminal, and for Tidy up rows nobody connected since the scan. No SIGKILL, ever.
    @MainActor
    private static func terminate(_ t: Finding.Target, name: String, checkClients: Bool) async -> Outcome {
        guard let same = ours(pid: t.pid, start: t.start) else { return .done }
        guard same else { return .refused(Copy.refusedSystem) }
        let path = Sampler.currentPath(t.pid)
        if path.isEmpty || Safety.system(path) || Safety.neverNames.contains((path as NSString).lastPathComponent)
            || t.pid == ProcessInfo.processInfo.processIdentifier { return .refused(Copy.refusedSystem) }
        if let id = NSRunningApplication(processIdentifier: t.pid)?.bundleIdentifier, Safety.essential(id) { return .refused(Copy.refusedEssential) }
        let names = ([t.pid] + Sampler.treePids(t.pid)).map { Sampler.programName(Sampler.currentPath($0)) }
        if Safety.shells.contains(Sampler.programName(path)) || names.contains(where: { Safety.terminalHosts.contains($0) }) {
            return .refused(Copy.refusedTerminal)
        }
        if checkClients, Sampler.liveClients(root: t.pid) > 0 { return .refused(Copy.refusedConnected) }
        guard kill(t.pid, SIGTERM) == 0 else { return .failed(Copy.couldNotClose(name)) }
        return await gone(t.pid) ? .done : .stillRunning
    }

    /// A quiet Claude session: SIGTERM to its process group (the session and the MCP servers it started, under Claude's
    /// `disclaimer --pgroup` wrapper) once every member is checked to be ours and part of that session; otherwise to the
    /// session alone. Claude picks the conversation up again when it is opened. No SIGKILL.
    private static func endSession(_ t: Finding.Target, name: String) async -> Outcome {
        guard let same = ours(pid: t.pid, start: t.start) else { return .done }
        guard same, Sampler.currentPath(t.pid).hasSuffix(Sampler.claudeSession) else { return .refused(Copy.refusedSystem) }
        let tree = Set(Sampler.treePids(t.pid))
        let parent = Sampler.info(t.pid)?.ppid ?? 0
        let group = getpgid(t.pid)
        let members = group > 1 ? Sampler.groupPids(group) : []
        let wholeGroup = !members.isEmpty && members.allSatisfy { m in
            Sampler.info(m)?.uid == Sampler.me && (tree.contains(m) || (m == parent && Sampler.currentPath(m).hasSuffix("/disclaimer")))
        }
        guard kill(wholeGroup ? -group : t.pid, SIGTERM) == 0 else { return .failed(Copy.couldNotClose(name)) }
        return await gone(t.pid) ? .done : .stillRunning
    }

    static let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    /// No network, no analytics, no hints: brew does only what it is asked.
    static let brewEnv = ["HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_ENV_HINTS": "1"]

    /// brew services stop: launchd boots the job out (a SIGTERM an idle service answers well inside its 5 s grace) and the
    /// service leaves the login list. Re-checked right now: same process, and for Tidy up still nothing connected in its tree.
    private static func stopService(formula: String, pid: pid_t, start: Date, name: String, explicit: Bool, bytes: UInt64) async -> ActResult {
        guard let same = ours(pid: pid, start: start) else { return ActResult(outcome: .done) }
        guard same else { return ActResult(outcome: .refused(Copy.refusedSystem)) }
        if !explicit, Sampler.liveClients(root: pid) > 0 { return ActResult(outcome: .refused(Copy.refusedConnected)) }
        guard let brew, let r = await Shell.run(brew, ["services", "stop", formula], timeout: 90, env: brewEnv), r.status == 0 else {
            return ActResult(outcome: .failed(Copy.couldNotClose(name)))
        }
        // brew reports success even when it could not stop the job, so the process going away is the proof.
        return await gone(pid) ? ActResult(outcome: .done, undo: [.startService(formula)], freed: bytes) : ActResult(outcome: .stillRunning)
    }

    /// Why a folder must stay right now, or nil when it may move to the Trash.
    private static func hold(_ t: Finding.TrashTarget, usage: DiskScanner.Usage) async -> String? {
        switch t.check {
        case .written:
            if DiskScanner.inUse(t.path, by: usage) { return Copy.refusedInUse }
            return await DiskScanner.recentlyWritten(t.path, minutes: 10) ? Copy.refusedBusy : nil
        case .worktree:
            return await DiskScanner.worktreeHold(t.path, using: usage, strict: false)
        case .mergedWorktree:
            return await DiskScanner.worktreeHold(t.path, using: usage, strict: true)
        case .unused:
            return DiskScanner.inUse(t.path, by: usage) ? Copy.refusedInUse : nil
        }
    }

    /// Into the Trash, with what it takes to put it back. A folder already gone counts as done.
    private static func trashOne(_ path: String, bytes: UInt64, name: String) -> ActResult {
        guard FileManager.default.fileExists(atPath: path) else { return ActResult(outcome: .done) }
        let url = URL(fileURLWithPath: path)
        var trashed: NSURL?
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
        } catch {
            return ActResult(outcome: .failed(Copy.couldNotMove(name)))
        }
        guard let moved = trashed as URL? else { return ActResult(outcome: .done, freed: bytes) }
        return ActResult(outcome: .done, undo: [.putBack(from: moved, to: url)], freed: bytes)
    }
}
