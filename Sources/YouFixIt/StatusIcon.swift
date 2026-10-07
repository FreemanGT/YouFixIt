import AppKit
import Observation
import SwiftUI

/// The pebble's face. Everything is a number so poses can be blended frame by frame.
struct Pose: Equatable, Sendable {
    /// Grey like every other bar icon while calm; colour means there is something to look at.
    enum Tint: Equatable, Sendable { case bar, ok, warn, paused }

    var eyeDX: CGFloat = 0        // eyes glance sideways (pt)
    var eyeDY: CGFloat = 0        // eyes look down (positive) or up
    var eyeScale: CGFloat = 1
    var eyeOpen: CGFloat = 1      // 1 open, 0 a closed line
    var smile: CGFloat = 0        // 0 round holes, 1 smile arcs
    var lift: CGFloat = 0         // whole pebble raised (pt)
    var squashX: CGFloat = 1
    var squashY: CGFloat = 1
    var alpha: CGFloat = 1
    var tint: Tint = .bar

    static let calm = Pose()
    static let light = Pose(tint: .ok)
    static let glance = Pose(eyeDX: 0.6, eyeDY: -0.4, tint: .ok)
    static let heavy = Pose(eyeScale: 1.2, lift: 1, tint: .warn)
    static let working = Pose(eyeDY: 0.7, squashX: 1.05, squashY: 0.95, tint: .ok)
    static let done = Pose(smile: 1, tint: .ok)
    static let hop = Pose(smile: 1, lift: 2, tint: .ok)
    static let paused = Pose(eyeOpen: 0, lift: -1, alpha: 0.55, tint: .paused)

    static func mix(_ a: Pose, _ b: Pose, _ t: CGFloat) -> Pose {
        func l(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        return Pose(eyeDX: l(a.eyeDX, b.eyeDX), eyeDY: l(a.eyeDY, b.eyeDY), eyeScale: l(a.eyeScale, b.eyeScale),
                    eyeOpen: l(a.eyeOpen, b.eyeOpen), smile: l(a.smile, b.smile), lift: l(a.lift, b.lift),
                    squashX: l(a.squashX, b.squashX), squashY: l(a.squashY, b.squashY), alpha: l(a.alpha, b.alpha),
                    tint: t < 0.5 ? a.tint : b.tint)
    }

    /// The menu bar image. Grey poses are templates (the bar tints them); colour poses are drawn as they are.
    /// The eyes are holes either way, so the bar shows through them.
    func image(scale: CGFloat = 1) -> NSImage {
        let canvas = Theme.barCanvas
        let fill: NSColor = switch tint {
        case .bar, .paused: .black
        case .ok: Theme.barGreen
        case .warn: Theme.barAmber
        }
        let image = NSImage(size: NSSize(width: canvas * scale, height: canvas * scale), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            cg.scaleBy(x: scale, y: scale)
            let w = Theme.pebble.width * squashX
            let h = Theme.pebble.height * squashY
            let cx = canvas / 2
            let cy = canvas / 2 - lift
            let body = NSBezierPath(roundedRect: NSRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h),
                                    xRadius: Theme.pebbleRadius * squashX, yRadius: Theme.pebbleRadius * squashY)
            fill.withAlphaComponent(alpha).setFill()
            body.fill()

            // Eyes are cut out of the pebble.
            cg.saveGState()
            cg.setBlendMode(.destinationOut)
            let r = Theme.eye * eyeScale
            let ey = cy - 1.0 + eyeDY
            for ex in [cx - Theme.eyeGap + eyeDX, cx + Theme.eyeGap + eyeDX] {
                if smile < 1 {
                    let open = max(0.22, eyeOpen)
                    NSColor.black.withAlphaComponent(1 - smile).setFill()
                    NSBezierPath(ovalIn: NSRect(x: ex - r, y: ey - r * open, width: r * 2, height: r * 2 * open)).fill()
                }
                if smile > 0 {
                    let arc = NSBezierPath()
                    arc.appendArc(withCenter: NSPoint(x: ex, y: ey + 0.4), radius: r + 0.4, startAngle: 200, endAngle: 340, clockwise: false)
                    arc.lineWidth = 1.1
                    arc.lineCapStyle = .round
                    NSColor.black.withAlphaComponent(smile).setStroke()
                    arc.stroke()
                }
            }
            cg.restoreGState()
            return true
        }
        image.isTemplate = tint == .bar || tint == .paused
        return image
    }
}

