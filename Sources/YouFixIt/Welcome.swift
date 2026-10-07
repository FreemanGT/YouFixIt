import AppKit
import ServiceManagement
import SwiftUI

/// First launch only: what the app does, what it never does, three switches, one button.
struct WelcomeView: View {
    let onStart: () -> Void
    @AppStorage(Sound.enabledKey) private var softSounds = true
    @AppStorage(Notifier.enabledKey) private var notifications = false
    @State private var openAtLogin = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            Pebble().frame(width: 60, height: 48).padding(.bottom, Theme.tight)
            Text(Copy.welcome1).font(Theme.font(.title))
            Text(Copy.welcome2).font(Theme.font(.body)).foregroundStyle(.secondary)
            Text(Copy.welcome3).font(Theme.font(.body)).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Theme.tight) {
                Text(Copy.neverHeading).font(Theme.font(.caption)).foregroundStyle(.secondary).padding(.top, Theme.tight)
                ForEach([Copy.never1, Copy.never2, Copy.never3], id: \.self) { line in
                    HStack(alignment: .top, spacing: Theme.row) {
                        Image(systemName: "xmark.circle").font(.system(size: 12)).foregroundStyle(Theme.tint).padding(.top, 1)
                        Text(line).font(Theme.font(.body)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.row) {
                Toggle(Copy.softSounds, isOn: $softSounds)
                Toggle(Copy.notifications, isOn: $notifications)
                Toggle(Copy.openAtLogin, isOn: $openAtLogin)
            }
            .toggleStyle(.switch)
            .tint(Theme.tint)
            .controlSize(.small)
            .font(Theme.font(.body))
            .padding(.top, Theme.tight)

            Button(action: start) {
                Text(Copy.startWatching).frame(maxWidth: .infinity).frame(height: Theme.buttonHeight - 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.tint)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.top, Theme.tight)
        }
        .padding(Theme.section)
        .frame(width: Theme.welcomeWidth)
    }

    private func start() {
        if openAtLogin, Bundle.main.bundlePath.hasPrefix("/Applications/") {
            try? SMAppService.mainApp.register()
        }
        if notifications { Notifier.shared.requestAuthorization() }
        onStart()
    }
}

/// The mascot at reading size, in the tint colour.
struct Pebble: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.tint)
            HStack(spacing: 16) {
                Circle().fill(Color.white.opacity(0.95)).frame(width: 7, height: 7)
                Circle().fill(Color.white.opacity(0.95)).frame(width: 7, height: 7)
            }
            .offset(y: -3)
        }
    }
}

@MainActor
enum Welcome {
    nonisolated static let key = "welcomed"
    private static var window: NSWindow?

    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        show()
    }

    static func show() {
        let view = WelcomeView {
            UserDefaults.standard.set(true, forKey: key)
            window?.close()
            window = nil
        }
        let host = NSHostingView(rootView: view)
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = true
        w.contentView = host
        w.center()
        w.level = .floating
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
