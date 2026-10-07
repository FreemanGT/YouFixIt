import AppKit
import ServiceManagement
import SwiftUI

struct SettingsPane: View {
    @Bindable var engine: Engine
    let back: () -> Void
    @AppStorage(Sound.enabledKey) private var softSounds = true
    @AppStorage(Notifier.enabledKey) private var notifications = false
    @AppStorage(Nudge.modeKey) private var nudgeMode = Nudge.Mode.struggling.rawValue
    @State private var loginItem = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            HStack(spacing: Theme.tight) {
                Button(action: back) {
                    HStack(spacing: Theme.hair) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text(Copy.back)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(Theme.font(.caption))
                .keyboardShortcut(.cancelAction)
                Spacer()
                Text(Copy.settingsTip).font(Theme.font(.title))
                Spacer()
                Color.clear.frame(width: 40, height: 1)
            }

            Toggle(Copy.openAtLogin, isOn: Binding(get: { loginItem }, set: { setLoginItem($0) }))
            HStack {
                Toggle(Copy.softSounds, isOn: $softSounds)
                Spacer()
                Button(Copy.playSample) { Sound.play(.done, force: true) }.controlSize(.small)
            }
            VStack(alignment: .leading, spacing: Theme.hair) {
                Toggle(Copy.notifications, isOn: Binding(get: { notifications }, set: { on in
                    notifications = on
                    if on { Notifier.shared.requestAuthorization() }
                }))
                Text(Copy.notificationsCaption).font(Theme.font(.caption)).foregroundStyle(.secondary).padding(.leading, 20)
            }
            Picker(Copy.nudgeMe, selection: $nudgeMode) {
                Text(Copy.nudgeStruggling).tag(Nudge.Mode.struggling.rawValue)
                Text(Copy.nudgeDaily).tag(Nudge.Mode.daily.rawValue)
                Text(Copy.nudgeNever).tag(Nudge.Mode.never.rawValue)
            }

            Divider()

            VStack(alignment: .leading, spacing: Theme.tight) {
                Text(Copy.alwaysKeep).font(Theme.font(.body))
                Text(Copy.alwaysKeepCaption).font(Theme.font(.caption)).foregroundStyle(.secondary)
                if engine.keep.isEmpty {
                    Text(Copy.alwaysKeepEmpty).font(Theme.font(.caption)).foregroundStyle(.tertiary).padding(.top, Theme.hair)
                } else {
                    ForEach(engine.keep.sorted(by: { $0.value < $1.value }), id: \.key) { key, name in
                        HStack {
                            Text(name).font(Theme.font(.body)).lineLimit(1)
                            Spacer()
                            Button(Copy.remove) { engine.unkeep(key) }.buttonStyle(.link).foregroundStyle(Theme.tint).font(Theme.font(.caption))
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button(Copy.pauseHour) { engine.pause(for: 3600); back() }.controlSize(.small)
                Spacer()
                Button(Copy.quit) { NSApp.terminate(nil) }.controlSize(.small)
            }
        }
        .toggleStyle(.switch)
        .tint(Theme.tint)
        .controlSize(.small)
        .font(Theme.font(.body))
        .padding(Theme.edge)
    }

    private func setLoginItem(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("YouFixIt login item: \(error)")
        }
        if on, SMAppService.mainApp.status != .enabled { SMAppService.openSystemSettingsLoginItems() }
        loginItem = SMAppService.mainApp.status == .enabled
    }
}
