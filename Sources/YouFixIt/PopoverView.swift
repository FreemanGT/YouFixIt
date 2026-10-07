import AppKit
import SwiftUI

/// The menu bar window: the face and a mood sentence, the suggestions as cards, one pill, what's good to know, a footer.
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
                MeasuredScroll(maxHeight: Theme.popoverMaxHeight - 220, estimate: estimatedListHeight) {
                    VStack(alignment: .leading, spacing: Theme.section) {
                        if engine.mood == .done, !doneRows.isEmpty {
                            section(Copy.sectionRunning, count: doneRows.count) {
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
                    .padding(.horizontal, Theme.edge)
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

    /// Cards are fixed height, so the list's size is known before layout. Only an open Good to know varies.
    private var estimatedListHeight: CGFloat {
        let sectionHead: CGFloat = 16 + Theme.row
        func cards(_ n: Int) -> CGFloat { CGFloat(n) * Theme.cardHeight + CGFloat(max(0, n - 1)) * Theme.cardGap }
        var h: CGFloat = Theme.tight
        var sections = 0
        if engine.mood == .done, !doneRows.isEmpty {
            h += sectionHead + cards(doneRows.count); sections += 1
        } else {
            if !engine.running.isEmpty { h += sectionHead + cards(engine.running.count); sections += 1 }
            if !engine.space.isEmpty { h += sectionHead + cards(engine.space.count); sections += 1 }
        }
        if !engine.know.isEmpty { h += 44 + (knowOpen ? CGFloat(engine.know.count) * 64 : 0); sections += 1 }
        h += CGFloat(max(0, sections - 1)) * Theme.section
        return h
    }

    private var hasList: Bool {
        engine.mood != .paused && (!rows.isEmpty || !engine.know.isEmpty || (engine.mood == .done && !doneRows.isEmpty))
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        HStack(alignment: .top, spacing: Theme.gap) {
            Pebble(mood: engine.mood)
                .frame(width: Theme.faceSize.width, height: Theme.faceSize.height)
                .padding(.top, Theme.hair)
            VStack(alignment: .leading, spacing: Theme.tight) {
                switch engine.mood {
                case .scanning:
                    Text(Copy.headerScanning).font(Theme.font(.title))
                case .calm:
                    Text(engine.know.isEmpty ? Copy.headerEmpty : Copy.headerCalm).font(Theme.font(.title))
                    if engine.know.isEmpty { Text(Copy.subEmpty).font(Theme.font(.body)).foregroundStyle(.secondary) }
                case .light:
                    Text(Copy.headerLight).font(Theme.font(.title))
                    Text(Copy.subLight).font(Theme.font(.body)).foregroundStyle(.secondary)
                case .heavy:
                    Text(Copy.headerHeavy).font(Theme.font(.title))
                    Text(Copy.subHeavy).font(Theme.font(.body)).foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(.opacity)
        .id(engine.mood)
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.row) {
            HStack(spacing: Theme.row) {
                Text(title).font(Theme.font(.caption)).foregroundStyle(.secondary)
                countPill(count)
            }
            .padding(.horizontal, Theme.tight)
            VStack(spacing: Theme.cardGap) { content() }
        }
    }

    private func countPill(_ n: Int) -> some View {
        Text("\(n)")
            .font(Theme.font(.badge)).foregroundStyle(.secondary)
            .padding(.horizontal, Theme.row - Theme.hair).padding(.vertical, 1)
            .background(Capsule().fill(Theme.pill))
    }

    private func group(_ title: String, _ findings: [Finding], offset: Int) -> some View {
        section(title, count: findings.count) {
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
                ForEach(Array(engine.know.enumerated()), id: \.element.id) { index, finding in
                    if index > 0 { Divider() }
                    KnowRow(finding: finding)
                }
            }
            .padding(.top, Theme.row)
        } label: {
            HStack(spacing: Theme.row) {
                Text(Copy.sectionKnow).font(Theme.font(.bodyStrong))
                countPill(engine.know.count)
            }
        }
        .padding(.leading, Theme.tight)
        .card()
    }

    // MARK: - The button

    @ViewBuilder private var primary: some View {
        VStack(spacing: Theme.tight) {
            if engine.mood == .done, engine.canUndo {
                Button { Task { await engine.undo() } } label: { PillLabel(title: Copy.undo, filled: false) }
                    .buttonStyle(PillStyle(filled: false))
                    .keyboardShortcut(.defaultAction)
                Text(Copy.undoCaption).font(Theme.font(.caption)).foregroundStyle(.secondary)
            } else if engine.mood != .done {
                let none = engine.selectedFindings.isEmpty
                Button { Task { await engine.clean() } } label: {
                    PillLabel(title: engine.isWorking ? Copy.headerWorking : (none ? Copy.nothingSelected : Copy.tidyUp), showKey: !none && !engine.isWorking)
                }
                .buttonStyle(PillStyle())
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

    private var overflows: Bool { height > maxHeight + 1 }

    var body: some View {
        ScrollView(.vertical) {
            content()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .frame(height: min(height, maxHeight))
        // A soft fade at the bottom says "there is more" without a scroll bar.
        .mask(
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, overflows ? .clear : .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: Theme.fade)
            }
        )
    }
}
