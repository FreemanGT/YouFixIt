import AppKit
import SwiftUI

/// The menu bar window: a mood sentence, the suggestions, one button, what's good to know, a footer.
struct PopoverView: View {
    enum Pane { case main, settings }

    @Bindable var engine: Engine
    @State var pane: Pane = .main
    @State var knowOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch pane {
            case .main: MainPane(engine: engine, knowOpen: $knowOpen) { pane = .settings }
            case .settings: SettingsPane(engine: engine) { pane = .main }
            }
        }
        .frame(width: Theme.popoverWidth)
        .tint(Theme.tint)
        .animation(reduceMotion ? .easeInOut(duration: Theme.state) : Theme.settle, value: pane)
        .onAppear { engine.popoverOpen = true }
        .onDisappear { engine.popoverOpen = false }
    }
}

struct MainPane: View {
    @Bindable var engine: Engine
    @Binding var knowOpen: Bool
    let openSettings: () -> Void
    @State private var appeared = false
    @State private var shownTotal: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rows: [Finding] { engine.running + engine.space }
    private var doneRows: [Engine.Row] { engine.result?.rows.filter { $0.outcome != .done } ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Theme.edge)
                .padding(.top, Theme.edge)
                .padding(.bottom, Theme.gap)
            if hasList {
                MeasuredScroll(maxHeight: Theme.popoverMaxHeight - 200, estimate: estimatedListHeight) {
                    VStack(alignment: .leading, spacing: Theme.section) {
                        if engine.mood == .done, !doneRows.isEmpty {
                            section(Copy.sectionRunning) {
                                ForEach(doneRows) { row in
                                    FindingRow(finding: row.finding, engine: engine)
                                }
                            }
                        } else {
                            if !engine.running.isEmpty { group(Copy.sectionRunning, engine.running, offset: 0) }
                            if !engine.space.isEmpty { group(Copy.sectionSpace, engine.space, offset: engine.running.count) }
                        }
                        if !engine.know.isEmpty { knowSection }
                    }
                    .padding(.horizontal, Theme.row)
                    .padding(.bottom, Theme.tight)
                }
            }
            if let kept = engine.kept, engine.mood != .paused {
                keptLine(kept)
                    .padding(.horizontal, Theme.edge)
                    .padding(.top, Theme.gap)
            }
            if engine.mood != .paused, !engine.actionable.isEmpty || engine.mood == .done || engine.mood == .working {
                primary
                    .padding(.horizontal, Theme.edge)
                    .padding(.top, Theme.gap)
            }
            footer
                .padding(.horizontal, Theme.edge)
                .padding(.top, Theme.gap)
                .padding(.bottom, Theme.gap)
        }
        .animation(reduceMotion ? .easeInOut(duration: Theme.exit) : Theme.leave, value: engine.findings)
        .animation(reduceMotion ? .easeInOut(duration: Theme.state) : Theme.settle, value: engine.mood)
        .onAppear {
            appeared = true
            if let r = engine.result { shownTotal = Double(r.freed) }
        }
        .task { if Render.offscreen { appeared = true } }
        .onChange(of: engine.result) { _, new in
            if let new {
                shownTotal = 0
                withAnimation(reduceMotion || Render.offscreen ? nil : .easeOut(duration: Theme.count)) { shownTotal = Double(new.freed) }
            }
        }
    }

    /// Rows are fixed height, so the list's size is known before layout. Only an open Good to know varies.
    private var estimatedListHeight: CGFloat {
        let sectionHead: CGFloat = 16 + Theme.tight
        var h: CGFloat = Theme.tight
        var sections = 0
        if engine.mood == .done, !doneRows.isEmpty {
            h += sectionHead + CGFloat(doneRows.count) * Theme.rowHeight; sections += 1
        } else {
            if !engine.running.isEmpty { h += sectionHead + CGFloat(engine.running.count) * Theme.rowHeight; sections += 1 }
            if !engine.space.isEmpty { h += sectionHead + CGFloat(engine.space.count) * Theme.rowHeight; sections += 1 }
        }
        if !engine.know.isEmpty { h += 20 + (knowOpen ? CGFloat(engine.know.count) * 56 : 0); sections += 1 }
        h += CGFloat(max(0, sections - 1)) * Theme.section
        return h
    }

    private var hasList: Bool {
        engine.mood != .paused && (!rows.isEmpty || !engine.know.isEmpty || (engine.mood == .done && !doneRows.isEmpty))
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            switch engine.mood {
            case .scanning:
                Text(Copy.headerScanning).font(Theme.font(.title))
            case .calm:
                Text(engine.know.isEmpty ? Copy.headerEmpty : Copy.headerCalm).font(Theme.font(.title))
                if engine.know.isEmpty { Text(Copy.subEmpty).font(Theme.font(.body)).foregroundStyle(.secondary) }
            case .light:
                Text(Copy.headerLight).font(Theme.font(.title))
            case .heavy:
                Text(Copy.headerHeavy).font(Theme.font(.title))
            case .working:
                Text(Copy.headerWorking).font(Theme.font(.title))
            case .done:
                let freed = engine.result?.freed ?? 0
                Text(Copy.headerDone(UInt64(shownTotal)))
                    .font(Theme.font(.hero))
                    .contentTransition(.numericText(value: shownTotal))
                Text(freed > 0 ? Copy.subDone : Copy.subDoneNothing).font(Theme.font(.body)).foregroundStyle(.secondary)
            case .paused:
                Text(Copy.headerPaused(until: engine.pausedUntil ?? Date())).font(Theme.font(.title))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .transition(.opacity)
        .id(engine.mood)
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            Text(title)
                .font(Theme.font(.caption))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.row)
            content()
        }
    }

    private func group(_ title: String, _ findings: [Finding], offset: Int) -> some View {
        section(title) {
            ForEach(Array(findings.enumerated()), id: \.element.id) { index, finding in
                FindingRow(finding: finding, engine: engine)
                    .opacity(appeared || Render.offscreen ? 1 : 0)
                    .offset(y: appeared || reduceMotion || Render.offscreen ? 0 : 8)
                    .animation(entrance(index + offset), value: appeared)
                    .transition(.opacity)
            }
        }
    }

    private func entrance(_ index: Int) -> Animation? {
        if Render.offscreen { return nil }
        return reduceMotion ? .easeOut(duration: 0.2) : Theme.arrive.delay(Double(min(index, Theme.staggerCap)) * Theme.stagger)
    }

    private func keptLine(_ kept: (key: String, name: String)) -> some View {
        HStack(spacing: Theme.row) {
            Text(Copy.kept(kept.name)).font(Theme.font(.caption)).foregroundStyle(.secondary).lineLimit(1)
            Button(Copy.undo) { engine.unkeep(kept.key) }.buttonStyle(.link).foregroundStyle(Theme.tint).font(Theme.font(.caption))
        }
        .transition(.opacity)
    }

    private var knowSection: some View {
        DisclosureGroup(isExpanded: $knowOpen) {
            VStack(alignment: .leading, spacing: Theme.row) {
                ForEach(engine.know) { KnowRow(finding: $0) }
            }
            .padding(.top, Theme.tight)
        } label: {
            Text(Copy.sectionKnow).font(Theme.font(.caption)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.row)
    }

    // MARK: - The button

    @ViewBuilder private var primary: some View {
        VStack(spacing: Theme.tight) {
            if engine.mood == .done, engine.canUndo {
                Button { Task { await engine.undo() } } label: {
                    Text(Copy.undo).frame(maxWidth: .infinity).frame(height: Theme.buttonHeight - 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                Text(Copy.undoCaption).font(Theme.font(.caption)).foregroundStyle(.secondary)
            } else if engine.mood != .done {
                let none = engine.selectedFindings.isEmpty
                Button { Task { await engine.clean() } } label: {
                    Text(engine.isWorking ? Copy.headerWorking : (none ? Copy.nothingSelected : Copy.tidyUp))
                        .frame(maxWidth: .infinity).frame(height: Theme.buttonHeight - 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.tint)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(none || engine.isWorking)
                .accessibilityLabel(Copy.a11yTidy(engine.selectedFindings.count, engine.selectedMemory + engine.selectedSpace))
                let caption = Copy.frees(memory: engine.selectedMemory, space: engine.selectedSpace)
                if !caption.isEmpty {
                    Text(caption).font(Theme.font(.caption)).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(Theme.settle, value: caption)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Theme.row) {
            if engine.mood == .paused, let until = engine.pausedUntil {
                Text(Copy.pausedUntil(until)).font(Theme.font(.caption)).foregroundStyle(.secondary)
                Button(Copy.resume) { engine.resume() }.buttonStyle(.link).foregroundStyle(Theme.tint).font(Theme.font(.caption))
            } else {
                Text(Copy.checked(ago: engine.lastScan)).font(Theme.font(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            if engine.mood != .paused {
                Button { engine.pause(for: 3600) } label: { Image(systemName: "pause.circle") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help(Copy.pauseTip).accessibilityLabel(Copy.pauseTip)
            }
            Button(action: openSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help(Copy.settingsTip).accessibilityLabel(Copy.settingsTip)
        }
    }
}

/// A scroll view that is as tall as its content, up to a cap.
struct MeasuredScroll<Content: View>: View {
    let maxHeight: CGFloat
    let content: () -> Content
    @State private var height: CGFloat

    init(maxHeight: CGFloat, estimate: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.maxHeight = maxHeight
        self.content = content
        _height = State(initialValue: estimate)
    }

    var body: some View {
        ScrollView(.vertical) {
            content()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .frame(height: min(height, maxHeight))
    }
}
