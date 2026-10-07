import Foundation

/// What the app must never touch. Data first, one function. Checked when a finding is made and again right before acting.
enum Safety {
    static let neverBundles: Set<String> = [
        // macOS itself
        "com.apple.finder", "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.loginwindow", "com.apple.ScreenSharing",
        // Where the user works: terminals, editors, Claude
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty", "org.alacritty",
        "net.kovidgoyal.kitty", "co.zeit.hyper", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "dev.zed.Zed",
        "com.exafunction.windsurf", "com.apple.dt.Xcode", "com.google.android.studio", "com.anthropic.claudefordesktop",
        // Browsers: tabs are unsaved state
        "com.apple.Safari", "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "company.thebrowser.Browser", "org.mozilla.firefox", "com.brave.Browser", "com.microsoft.edgemac",
        // Messages, mail and calls
        "com.apple.MobileSMS", "com.apple.mail", "com.microsoft.Outlook", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram",
        "com.tdesktop.Telegram", "com.hnc.Discord", "org.whispersystems.signal-desktop", "com.skype.skype", "Cisco-Systems.Spark",
        "us.zoom.xos", "com.apple.FaceTime", "com.microsoft.teams2", "com.tinyspeck.slackmacgap",
        // Remote access hosts: quitting one locks the user out
        "com.teamviewer.TeamViewer", "com.philandro.anydesk", "tv.parsec.www", "com.p5sys.jump.connect", "com.splashtop.Splashtop-Streamer",
        // Passwords, VPN, sync
        "com.1password.1password", "com.bitwarden.desktop", "com.dashlane.dashlanephonefinal", "com.nordvpn.macos",
        "com.google.drivefs", "com.getdropbox.dropbox", "com.microsoft.OneDrive", "com.box.desktop", "mega.mac",
        // Virtual machines and local databases: guest state, and other apps depend on them
        "com.parallels.desktop.console", "com.vmware.fusion", "com.utmapp.UTM", "org.virtualbox.app.VirtualBox",
        "com.postgresapp.Postgres2", "com.tinyapp.DBngin", "de.beyondco.herd", "de.appsolute.MAMP", "com.getflywheel.lightning.local",
        // Media and recording
        "com.apple.Music", "com.spotify.client", "com.timpler.screenstudio", "com.obsproject.obs-studio",
        // Ourselves
        "com.freeman.youfixit",
    ]
    static let neverBundlePrefixes = ["com.jetbrains."]
    static let neverNames: Set<String> = [
        "kernel_task", "WindowServer", "loginwindow", "launchd", "mds", "mds_stores", "mdworker_shared", "coreaudiod",
        "backupd", "Finder", "Dock", "SystemUIServer", "ControlCenter", "NotificationCenter", "YouFixIt",
    ]
    static let neverPaths = ["/System/", "/usr/", "/sbin/", "/bin/", "/Library/Apple/", "/private/var/"]
    static let keepKey = "keep"

    static func essential(_ bundleID: String) -> Bool {
        neverBundles.contains(bundleID) || neverBundlePrefixes.contains { bundleID.hasPrefix($0) }
    }

    /// nil means the app may act on this process. Otherwise the reason, in plain words.
    /// `history` lets it see whether the process has been working (CPU or disk) over the idle window.
    static func refusal(_ p: Sample.Proc, app: Sample.App?, in s: Sample, history h: [Sample], keep: Set<String>, tuning: Tuning) -> String? {
        if p.uid != Sampler.me { return Copy.refusedSystem }
        if neverPaths.contains(where: { p.path.hasPrefix($0) }) { return Copy.refusedSystem }
        if neverNames.contains(p.name) { return Copy.refusedSystem }
        if p.pid == ProcessInfo.processInfo.processIdentifier { return Copy.refusedSystem }
        if let app {
            if essential(app.bundleID) { return Copy.refusedEssential }
            if app.active || s.frontmost == app.pid { return Copy.refusedInUse }
            if let last = app.lastActivated, s.at.timeIntervalSince(last) < tuning.appIdle { return Copy.refusedInUse }
            if app.hasModal { return Copy.refusedDialog }
            if app.audio { return Copy.refusedAudio }
            if keep.contains(app.bundleID) { return Copy.refusedKept }
        }
        if s.frontmost == p.pid { return Copy.refusedInUse }
        if Rules.avgCPU(p.pid, h, tuning.idle) >= 0.05 || Rules.ioRate(p.pid, h, tuning.idle) >= tuning.busyIO { return Copy.refusedBusy }
        if keep.contains(p.path) { return Copy.refusedKept }
        return nil
    }
}
