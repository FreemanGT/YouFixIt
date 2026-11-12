import Foundation

/// Every user-facing string. Plain words, no jargon, no em-dashes, no emoji, no exclamation marks.
enum Copy {
    // Menu bar tooltip and VoiceOver, one string per icon state.
    static let tipCalm = "YouFixIt, your Mac feels fine"
    static let tipScanning = "YouFixIt, taking a first look"
    static let tipWorking = "YouFixIt, tidying up"
    static func tipFindings(_ n: Int, _ bytes: UInt64) -> String { "YouFixIt, \(things(n)) to tidy, about \(Format.size(bytes))" }
    static func tipPaused(until: Date) -> String { "YouFixIt, paused until \(Format.clock(until))" }

    // Header.
    static let headerCalm = "Your Mac feels fine."
    static let headerLight = "A few things are idling in the background."
    static let headerHeavy = "Your Mac is working hard. Here's what you can let go."
    static let headerScanning = "Taking a first look around…"
    static let headerWorking = "Tidying up…"
    static func headerDone(_ bytes: UInt64) -> String { "Freed up \(Format.size(bytes))" }
    static let subDone = "Your Mac has more room to breathe."
    static let subDoneNothing = "Nothing needed closing after all."
    static func headerPaused(until: Date) -> String { "Taking a break until \(Format.clock(until))." }
    static let headerEmpty = "Nothing to tidy."
    static let subEmpty = "Your Mac is doing great."
    static let subLight = "Nothing changes until you press the button."
    static let subHeavy = "Letting these go helps right away."

    // Sections.
    static let sectionRunning = "Running now"
    static let sectionSpace = "Taking up space"
    static let sectionKnow = "Good to know"

    // Rows.
    // Why lines fit one row at 11 pt, so they stay short and specific.
    static func whyIdleSim(runtime: String, since: Date?) -> String {
        since.map { "\(runtime), idle since \(Format.clock($0))" } ?? "\(runtime), nothing is using it"
    }
    static func whyIdleApp(since: Date) -> String { "Untouched since \(Format.clock(since))" }
    /// "Port 3120 in Real Woo AI, from a finished coding session".
    static func whyDevServer(port: Int?, place: String?) -> String {
        switch (port, place) {
        case let (port?, place?): "Port \(port) in \(place), from a finished coding session"
        case let (port?, nil): "Port \(port), from a finished coding session"
        case let (nil, place?): "In \(place), from a finished coding session"
        default: "From a finished coding session"
        }
    }
    static func serverGroup(_ n: Int) -> String { "\(n) leftover servers" }
    static func whyServerGroup(low: Int?, high: Int?) -> String {
        switch (low, high) {
        case let (low?, high?) where low != high: "Ports \(low) to \(high), from finished coding sessions"
        case let (low?, _): "Port \(low), from finished coding sessions"
        default: "From finished coding sessions"
        }
    }
    /// "Gradle daemon" reads as "Gradle starts a fresh one on the next build".
    static func whyDaemon(_ name: String) -> String { "\(name.replacingOccurrences(of: " daemon", with: "")) starts a fresh one on the next build" }
    static let whyTestBrowser = "Left by a script, holds no tabs"
    /// "Google Chrome" reads as "Chrome (test copy)": the brand word only costs room.
    static func testCopy(_ name: String) -> String { "\(name.replacingOccurrences(of: "Google ", with: "")) (test copy)" }
    static func whyDerivedData(_ bytes: UInt64) -> String { "Xcode rebuilds this when needed" }
    static let whyDeviceSupport = "Xcode copies these again when needed"
    static let whyDevCache = "Tools refill this as they need it"
    static let whyOrphanCache = "Left behind by a removed app"
    static func whyInstaller(_ bytes: UInt64) -> String { "An installer you already used" }
    static let whyUnavailableSims = "Their iOS version is gone"
    static let whyIdleVM = "No containers running, nothing using it"
    static let whyServiceIdle = "Nothing is using it. Stays off until you start it again."
    static func finishedWorktrees(_ project: String) -> String { "Finished worktrees in \(project)" }
    static func whyFinishedWorktrees(_ n: Int) -> String { n == 1 ? "1 copy whose work is already merged" : "\(n) copies whose work is already merged" }
    static let npxName = "Old npx downloads"
    static func whyNpx(_ n: Int) -> String { "\(n == 1 ? "1 package" : "\(n) packages") unused for two weeks, npx fetches them again" }
    static let claudeTempName = "Claude scratch folders"
    static func whyClaudeTemp(_ n: Int) -> String { "\(n == 1 ? "1 folder" : "\(n) folders") from sessions that ended days ago" }
    static func estimate(_ bytes: UInt64) -> String { "about \(Format.size(bytes))" }
    static let keep = "Keep"
    static func keepTip(_ name: String) -> String { "Never suggest \(name)" }
    static func kept(_ name: String) -> String { "Won't suggest \(name) again." }
    static let hide = "Hide"
    static func hideTip(_ name: String) -> String { "Never mention \(name)" }
    static func hidden(_ name: String) -> String { "Won't mention \(name) again." }
    static let undo = "Undo"
    static let undoCaption = "You can undo for the next minute."
    static let stillOpen = "Still open"
    static let putBack = "Put back"
    static let bootAgain = "Boot again"
    static let reopen = "Reopen"
    static let startAgain = "Start again"

