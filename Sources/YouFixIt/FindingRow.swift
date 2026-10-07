import AppKit
import SwiftUI

/// One suggestion: a checkbox, what it is, why, Keep, and what it frees.
struct FindingRow: View {
    let finding: Finding
    @Bindable var engine: Engine
    @State private var hovering = false

    private var outcome: Outcome? { engine.progress[finding.id] }
    private var closing: Bool { engine.isWorking && outcome == nil && engine.selected.contains(finding.id) }

    var body: some View {
        HStack(spacing: Theme.gap) {
            leading
            icon
            VStack(alignment: .leading, spacing: Theme.hair) {
                Text(finding.name).font(Theme.font(.body)).lineLimit(1)
                Text(why).font(Theme.font(.caption)).foregroundStyle(.secondary).lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: Theme.tight)
            if !engine.isWorking, outcome == nil {
                // Keep shows on hover (and to VoiceOver always); its space is reserved so nothing jumps.
                Button(Copy.keep) { engine.keep(finding) }
                    .buttonStyle(.plain)
                    .font(Theme.font(.caption))
                    .foregroundStyle(.secondary)
                    .opacity(hovering ? 1 : 0)
                    .help(Copy.keepTip(finding.name))
                    .accessibilityLabel(Copy.a11yKeep(finding.name))
            }
            if finding.bytes > 0 {
                Text(Format.size(finding.bytes)).font(Theme.font(.caption)).foregroundStyle(.secondary).fixedSize()
            }
        }
        .frame(height: Theme.rowHeight)
        .padding(.horizontal, Theme.row)
        .background(RoundedRectangle(cornerRadius: Theme.rowRadius).fill(hovering ? Theme.hover : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    @ViewBuilder private var leading: some View {
        if closing {
            ProgressView().controlSize(.small).frame(width: 14, height: 14)
        } else if let outcome {
            switch outcome {
            case .done:
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tint).frame(width: 14)
            default:
                Image(systemName: "minus").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).frame(width: 14)
            }
        } else {
            Toggle("", isOn: Binding(
                get: { engine.selected.contains(finding.id) },
                set: { on in if on { engine.selected.insert(finding.id) } else { engine.selected.remove(finding.id) } }
            ))
            .toggleStyle(.checkbox)
            .tint(Theme.tint)
            .labelsHidden()
            .disabled(engine.isWorking)
            .accessibilityLabel(Copy.a11yInclude(finding.name, finding.bytes))
        }
    }

    @ViewBuilder private var icon: some View {
        if let path = finding.iconPath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: Theme.appIcon, height: Theme.appIcon)
        } else {
            Image(systemName: finding.symbol)
                .font(.system(size: Theme.symbol))
                .foregroundStyle(.secondary)
                .frame(width: Theme.appIcon, height: Theme.appIcon)
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
                .font(.system(size: Theme.symbol))
                .foregroundStyle(.secondary)
                .frame(width: Theme.appIcon, height: Theme.appIcon)
            VStack(alignment: .leading, spacing: Theme.hair) {
                Text(finding.name).font(Theme.font(.body))
                Text(finding.why).font(Theme.font(.caption)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let link = finding.link {
                    Button(link.title) { open(link) }.buttonStyle(.link).foregroundStyle(Theme.tint).font(Theme.font(.caption))
                }
            }
        }
        .padding(.horizontal, Theme.row)
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
