import AppKit
import UserNotifications

/// One optional note when the Mac is struggling. Opt-in: nothing is asked of macOS until the user turns it on.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    nonisolated static let enabledKey = "notifications"

    var enabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    /// UNUserNotificationCenter traps when the process isn't a real bundle (--selftest, --scan, --snapshot from .build).
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func install() {
        guard available else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// The toggle only records intent; macOS holds the real switch. Runs when the user opts in and at each launch while opted in.
    func requestAuthorization(atLaunch: Bool = false) {
        guard enabled, available else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                switch status {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                        if let error { NSLog("YouFixIt notification auth failed: %@", String(describing: error)) }
                        if !granted { DispatchQueue.main.async { UserDefaults.standard.set(false, forKey: Notifier.enabledKey) } }
                    }
                case .denied where atLaunch:
                    UserDefaults.standard.set(false, forKey: Self.enabledKey)
                case .denied:
                    let id = Bundle.main.bundleIdentifier ?? ""
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
                        NSWorkspace.shared.open(url)
                    }
                default:
                    break
                }
            }
        }
    }

    func post(_ title: String, _ body: String) {
        guard enabled, available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // Banners show even while the popover is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