    // Primary button.
    static let tidyUp = "Tidy up"
    static let nothingSelected = "Nothing selected"
    static func frees(memory: UInt64, space: UInt64) -> String {
        switch (memory > 0, space > 0) {
        case (true, true): "Frees about \(Format.size(memory)) of memory and \(Format.size(space)) of space"
        case (true, false): "Frees about \(Format.size(memory)) of memory"
        case (false, true): "Frees about \(Format.size(space)) of space"
        default: ""
        }
    }

    // Good to know buttons. A trailing "…" means a window or a question comes first.
    static func verb(_ action: Finding.Action) -> String {
        switch action {
        case .quitApp: "Quit"
        case .shutdownSim: "Shut down"
        case .sigterm, .sigtermAll, .stopService: "Stop"
        case .endSessions: "Close quiet ones"
        case .trash, .trashAll: "Move to Trash"
        case .deleteUnavailableSims: "Remove"
        case .stopBackup: "Skip this backup"
        case .restart: "Restart…"
        case .emptyTrash: "Empty Trash…"
        case .deleteRuntime, .deleteDevice: "Remove…"
        }
    }
    /// The filled button of the inline confirm.
    static func confirmVerb(_ action: Finding.Action) -> String { action == .emptyTrash ? "Empty Trash" : "Remove" }
    /// What the inline confirm says. Emptying takes everything in the Trash, not only what YouFixIt put there.
    static func confirmNote(_ action: Finding.Action) -> String {
        action == .emptyTrash ? "Everything in the Trash goes for good, not only what YouFixIt put there. This can't be undone." : "This can't be undone."
    }
    static let cancel = "Cancel"
    /// The line under Good to know after a button did its work.
    static func acted(_ action: Finding.Action, name: String, freed: UInt64) -> String {
        let tail = freed > 0 ? ", freed \(Format.size(freed))." : "."
        switch action {
        case .quitApp: return "Quit \(name)\(tail)"
        case .shutdownSim, .sigterm, .sigtermAll, .stopService: return "Stopped \(name)\(tail)"
        case .endSessions: return "Closed the quiet sessions\(tail)"
        case .trash, .trashAll: return "Moved \(name) to the Trash."
        case .stopBackup: return "Skipped this backup."
        case .restart: return "The Restart window is open."
        case .emptyTrash: return "Emptied the Trash\(tail)"
        case .deleteRuntime, .deleteDevice, .deleteUnavailableSims: return "Removed \(name)\(tail)"
        }
    }

