import AppKit
import UserNotifications

enum Notifier {
    // `UNUserNotificationCenter.current()` needs a proper .app bundle; when the
    // bare executable is run directly (e.g. `swift run`) it would crash, so guard it.
    private static var notificationsAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static func requestAuthorization() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(title: String, body: String) {
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func alert(title: String, message: String) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                showAlert(title: title, message: message)
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    showAlert(title: title, message: message)
                }
            }
        }
    }

    @MainActor
    private static func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
