import AppKit
import SwiftUI

/// `YouFixIt --snapshot DIR` renders every popover state, light and dark, plus the icon poses, to PNG.
@MainActor
enum Snapshot {
    private struct Scene {
        let name: String
        let mock: String
        var pane: PopoverView.Pane = .main
        var knowOpen = false
        var paused = false
        var working = false
        var done = false
        var kept = false
    }

    private static let scenes: [Scene] = [
        Scene(name: "empty", mock: "calm"),
        Scene(name: "light-1", mock: "simIdle"),
        Scene(name: "heavy", mock: "heavy"),
        Scene(name: "good-to-know-open", mock: "heavy", knowOpen: true),
        Scene(name: "know-open", mock: "chrome40", knowOpen: true),
        Scene(name: "busy", mock: "busyProgram", knowOpen: true),
        Scene(name: "kept-undo-line", mock: "heavy", kept: true),
        Scene(name: "working-mid", mock: "heavy", working: true),
        Scene(name: "done", mock: "heavy", done: true),
        Scene(name: "paused", mock: "heavy", paused: true),
        Scene(name: "settings", mock: "heavy", pane: .settings),
    ]

    static func run(into dir: URL) async {
        Render.offscreen = true
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSApplication.shared.finishLaunching()
        var written = 0
        for scene in scenes {
            let engine = Engine()
            engine.startMock(named: scene.mock)
            if scene.paused { engine.pause(for: 3600) }
            if scene.kept, let first = engine.running.first { engine.keep(first) }
            if scene.working {
                let task = Task { await engine.clean() }
                try? await Task.sleep(for: .milliseconds(1000))
                for appearance in appearances { if render(scene, engine: engine, appearance: appearance, into: dir) { written += 1 } }
                await task.value
                continue
            }
            if scene.done { await engine.clean() }
            for appearance in appearances { if render(scene, engine: engine, appearance: appearance, into: dir) { written += 1 } }
        }
        for appearance in appearances { if renderWelcome(appearance, into: dir) { written += 1 } }
        for appearance in appearances { if renderIcons(appearance, into: dir) { written += 1 } }
        print("wrote \(written) snapshots to \(dir.path)")
    }

    private static let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]

    private static func render(_ scene: Scene, engine: Engine, appearance: (String, NSAppearance.Name), into dir: URL) -> Bool {
        let view = PopoverView(engine: engine, pane: scene.pane, knowOpen: scene.knowOpen)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.separator, lineWidth: 1))
        return write(AnyView(view), name: "\(scene.name)-\(appearance.0)", appearance: appearance.1, into: dir)
    }

    private static func renderWelcome(_ appearance: (String, NSAppearance.Name), into dir: URL) -> Bool {
        let view = WelcomeView(onStart: {}).background(Color(nsColor: .windowBackgroundColor))
        return write(AnyView(view), name: "welcome-\(appearance.0)", appearance: appearance.1, into: dir)
    }

    /// Every pose at 1x and 2x on a menu-bar-like strip, so legibility can be judged at real size.
    private static func renderIcons(_ appearance: (String, NSAppearance.Name), into dir: URL) -> Bool {
        let poses: [(String, Pose)] = [("calm", .calm), ("blink", { var p = Pose.calm; p.eyeOpen = 0; return p }()), ("glance", .glance),
                                       ("light", .light), ("heavy", .heavy), ("working", .working), ("done", .done), ("hop", .hop), ("paused", .paused)]
        let dark = appearance.1 == .darkAqua
        let view = VStack(alignment: .leading, spacing: 8) {
            ForEach([1.0, 2.0], id: \.self) { scale in
                HStack(spacing: 12) {
                    ForEach(poses, id: \.0) { name, pose in
                        VStack(spacing: 2) {
                            Image(nsImage: pose.image())
                                .resizable().interpolation(.none)
                                .frame(width: Theme.barCanvas * scale, height: Theme.barCanvas * scale)
                                .foregroundStyle(dark ? Color.white : Color.black)
                            Text(name).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    // The bar item as it looks with things to tidy: the colour face plus the count.
                    VStack(spacing: 2) {
                        HStack(spacing: Theme.tight * scale) {
                            Image(nsImage: Pose.light.image())
                                .resizable().interpolation(.none)
                                .frame(width: Theme.barCanvas * scale, height: Theme.barCanvas * scale)
                            Text("3").font(.system(size: 12 * scale, weight: .semibold, design: .rounded)).foregroundStyle(dark ? Color.white : Color.black)
                        }
                        Text("count").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(dark ? Color(white: 0.12) : Color(white: 0.93))
        return write(AnyView(view), name: "icon-poses-\(appearance.0)", appearance: appearance.1, into: dir)
    }

    /// Controls only draw in their active state in the key window of the active app, so the window is made key far off screen.
    private static func write(_ view: AnyView, name: String, appearance: NSAppearance.Name, into dir: URL) -> Bool {
        let host = NSHostingView(rootView: view)
        host.sizingOptions = [.intrinsicContentSize]
        let size = host.fittingSize
        let window = KeyableWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        window.makeKey()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        // Measured lists settle after the first pass; take the window to the settled size and look again.
        window.setContentSize(host.fittingSize)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        defer { window.orderOut(nil) }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: dir.appendingPathComponent("\(name).png"))
            return true
        } catch {
            print("snapshot: could not write \(name): \(error)")
            return false
        }
    }

    private final class KeyableWindow: NSPanel {
        override var canBecomeKey: Bool { true }
        override var isKeyWindow: Bool { true }
        override var isMainWindow: Bool { true }
    }
}