    // Outcomes.
    static func askedToSave(_ name: String) -> String { "\(name) asked to save first, so it stayed open." }
    static func stayedOpen(_ name: String) -> String { "\(name) didn't want to close, so it stayed as it was." }
    static func couldNotClose(_ name: String) -> String { "Couldn't close \(name). You can quit it from its own menu." }
    static func couldNotMove(_ name: String) -> String { "Couldn't move \(name) to the Trash." }
    static let refusedSystem = "Part of macOS, so it stays."
    static let refusedEssential = "Something you rely on, so it stays."
    static let refusedInUse = "You're using it right now, so it stays."
    static let refusedDialog = "It has a dialog open, so it stays."
    static let refusedAudio = "It's playing audio, so it stays."
    static let refusedKept = "On your Always keep list."
    static let refusedBusy = "It's busy with something, so it stays."
    static let refusedConnected = "Something is connected to it, so it stays."
    static let refusedChanges = "It holds work that isn't saved anywhere else, so it stays."
    static let refusedRecent = "It was worked on in the last day, so it stays."
    static let refusedUnmerged = "Its work isn't merged yet, so it stays."
    static let refusedTerminal = "It holds terminal sessions, so it stays."
    static func refusedAppOpen(_ name: String) -> String { "\(name) is open, so its cache stays. Quit it first." }
    static let backupFailed = "Time Machine didn't stop. You can skip the backup from its menu."
    static let restartFailed = "Couldn't open the Restart window. Restart from the Apple menu instead."
    static let emptyTrashFailed = "Couldn't empty the Trash. Allow YouFixIt to control Finder in Privacy & Security, Automation."
    static func removeFailed(_ name: String) -> String { "Couldn't remove \(name). Xcode can remove it from its settings." }

