import AppKit
import SwiftUI

/// Single source of truth for colour, type, spacing, sizes and motion. A literal in a view is a bug.
enum Theme {
    // MARK: - Colour (one tint, used as a fill only; text is always a system label colour)

    static let tint = Color(light: NSColor(srgbRed: 0.090, green: 0.490, blue: 0.400, alpha: 1),
                            dark: NSColor(srgbRed: 0.098, green: 0.518, blue: 0.420, alpha: 1))
    static let separator = Color(nsColor: .separatorColor)
    static let hover = Color.primary.opacity(0.05)
    static let rowFill = Color.primary.opacity(0.035)

    // MARK: - Type (four steps; digits always monospaced so totals never jitter)

    enum Step { case caption, body, title, hero }

    static func font(_ step: Step) -> Font {
        switch step {
        case .caption: .system(size: 11).monospacedDigit()
        case .body: .system(size: 13).monospacedDigit()
        case .title: .system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
        case .hero: .system(size: 22, weight: .semibold, design: .rounded).monospacedDigit()
        }
    }

    // MARK: - Spacing (4 pt grid, named by role)

    static let hair: CGFloat = 2
    static let tight: CGFloat = 4
    static let row: CGFloat = 8
    static let gap: CGFloat = 12
    static let edge: CGFloat = 16
    static let section: CGFloat = 20

    // MARK: - Sizes

    static let popoverWidth: CGFloat = 360
    static let popoverMaxHeight: CGFloat = 560
    static let rowHeight: CGFloat = 44
    static let rowRadius: CGFloat = 8
    static let appIcon: CGFloat = 24
    static let symbol: CGFloat = 16
    static let buttonHeight: CGFloat = 36
    static let barCanvas: CGFloat = 22
    static let pebble = CGSize(width: 15, height: 12)
    static let pebbleRadius: CGFloat = 6
    static let eye: CGFloat = 0.9
    static let dot: CGFloat = 1.5
    static let welcomeWidth: CGFloat = 380

    // MARK: - Motion (seconds)

    static let feedback = 0.12
    static let state = 0.22
    static let overlay = 0.36
    static let exit = 0.16
    static let count = 0.6
    static let stagger = 0.08
    static let staggerCap = 5
    static let blink = 0.09
    static let smileHold = 1.2
    static let undoWindow: TimeInterval = 60

    static let arrive = Animation.timingCurve(0.16, 1, 0.3, 1, duration: overlay)
    static let settle = Animation.timingCurve(0.16, 1, 0.3, 1, duration: state)
    static let leave = Animation.easeIn(duration: exit)
    static let perk = Animation.spring(duration: 0.45, bounce: 0.25)
    static let hop = Animation.spring(duration: 0.5, bounce: 0.3)
}

extension Color {
    /// One colour that follows the appearance, without a second asset catalogue.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

/// Set while rendering offscreen, so views can skip what the offscreen renderer cannot draw.
@MainActor
enum Render {
    static var offscreen = false
}
