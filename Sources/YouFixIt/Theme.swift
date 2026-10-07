import AppKit
import SwiftUI

/// Single source of truth for colour, type, spacing, sizes and motion. A literal in a view is a bug.
enum Theme {
    // MARK: - Colour (one accent, used as a fill; text is always a system label colour)

    static let tint = Color(light: NSColor(srgbRed: 0.090, green: 0.490, blue: 0.400, alpha: 1),
                            dark: NSColor(srgbRed: 0.098, green: 0.518, blue: 0.420, alpha: 1))
    /// The face under strain. Only ever a face colour, never a control.
    static let amber = Color(light: NSColor(srgbRed: 0.851, green: 0.604, blue: 0.169, alpha: 1),
                             dark: NSColor(srgbRed: 0.941, green: 0.706, blue: 0.271, alpha: 1))
    static let separator = Color(nsColor: .separatorColor)
    static let hover = Color.primary.opacity(0.05)
    /// Cards sit one step above the window: a soft fill in both appearances, never a border.
    static let card = Color(light: NSColor.black.withAlphaComponent(0.055), dark: NSColor.white.withAlphaComponent(0.085))
    static let cardHover = Color(light: NSColor.black.withAlphaComponent(0.09), dark: NSColor.white.withAlphaComponent(0.13))
    static let pill = Color.primary.opacity(0.08)
    /// The accent at low strength: symbol wells and the secondary pill (Hoy's grey pill, in our colour).
    static let tonal = tint.opacity(0.14)
    static let onAccent = Color.white
    static let keyOnAccent = Color.white.opacity(0.22)
    static let keyOnTonal = tint.opacity(0.22)
    static let faceEyes = Color.white

    /// What colour the face is in each mood: grey while calm, the accent when there is something to do, amber under strain.
    static func face(_ mood: Engine.Mood) -> Color {
        switch mood {
        case .scanning, .calm: Color(nsColor: .secondaryLabelColor)
        case .light, .working, .done: tint
        case .heavy: amber
        case .paused: Color(nsColor: .tertiaryLabelColor)
        }
    }

    /// Menu bar fills (the icon is drawn with AppKit).
    static let barGreen = NSColor(srgbRed: 0.145, green: 0.620, blue: 0.500, alpha: 1)
    static let barAmber = NSColor(srgbRed: 0.930, green: 0.660, blue: 0.200, alpha: 1)

    // MARK: - Type (digits always monospaced so totals never jitter)

    enum Step { case caption, body, bodyStrong, button, title, hero, badge }

    static func font(_ step: Step) -> Font {
        switch step {
        case .caption: .system(size: 11).monospacedDigit()
        case .body: .system(size: 13).monospacedDigit()
        case .bodyStrong: .system(size: 13, weight: .semibold).monospacedDigit()
        case .button: .system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
        case .title: .system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()
        case .hero: .system(size: 24, weight: .semibold, design: .rounded).monospacedDigit()
        case .badge: .system(size: 12, weight: .semibold, design: .rounded).monospacedDigit()
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
    static let cardHeight: CGFloat = 56
    static let cardRadius: CGFloat = 14
    static let cardGap: CGFloat = 6
    static let appIcon: CGFloat = 28
    static let symbol: CGFloat = 14
    static let check: CGFloat = 18
    static let pillHeight: CGFloat = 44
    static let pillCompact: CGFloat = 32
    static let keyGlyph: CGFloat = 18
    static let keyRadius: CGFloat = 5
    static let faceSize = CGSize(width: 40, height: 32)
    static let barCanvas: CGFloat = 22
    static let pebble = CGSize(width: 18, height: 15)
    static let pebbleRadius: CGFloat = 7.5
    static let eye: CGFloat = 1.3
    static let eyeGap: CGFloat = 3.0
    static let welcomeWidth: CGFloat = 380
    static let fade: CGFloat = 28

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

extension View {
    /// The card every group of content sits in.
    func card() -> some View {
        padding(Theme.gap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
    }
}

/// A full-width capsule: filled with the accent for the one thing to do, tonal for the way back.
struct PillStyle: ButtonStyle {
    var filled = true
    var height = Theme.pillHeight
    @Environment(\.isEnabled) private var enabled

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: height / 2, style: .continuous) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.button))
            .foregroundStyle(filled ? (enabled ? Theme.onAccent : Color.secondary) : Theme.tint)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(shape.fill(filled ? (enabled ? Theme.tint : Theme.card) : Theme.tonal))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: Theme.feedback), value: configuration.isPressed)
    }
}

/// The pill's label: the words centred, the return-key hint at the trailing edge (the button answers Return).
struct PillLabel: View {
    let title: String
    var filled = true
    var showKey = true

    var body: some View {
        ZStack {
            Text(title)
            if showKey {
                HStack {
                    Spacer()
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: Theme.keyGlyph, height: Theme.keyGlyph)
                        .background(RoundedRectangle(cornerRadius: Theme.keyRadius, style: .continuous).fill(filled ? Theme.keyOnAccent : Theme.keyOnTonal))
                        .padding(.trailing, Theme.gap)
                }
            }
        }
    }
}

/// Set while rendering offscreen, so views can skip what the offscreen renderer cannot draw.
@MainActor
enum Render {
    static var offscreen = false
}
