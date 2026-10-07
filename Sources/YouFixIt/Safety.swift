import Foundation

/// What the app must never touch. Data first, one function. Checked when a finding is made and again right before acting.
enum Safety {
    static let neverBundles: Set<String> = [
        "com.apple.finder", "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.loginwindow", "com.apple.Terminal", "com.googlecode.iterm2",
        "dev.warp.Warp-Stable", "com.microsoft.VSCode", "com.apple.dt.Xcode", "com.anthropic.claudefordesktop",
        "com.apple.Safari", "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "company.thebrowser.Browser", "org.mozilla.firefox", "com.brave.Browser", "com.microsoft.edgemac",
        "com.1password.1password", "com.nordvpn.macos", "com.google.drivefs", "com.getdropbox.dropbox",
        "us.zoom.xos", "com.apple.FaceTime", "com.microsoft.teams2", "com.tinyspeck.slackmacgap",
        "com.apple.Music", "com.spotify.client", "com.timpler.screenstudio", "com.freeman.youfixit",
    ]
    static let neverNames: Set<String> = [
        "kernel_task", "WindowServer", "loginwindow", "launchd", "mds", "mds_stores", "mdworker_shared", "coreaudiod",
        "backupd", "Finder", "Dock", "SystemUIServer", "ControlCenter", "NotificationCenter", "YouFixIt",
    ]
    static let neverPaths = ["/System/", "/usr/", "/sbin/", "/bin/", "/Library/Apple/", "/private/var/"]
    static let keepKey = "keep"

    /// nil means the app may act on this process. Otherwise the reason, in plain words.
    static func refusal(_ p: Sample.Proc, app: Sample.App?, in s: Sample, keep: Set<String>, tuning: Tuning) -> String? {
        if p.uid != Sampler.me { return Copy.refusedSystem }
        if neverPaths.contains(where: { p.path.hasPrefix($0) }) { return Copy.refusedSystem }
        if neverNames.contains(p.name) { return Copy.refusedSystem }
        if p.pid == ProcessInfo.processInfo.processIdentifier { return Copy.refusedSystem }
        if let app {
            if neverBundles.contains(app.bundleID) { return Copy.refusedEssential }
            if app.active || s.frontmost == app.pid { return Copy.refusedInUse }
            if let last = app.lastActivated, s.at.timeIntervalSince(last) < tuning.appIdle { return Copy.refusedInUse }
            if app.hasModal { return Copy.refusedDialog }
            if app.audio { return Copy.refusedAudio }
            if keep.contains(app.bundleID) { return Copy.refusedKept }
        }
        if s.frontmost == p.pid { return Copy.refusedInUse }
        if keep.contains(p.path) { return Copy.refusedKept }
        return nil
    }
}