    // Good to know.
    static let spotlight = "Spotlight is building its search index. It finishes on its own."
    static let spotlightLink = "Open Spotlight settings"
    static let photos = "Photos is looking through your library. It finishes on its own, mostly while charging."
    static let timeMachine = "Time Machine is backing up. Skipping this one is fine, the next backup runs on schedule."
    static let update = "macOS is downloading an update."
    static let updateLink = "Open Software Update"
    static func tabs(_ browser: String, _ n: Int, _ bytes: UInt64) -> String {
        "\(browser) has about \(n) tabs open (\(Format.size(bytes))). Closing the ones you're done with helps. Tabs are never closed for you."
    }
    /// `quiet` names up to three project folders whose sessions have gone quiet; `more` says the list was cut;
    /// `closable` says the row has a button that closes them.
    static func claude(_ n: Int, _ bytes: UInt64, quiet: [String], more: Bool, closable: Bool) -> String {
        let open = "\(n) Claude sessions are open (\(Format.size(bytes)))."
        let list = quiet.joined(separator: ", ") + (more ? " and more" : "")
        switch (quiet.isEmpty, closable) {
        case (true, false): return "\(n) Claude coding sessions are open (\(Format.size(bytes))). Closing finished ones in Claude's sidebar frees memory."
        case (true, true): return "\(open) Some have been quiet for half an hour. Closing them keeps their chats."
        case (false, true): return "\(open) Quiet for half an hour: \(list). Closing keeps their chats."
        case (false, false): return "\(open) Quiet ones: \(list). Close finished ones from the sidebar."
        }
    }
    static func showApp(_ name: String) -> String { "Show \(name)" }
    static let showFolder = "Show in Finder"
    static let activityMonitorLink = "Open Activity Monitor"
    static let serviceConnected = "Running from Homebrew, and something is connected to it right now."
    static let serviceBusy = "Running from Homebrew, and busy right now."
    static let memorySqueeze = "Memory is nearly full, so your Mac is juggling. Letting go of the things above helps right away."
    static let backlog = "Lots of programs are waiting their turn. Closing idle ones clears the queue."
    static let drawing = "Drawing all those windows is hard work. Fewer open windows means a smoother Mac."
    static let warm = "Your Mac is running warm. That's normal while it works hard, it cools down when things settle."
    static func loginLaunches(_ n: Int) -> String { "\(n) apps opened by themselves when you logged in. You can pick which ones in Login Items." }
    static let loginLink = "Open Login Items"
    static func longUptime(_ days: Int) -> String { "Your Mac has been on for \(days) days. A restart gives it a fresh start." }
    static func otherLeftover(_ name: String, _ bytes: UInt64) -> String { "A \(name) program left running after its session ended. Stop it if you don't need it." }
    static let liveTestBrowser = "A script is running a browser right now. It closes when the script is done."
    static func trashSize(_ bytes: UInt64) -> String { "The Trash holds \(Format.size(bytes)). Emptying it gives that space back for good." }
    static func trashMoved(_ bytes: UInt64) -> String { "YouFixIt moved \(Format.size(bytes)) to the Trash. The space comes back once the Trash is emptied." }
    static let trashLink = "Open Trash"
    static func oldRuntime(_ name: String, _ bytes: UInt64) -> String { "The \(name) simulator hasn't been used in months. Xcode downloads it again if you ever need it." }
    static func oldDevice(_ name: String, _ bytes: UInt64) -> String { "The test iPhone \(name) hasn't been used in months. Removing it deletes the apps and data on it." }
    static func vmApp(_ name: String, _ bytes: UInt64) -> String { "\(name) is holding \(Format.size(bytes)) for a virtual machine. Shut the machine down inside \(name) when you're done." }
    static let brewProgram = "Started from Homebrew and left running in the background. Stop it if you're not using it."
    static let menuBarApp = "A menu bar app sitting quiet in the background. Quit it if you don't need it right now."
    static func busyProgram(_ name: String) -> String { "\(name) has been working hard for a few minutes. If you're not waiting on it, quitting it gives the Mac a breather." }
    static func leftoverWatcher(_ bytes: UInt64) -> String { "Left over from a coding session and serving nothing. Stop it if you don't need it." }
    static let connectedServer = "Still running from a coding session, and something is connected to it right now."
    static let notebook = "A notebook server left running. Its notebooks may hold unsaved work, so save them before you stop it."
    static func leftoverDatabase(place: String?) -> String {
        place.map { "Left running by a coding session in \($0). Nothing is connected over the network." }
            ?? "Left running by a coding session. Nothing is connected over the network."
    }
    /// "Vorssaint has kept your Mac awake for 23 hours."
    static func keepingAwake(_ name: String, for seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let span = hours >= 48 ? "\(hours / 24) days" : hours >= 2 ? "\(hours) hours" : "an hour"
        return "\(name) has kept your Mac awake for \(span), so it can't sleep to save power."
    }
    static func otherCache(_ bytes: UInt64) -> String { "Holds \(Format.size(bytes)) of downloaded tool data. Some tools need reinstalling after it's cleared, so it's your call." }
    static func appCacheName(_ app: String) -> String { "\(app) cache" }
    static func appCache(_ app: String) -> String { "\(app) keeps downloaded data here and fetches it again when needed. It can go while \(app) is closed." }
    static func appCacheOpen(_ app: String) -> String { "\(app) keeps downloaded data here and fetches it again when needed. Quit \(app) first to clear it." }
    static func unmergedWorktrees(_ project: String) -> String { "Unmerged worktrees in \(project)" }
    static func whyUnmergedWorktrees(_ n: Int, local: Bool) -> String {
        let copies = n == 1 ? "1 quiet copy" : "\(n) quiet copies"
        return local ? "\(copies) with unmerged commits, which their branches keep. Local files git ignores go to the Trash with them."
            : "\(copies) with commits that were never merged. Their branches keep the commits, so the folders can go."
    }
    static func localWorktrees(_ project: String) -> String { "Worktrees with local files in \(project)" }
    static func whyLocalWorktrees(_ n: Int) -> String {
        "\(n == 1 ? "1 copy whose work is merged still holds" : "\(n) copies whose work is merged still hold") local files git ignores, like .env files. They go to the Trash too."
    }
    static func dirtyWorktrees(_ project: String) -> String { "Worktrees with unsaved work in \(project)" }
    static func whyDirtyWorktrees(_ n: Int) -> String {
        "\(n == 1 ? "1 quiet copy holds" : "\(n) quiet copies hold") work found nowhere else, like uncommitted changes. Look through them before removing any."
    }
    static func lowDisk(_ free: UInt64) -> String { "Only \(Format.size(free)) of space is left. The things above are the quickest way to make room." }

