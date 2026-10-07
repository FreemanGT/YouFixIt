import AppKit
import SwiftUI

/// One suggestion as a card: a round check, what it is, why, Keep on hover, and what it frees.
struct FindingRow: View {
    let finding: Finding
    @Bindable var engine: Engine
    @State private var hovering = false

    private var outcome: Outcome? { engine.progress[finding.id] }
    private var closing: Bool { engine.isWorking && outcome == nil && engine.selected.contains(finding.id) }
    private var selected: Bool { engine.selected.contains(finding.id) }
    private var pending: Bool { !engine.isWorking && outcome == nil }

    var body: some View {
        HStack(spacing: Theme.gap) {
            leading
            icon
            VStack(alignment: .leading, spacing: Theme.hair) {
                Text(finding.name).font(Theme.font(.bodyStrong)).lineLimit(1)
                Text(why).font(Theme.font(.caption)).foregroundStyle(.secondary).lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: Theme.tight)
            trailing
        }
        .padding(.horizontal, Theme.gap)
        .frame(height: Theme.cardHeight)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(hovering && pending ? Theme.cardHover : Theme.card))
        .opacity(pending && !selected ? 0.55 : 1)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .onTapGesture { if pending { toggle() } }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: Theme.feedback), value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private func toggle() {
        if selected { engine.selected.remove(finding.id) } else { engine.selected.insert(finding.id) }
    }

    @ViewBuilder private var leading: some View {
        if closing {
            ProgressView().controlSize(.small).frame(width: Theme.check, height: Theme.check)
        } else if let outcome {
            switch outcome {
            case .done:
                Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.check)).foregroundStyle(Theme.tint).frame(width: Theme.check)
            default:
                Image(systemName: "minus.circle").font(.system(size: Theme.check)).foregroundStyle(.secondary).frame(width: Theme.check)
            }
        } else {
            Button(action: toggle) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: Theme.check))
                    .foregroundStyle(selected ? Theme.tint : Color(nsColor: .tertiaryLabelColor))
                    .frame(width: Theme.check, height: Theme.check)
            }
            .buttonStyle(.plain)
            .disabled(engine.isWorking)
            .accessibilityLabel(Copy.a11yInclude(finding.name, finding.bytes))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    @ViewBuilder private var icon: some View {
        if let path = finding.iconPath, FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: Theme.appIcon, height: Theme.appIcon)
        } else {
            Image(systemName: finding.symbol)
                .font(.system(size: Theme.symbol, weight: .medium))
                .foregroundStyle(Theme.tint)
                .frame(width: Theme.appIcon, height: Theme.appIcon)
                .background(Circle().fill(Theme.tonal))
        }
    }

    /// The size sits in a small capsule; Keep takes its place while the pointer is over the card (and is always there for VoiceOver).
    @ViewBuilder private var trailing: some View {
        ZStack(alignment: .trailing) {
            if finding.bytes > 0 {
                Text(Format.size(finding.bytes))
                    .font(Theme.font(.caption)).foregroundStyle(.secondary).fixedSize()
                    .padding(.horizontal, Theme.row).padding(.vertical, Theme.tight)
                    .background(Capsule().fill(Theme.pill))
                    .opacity(hovering && pending ? 0 : 1)
            }
            if pending {
                Button(Copy.keep) { engine.keep(finding) }
                    .buttonStyle(.plain)
                    .font(Theme.font(.bodyStrong))
                    .foregroundStyle(Theme.tint)
                    .opacity(hovering ? 1 : 0)
                    .help(Copy.keepTip(finding.name))
                    .accessibilityLabel(Copy.a11yKeep(finding.name))
            }
        }
    }

    private var why: String {
        switch outcome {
        case .askedToSave: Copy.askedToSave(finding.name)
        case .stillRunning: Copy.stayedOpen(finding.name)
        case .refused(let reason): reason
        case .failed(let reason): reason
        default: finding.why
        }
    }

    private var a11y: String {
        if closing { return Copy.a11yClosing(finding.name) }
        if outcome == .done { return Copy.a11yClosed(finding.name) }
        return "\(finding.name), \(why)"
    }
}

/// An explain-only row: a symbol, a name, the plain reason, and sometimes a place to go.
struct KnowRow: View {
    let finding: Finding

    var body: some View {
        HStack(alignment: .top, spacing: Theme.gap) {
            Image(systemName: finding.symbol)
                .font(.system(size: Theme.symbol, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Theme.appIcon, height: Theme.appIcon)
                .background(Circle().fill(Theme.pill))
            VStack(alignment: .leading, spacing: Theme.hair) {
                HStack(spacing: Theme.row) {
                    Text(finding.name).font(Theme.font(.bodyStrong)).lineLimit(1)
                    if finding.bytes > 0 {
                        Text(Format.size(finding.bytes)).font(Theme.font(.caption)).foregroundStyle(.secondary)
                    }
                }
                Text(finding.why).font(Theme.font(.caption)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let link = finding.link {
                    Button(link.title) { open(link) }.buttonStyle(.link).foregroundStyle(Theme.tint).font(Theme.font(.caption))
                }
            }
        }
        .padding(.vertical, Theme.tight)
        .accessibilityElement(children: .combine)
    }

    private func open(_ link: Finding.Link) {
        if link.url == "trash" {
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash"))
        } else if let url = URL(string: link.url) {
            NSWorkspace.shared.open(url)
        }
    }
}
