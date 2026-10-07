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
            HStack(alignment: .top, spacing: Theme.gap) {
                Pebble(mood: .light)
                    .frame(width: Theme.faceSize.width, height: Theme.faceSize.height)
                    .padding(.top, Theme.hair)
                Text(Copy.welcome1).font(Theme.font(.title)).fixedSize(horizontal: false, vertical: true)
            }
            Text(Copy.welcome2).font(Theme.font(.body)).foregroundStyle(.secondary)
            Text(Copy.welcome3).font(Theme.font(.body)).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Theme.row) {
                Text(Copy.neverHeading).font(Theme.font(.bodyStrong))
                ForEach([Copy.never1, Copy.never2, Copy.never3], id: \.self) { line in
                    HStack(alignment: .top, spacing: Theme.row) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.tint).padding(.top, 1)
                        Text(line).font(Theme.font(.body)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: Theme.row) {
                Toggle(Copy.softSounds, isOn: $softSounds)
                Toggle(Copy.notifications, isOn: $notifications)
                Toggle(Copy.openAtLogin, isOn: $openAtLogin)
            }
            .toggleStyle(.switch)
            .tint(Theme.tint)
            .font(Theme.font(.body))
            .padding(.top, Theme.tight)

            Button(action: start) { PillLabel(title: Copy.startWatching) }
                .buttonStyle(PillStyle())
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

/// The mascot at reading size, in the mood's colour. The same face as the menu bar, drawn with SwiftUI shapes.
struct Pebble: View {
    var mood: Engine.Mood = .light

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let scale = w / Theme.pebble.width
            let r = Theme.eye * scale * (mood == .heavy ? 1.2 : 1)
            let gap = Theme.eyeGap * scale
            let dy = (mood == .working ? 0.7 : -1.0) * scale
            ZStack {
                RoundedRectangle(cornerRadius: Theme.pebbleRadius * scale, style: .continuous).fill(Theme.face(mood))
                ForEach([-1.0, 1.0], id: \.self) { side in
                    let x = w / 2 + gap * side
                    let y = h / 2 + dy
                    switch mood {
                    case .done:
                        SmileArc().stroke(Theme.faceEyes, style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round))
                            .frame(width: (r + 0.4 * scale) * 2, height: (r + 0.4 * scale) * 2)
                            .position(x: x, y: y + 0.4 * scale)
                    case .paused:
                        Capsule().fill(Theme.faceEyes).frame(width: r * 2, height: max(1, r * 0.44)).position(x: x, y: y)
                    default:
                        Circle().fill(Theme.faceEyes).frame(width: r * 2, height: r * 2).position(x: x, y: y)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The smile of the done pose: an arc open at the top, like the menu bar icon's.
struct SmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: true)
        return p
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
