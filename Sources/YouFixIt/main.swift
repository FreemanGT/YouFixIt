import AppKit
import SwiftUI

// Command-line modes run before any UI exists.

if CommandLine.arguments.contains("--selftest") {
    MainActor.assumeIsolated { runSelfTest() }
}

if let i = CommandLine.arguments.firstIndex(of: "--snapshot") {
    let dir = CommandLine.arguments.dropFirst(i + 1).first ?? "snapshots"
    // The real AppKit run loop, so main-actor continuations land on the main thread (dispatchMain does not guarantee that for AppKit).
    NSApplication.shared.setActivationPolicy(.accessory)
    Task { @MainActor in
        await Snapshot.run(into: URL(fileURLWithPath: dir, isDirectory: true))
        exit(0)
    }
    NSApplication.shared.run()
}

/// `--scan [--window N] [--apply ID [--then-undo]]`: sample this Mac and print findings as text.
if CommandLine.arguments.contains("--scan") {
    let args = CommandLine.arguments
    let window = args.firstIndex(of: "--window").flatMap { args.count > $0 + 1 ? TimeInterval(args[$0 + 1]) : nil }
    let apply = args.firstIndex(of: "--apply").flatMap { args.count > $0 + 1 ? args[$0 + 1] : nil }
    let thenUndo = args.contains("--then-undo")
    NSApplication.shared.setActivationPolicy(.accessory)
    Task { @MainActor in
        let engine = Engine()
        if let window {
            engine.tuning.idle = window
            engine.tuning.appIdle = window
            engine.tuning.sustain = min(window, 120)
        }
        engine.popoverOpen = true   // 5 s cadence
        engine.start()
        let started = Date()
        var lastPrinted = ""
        while true {
            try? await Task.sleep(for: .seconds(5))
            let s = engine.latestSample
            let lines = engine.findings.map { f in
                let kind = f.actionable ? (f.group == .space ? "SPACE" : "ACT  ") : "KNOW "
                return "  \(kind) \(f.id)  \(f.name)  \(f.why)  \(f.bytes > 0 ? Copy.estimate(f.bytes) : "")"
            }
            let head = "mood \(engine.mood)  procs \(s?.procs.count ?? 0)  cpu \(Int((s?.cpuBusy ?? 0) * 100))%  load \(Int(s?.load1 ?? 0))  mem \(Format.size(s?.memUsed ?? 0))  compressed \(Format.size(s?.compressed ?? 0))  pressure \(s?.pressure ?? 0)  sims \(s?.sims.count ?? 0)  spike \(engine.spike.active)  history \(Int(Date().timeIntervalSince(started)))s"
            let text = ([head] + lines).joined(separator: "\n")
            if text != lastPrinted {
                print(text)
                lastPrinted = text
            }
            if let apply, let target = engine.findings.first(where: { $0.id == apply && $0.actionable }) {
                print("applying \(target.id)")
                engine.selected = [target.id]
                await engine.clean()
                for row in engine.result?.rows ?? [] { print("  \(row.finding.name): \(row.outcome)") }
                print("  freed memory \(Format.size(engine.result?.freedMemory ?? 0)), space \(Format.size(engine.result?.freedSpace ?? 0))")
                if thenUndo {
                    try? await Task.sleep(for: .seconds(2))
                    print("undoing (canUndo \(engine.canUndo))")
                    await engine.undo()
                }
                exit(0)
            }
            if let apply, Date().timeIntervalSince(started) > (window ?? 600) * 2 + 120 {
                print("gave up waiting for \(apply)")
                exit(1)
            }
        }
    }
    NSApplication.shared.run()
}

// The app.

struct YouFixItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView(engine: delegate.engine)
        } label: {
            IconLabel(icon: delegate.icon, engine: delegate.engine)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = Engine()
    let icon = StatusIcon()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Sound.enabledKey: true, Nudge.modeKey: Nudge.Mode.struggling.rawValue])
        if let i = CommandLine.arguments.firstIndex(of: "--mock"), i + 1 < CommandLine.arguments.count {
            engine.startMock(named: CommandLine.arguments[i + 1])
        } else {
            replaceOtherCopies()
            warnIfNotInstalled()
            engine.start()
            Notifier.shared.install()
            Notifier.shared.requestAuthorization(atLaunch: true)
        }
        icon.follow(engine)
        Welcome.showIfNeeded()
    }

    /// Opening the app again while it runs shows the welcome again, which is the only window it has.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Welcome.show()
        return false
    }

    /// Newest launch wins, so the copy in /Applications replaces one still running from the disk image.
    private func replaceOtherCopies() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        for other in NSRunningApplication.runningApplications(withBundleIdentifier: id) where other.processIdentifier != me {
            other.terminate()
        }
    }

    private func warnIfNotInstalled() {
        let path = Bundle.main.bundlePath
        guard path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/") else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Move YouFixIt to Applications"
        alert.informativeText = "It's running from the download right now. Drag it into your Applications folder and open it from there so it keeps working after a restart."
        alert.runModal()
    }
}

MainActor.assumeIsolated { YouFixItApp.main() }