    // Footer and settings.
    static func checked(ago: Date?) -> String { ago.map { "Checked \(Format.ago($0))" } ?? "Checking…" }
    static func pausedUntil(_ date: Date) -> String { "Paused until \(Format.clock(date))" }
    static let resume = "Resume"
    static let pauseTip = "Pause for an hour"
    static let settingsTip = "Settings"
    static let back = "Back"
    static let openAtLogin = "Open at login"
    static let softSounds = "Soft sounds"
    static let playSample = "Play sample"
    static let notifications = "Notifications"
    static let notificationsCaption = "A short note when your Mac is struggling"
    static let nudgeMe = "Nudge me"
    static let nudgeStruggling = "When my Mac is struggling"
    static let nudgeDaily = "At most once a day"
    static let nudgeNever = "Never"
    static let alwaysKeep = "Always keep"
    static let alwaysKeepCaption = "Never suggested, even when idle"
    static let alwaysKeepEmpty = "Nothing here yet. Press Keep on a suggestion to add it."
    static let remove = "Remove"
    static let pauseHour = "Pause for an hour"
    static let quit = "Quit YouFixIt"

    // Welcome.
    static let welcome1 = "YouFixIt sits in your menu bar and keeps an eye on your Mac."
    static let welcome2 = "When something you're not using is slowing it down, it suggests one button press."
    static let welcome3 = "Nothing changes until you press it."
    static let neverHeading = "It never:"
    static let never1 = "Deletes your files on its own. Anything it clears goes to the Trash first, and emptying the Trash is always your call."
    static let never2 = "Closes what you're working in."
    static let never3 = "Touches your browser tabs."
    static let startWatching = "Start watching"

    // Notification.
    static let noteTitle = "A few things are weighing down your Mac"
    static func noteBody(_ n: Int, _ bytes: UInt64) -> String { "Closing \(n) idle \(n == 1 ? "thing" : "things") would free about \(Format.size(bytes)). Open YouFixIt to see them." }

    // Accessibility.
    static func a11yInclude(_ name: String, _ bytes: UInt64) -> String { "Include \(name), about \(Format.size(bytes))" }
    static func a11yKeep(_ name: String) -> String { "Keep \(name), never suggest it" }
    static func a11yHide(_ name: String) -> String { "Hide \(name), never mention it" }
    static func a11yAct(_ verb: String, _ name: String) -> String { "\(verb.replacingOccurrences(of: "…", with: "")) \(name)" }
    static func a11yTidy(_ n: Int, _ bytes: UInt64) -> String { "Tidy up \(things(n)), frees about \(Format.size(bytes))" }
    static func a11yClosing(_ name: String) -> String { "\(name), closing" }
    static func a11yClosed(_ name: String) -> String { "\(name), closed" }
    static func a11yWorking(_ name: String) -> String { "\(name), working" }

    static func things(_ n: Int) -> String { n == 1 ? "1 thing" : "\(n) things" }
}

/// Shared number and date wording, so the same reading never shows up two ways.
enum Format {
    static func size(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        guard mb >= 1000 else { return "\(Int(mb.rounded())) MB" }
        let gb = mb / 1024
        // "9 GB" and "22 GB", but "1.3 GB": one decimal only when it says something.
        let whole = gb >= 10 || abs(gb - gb.rounded()) < 0.05
        return String(format: whole ? "%.0f GB" : "%.1f GB", gb)
    }

    static func clock(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if cal.isDateInYesterday(date) { return "yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    static func ago(_ date: Date) -> String {
        let s = max(0, -date.timeIntervalSinceNow)
        if s < 90 { return "just now" }
        if s < 3600 { return "\(Int(s / 60)) min ago" }
        if s < 86_400 { return "\(Int(s / 3600)) h ago" }
        return clock(date)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        if m < 60 { return "\(m) min" }
        return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min"
    }
}
