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

/// The only code that changes anything on the Mac. Every path re-checks safety first and never escalates.
enum Actions {
    @MainActor
    static func perform(_ f: Finding, history: [Sample], keep: Set<String>, tuning: Tuning) async -> (Outcome, UndoRecord?) {
        switch f.action {
        case .quitApp(let pid, let bundleID, let url):
            return await quit(pid: pid, bundleID: bundleID, url: url, name: f.name, history: history, keep: keep, tuning: tuning)
        case .shutdownSim(let udid):
            let gui = NSWorkspace.shared.runningApplications.contains { Rules.simGUIBundles.contains($0.bundleIdentifier ?? "") && !$0.isHidden }
            guard let r = await Shell.run("/usr/bin/xcrun", ["simctl", "shutdown", udid], timeout: 20), r.status == 0 else {
                return (.failed(Copy.couldNotClose(f.name)), nil)
            }
            return (.done, .boot(udid: udid, openGUI: gui))
        case .sigterm(let pid, let start):
            return await terminate(pid: pid, start: start, name: f.name)
        case .stopService(let formula, let pid, let start):
            return await stopService(formula: formula, pid: pid, start: start, name: f.name)
        case .trash(let path):
            // A tool may have started filling it since the scan.
            if await DiskScanner.recentlyWritten(path, minutes: 10) { return (.refused(Copy.refusedBusy), nil) }
            let url = URL(fileURLWithPath: path)
            var trashed: NSURL?
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
            } catch {
                return (.failed(Copy.couldNotClose(f.name)), nil)
            }
            guard let moved = trashed as URL? else { return (.done, nil) }
            return (.done, .putBack(from: moved, to: url))
        case .deleteUnavailableSims:
            let r = await Shell.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"], timeout: 60)
            return (r?.status == 0 ? .done : .failed(Copy.couldNotClose(f.name)), nil)
        case nil:
            return (.refused(Copy.refusedSystem), nil)
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

    /// The normal Quit request, so the app can save or refuse. Never force-quit.
    @MainActor
    private static func quit(pid: pid_t, bundleID: String, url: URL?, name: String, history: [Sample], keep: Set<String>, tuning: Tuning) async -> (Outcome, UndoRecord?) {
        guard let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier == bundleID, !app.isTerminated else {
            return (.done, url.map { .reopen($0) })   // already gone
        }
        if let sample = history.last, let p = sample.procs[pid],
           let why = Safety.refusal(p, app: sample.app(pid), in: sample, history: history, keep: keep, tuning: tuning) {
            return (.refused(why), nil)
        }
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

    /// SIGTERM to a process we proved is an orphan of ours, re-checked right now against pid reuse. No SIGKILL, ever.
    private static func terminate(pid: pid_t, start: Date, name: String) async -> (Outcome, UndoRecord?) {
        guard let same = ours(pid: pid, start: start) else { return (.done, nil) }
        guard same else { return (.refused(Copy.refusedSystem), nil) }
        guard kill(pid, SIGTERM) == 0 else { return (.failed(Copy.couldNotClose(name)), nil) }
        return (await gone(pid) ? .done : .stillRunning, nil)
    }

    static let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    /// No network, no analytics, no hints: brew does only what it is asked.
    static let brewEnv = ["HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_ENV_HINTS": "1"]

    /// brew services stop: launchd boots the job out (a SIGTERM an idle service answers well inside its 5 s grace) and the
    /// service leaves the login list. Re-checked right now: same process, and still nothing connected anywhere in its tree.
    private static func stopService(formula: String, pid: pid_t, start: Date, name: String) async -> (Outcome, UndoRecord?) {
        guard let same = ours(pid: pid, start: start) else { return (.done, nil) }
        guard same else { return (.refused(Copy.refusedSystem), nil) }
        if Sampler.treePids(pid).contains(where: { Sampler.sockets($0).established > 0 }) { return (.refused(Copy.refusedConnected), nil) }
        guard let brew, let r = await Shell.run(brew, ["services", "stop", formula], timeout: 90, env: brewEnv), r.status == 0 else {
            return (.failed(Copy.couldNotClose(name)), nil)
        }
        // brew reports success even when it could not stop the job, so the process going away is the proof.
        return await gone(pid) ? (.done, .startService(formula)) : (.stillRunning, nil)
    }
}
