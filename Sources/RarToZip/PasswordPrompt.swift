import AppKit

enum PasswordPrompt {
    static func ask(archiveName: String, retryMessage: String?) -> String? {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                prompt(archiveName: archiveName, retryMessage: retryMessage)
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                prompt(archiveName: archiveName, retryMessage: retryMessage)
            }
        }
    }

    @MainActor
    private static func prompt(archiveName: String, retryMessage: String?) -> String? {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "File RAR có mật khẩu"
        alert.informativeText = retryMessage ?? "Nhập mật khẩu để mở “\(archiveName)”."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Hủy")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "Mật khẩu"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let password = field.stringValue
        return password.isEmpty ? nil : password
    }
}