/// Drives the pebble: short tweens on mood changes, a blink now and then, nothing else. Never a continuous loop while calm.
@MainActor @Observable
final class StatusIcon {
    private(set) var image = Pose.calm.image()
    private(set) var pose = Pose.calm
    private(set) var mood: Engine.Mood = .scanning
    private var task: Task<Void, Never>?

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Re-runs itself whenever the engine's mood changes.
    func follow(_ engine: Engine) {
        withObservationTracking {
            show(engine.mood)
        } onChange: {
            Task { @MainActor in self.follow(engine) }
        }
    }

    func show(_ new: Engine.Mood) {
        guard new != mood else { return }
        let old = mood
        mood = new
        task?.cancel()
        task = Task {
            switch new {
            case .scanning:
                await tween(to: .calm, Theme.state)
            case .calm:
                await tween(to: .calm, Theme.state)
                await blinkLoop()
            case .light:
                if old == .calm || old == .scanning {
                    await tween(to: .glance, Theme.state, ease: Self.perk)
                    await tween(to: .light, Theme.state)
                } else {
                    await tween(to: .light, Theme.state)
                }
                await blinkLoop()
            case .heavy:
                await tween(to: .heavy, 0.45, ease: Self.perk)
                await blinkLoop()
            case .working:
                await tween(to: .working, Theme.state)
                await sweepLoop()
            case .done:
                await tween(to: .hop, 0.25, ease: Self.perk)
                await tween(to: .done, 0.25)
                try? await Task.sleep(for: .seconds(Theme.smileHold))
                await tween(to: .calm, Theme.overlay)
                await blinkLoop()
            case .paused:
                await tween(to: .paused, Theme.overlay)
            }
        }
    }

    private func set(_ p: Pose) {
        pose = p
        image = p.image()
    }

    nonisolated private static func smooth(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }

    /// A touch of overshoot for the perk and the hop; the only bounce in the app.
    nonisolated private static func perk(_ t: CGFloat) -> CGFloat {
        let c: CGFloat = 1.3
        let x = t - 1
        return 1 + x * x * ((c + 1) * x + c)
    }

    private func tween(to target: Pose, _ duration: TimeInterval, ease: (CGFloat) -> CGFloat = StatusIcon.smooth) async {
        guard !Task.isCancelled else { return }
        if reduceMotion || duration <= 0 {
            set(target)
            return
        }
        let from = pose
        let frames = max(1, Int(duration / 0.05))
        for i in 1...frames {
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            set(Pose.mix(from, target, ease(CGFloat(i) / CGFloat(frames))))
        }
    }

    private func blinkLoop() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 5...9)))
            guard !Task.isCancelled else { return }
            let open = pose
            var shut = open
            shut.eyeOpen = 0
            set(shut)
            try? await Task.sleep(for: .seconds(Theme.blink))
            guard !Task.isCancelled else { return }
            set(open)
        }
    }

    private func sweepLoop() async {
        guard !reduceMotion else { return }
        var t = 0.0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(125))
            guard !Task.isCancelled else { return }
            t += 0.125 / 1.2
            var p = Pose.working
            p.eyeDX = 0.7 * CGFloat(sin(t * 2 * .pi))
            set(p)
        }
    }
}

/// The menu bar label: the face, and next to it the number of things to tidy when there are any.
/// Re-rendered by SwiftUI only when the pose image or the count changes.
struct IconLabel: View {
    let icon: StatusIcon
    let engine: Engine

    var body: some View {
        HStack(spacing: Theme.tight) {
            Image(nsImage: icon.image)
            if let n = count {
                Text("\(n)").font(Theme.font(.badge))
            }
        }
        .accessibilityLabel(tip)
    }

    private var count: Int? {
        switch engine.mood {
        case .light, .heavy: engine.actionable.isEmpty ? nil : engine.actionable.count
        default: nil
        }
    }

    private var tip: String {
        switch engine.mood {
        case .scanning: Copy.tipScanning
        case .calm, .done: Copy.tipCalm
        case .light, .heavy: Copy.tipFindings(engine.actionable.count, engine.actionable.reduce(0) { $0 + $1.bytes })
        case .working: Copy.tipWorking
        case .paused: engine.pausedUntil.map { Copy.tipPaused(until: $0) } ?? Copy.tipCalm
        }
    }
}
