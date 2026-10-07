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
    static let whyDevServer = "From a finished coding session"
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
    static func estimate(_ bytes: UInt64) -> String { "about \(Format.size(bytes))" }
    static let keep = "Keep"
    static func keepTip(_ name: String) -> String { "Never suggest \(name)" }
    static func kept(_ name: String) -> String { "Won't suggest \(name) again." }
    static let undo = "Undo"
    static let undoCaption = "You can undo for the next minute."
    static let stillOpen = "Still open"
    static let putBack = "Put back"
    static let bootAgain = "Boot again"
    static let reopen = "Reopen"

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

    // Outcomes.
    static func askedToSave(_ name: String) -> String { "\(name) asked to save first, so it stayed open." }
    static func stayedOpen(_ name: String) -> String { "\(name) didn't want to close, so it stayed as it was." }
    static func couldNotClose(_ name: String) -> String { "Couldn't close \(name). You can quit it from its own menu." }
    static let refusedSystem = "Part of macOS, so it stays."
    static let refusedEssential = "Something you rely on, so it stays."
    static let refusedInUse = "You're using it right now, so it stays."
    static let refusedDialog = "It has a dialog open, so it stays."
    static let refusedAudio = "It's playing audio, so it stays."
    static let refusedKept = "On your Always keep list."
    static let refusedBusy = "It's busy with something, so it stays."
    static let restartServer = "Start it again from the project folder when you need it"

    // Good to know.
    static let spotlight = "Spotlight is building its search index. It finishes on its own."
    static let spotlightLink = "Open Spotlight settings"
    static let photos = "Photos is looking through your library. It finishes on its own, mostly while charging."
    static let timeMachine = "Time Machine is backing up."
    static let update = "macOS is downloading an update."
    static func tabs(_ browser: String, _ n: Int, _ bytes: UInt64) -> String {
        "\(browser) has about \(n) tabs open (\(Format.size(bytes))). Closing the ones you're done with helps. Tabs are never closed for you."
    }
    static func claude(_ n: Int, _ bytes: UInt64) -> String {
        "\(n) Claude coding sessions are open (\(Format.size(bytes))). Closing finished ones in Claude's sidebar frees memory."
    }
    static let memorySqueeze = "Memory is nearly full, so your Mac is juggling. Letting go of the things above helps right away."
    static let backlog = "Lots of programs are waiting their turn. Closing idle ones clears the queue."
    static let drawing = "Drawing all those windows is hard work. Fewer open windows means a smoother Mac."
    static let warm = "Your Mac is running warm. That's normal while it works hard, it cools down when things settle."
    static func loginLaunches(_ n: Int) -> String { "\(n) apps opened by themselves when you logged in. You can pick which ones in Login Items." }
    static let loginLink = "Open Login Items"
    static func longUptime(_ days: Int) -> String { "Your Mac has been on for \(days) days. A restart gives it a fresh start." }
    static func otherLeftover(_ name: String, _ bytes: UInt64) -> String { "A leftover \(name) program is holding \(Format.size(bytes)). If it isn't yours, quit it from Terminal." }
    static let liveTestBrowser = "A script is running a browser right now. It closes when the script is done."
    static func trashSize(_ bytes: UInt64) -> String { "The Trash holds \(Format.size(bytes)). Empty it from Finder when you're sure." }
    static let trashLink = "Open Trash"
    static func oldRuntime(_ name: String, _ bytes: UInt64) -> String { "The \(name) simulator hasn't been used in months (\(Format.size(bytes))). Remove it in Xcode's Components settings." }
    static func oldDevice(_ name: String, _ bytes: UInt64) -> String { "The test iPhone \(name) hasn't been used in months (\(Format.size(bytes))). Remove it in Xcode's Devices window." }
    static func vmApp(_ name: String, _ bytes: UInt64) -> String { "\(name) is holding \(Format.size(bytes)) for a virtual machine. Shut the machine down inside \(name) when you're done." }
    static func brewServices(_ names: [String], _ bytes: UInt64) -> String {
        "\(names.joined(separator: ", ")) are running from Homebrew (\(Format.size(bytes))). They start at login; brew services stop NAME turns one off."
    }
    static func menuBarApps(_ top: [String], _ bytes: UInt64) -> String {
        "Menu bar apps are holding \(Format.size(bytes)): \(top.joined(separator: ", ")). Quit the ones you don't use from their own menu bar icons."
    }
    static func busyProgram(_ name: String) -> String { "\(name) has been working hard for a few minutes. If you're not waiting on it, quitting it gives the Mac a breather." }
    static func leftoverWatcher(_ bytes: UInt64) -> String { "Left over from a coding session, holding \(Format.size(bytes)). It isn't serving anything; quit it from Terminal if it isn't yours." }
    static let connectedServer = "Still running from a coding session, and something is connected to it right now."
    static func otherCache(_ bytes: UInt64) -> String { "Holds \(Format.size(bytes)) of downloaded tool data. Some tools need reinstalling after it's removed, so it's left to you." }
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
    static let never1 = "Deletes your files. Anything it clears goes to the Trash first, and you can put it back."
    static let never2 = "Closes what you're working in."
    static let never3 = "Touches your browser tabs."
    static let startWatching = "Start watching"

    // Notification.
    static let noteTitle = "A few things are weighing down your Mac"
    static func noteBody(_ n: Int, _ bytes: UInt64) -> String { "Closing \(n) idle \(n == 1 ? "thing" : "things") would free about \(Format.size(bytes)). Open YouFixIt to see them." }

    // Accessibility.
    static func a11yInclude(_ name: String, _ bytes: UInt64) -> String { "Include \(name), about \(Format.size(bytes))" }
    static func a11yKeep(_ name: String) -> String { "Keep \(name), never suggest it" }
    static func a11yTidy(_ n: Int, _ bytes: UInt64) -> String { "Tidy up \(things(n)), frees about \(Format.size(bytes))" }
    static func a11yClosing(_ name: String) -> String { "\(name), closing" }
    static func a11yClosed(_ name: String) -> String { "\(name), closed" }

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
