import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let jobs = JobQueue()
    private var windowController: MainWindowController?
    private var launchBuffer: [URL] = []
    private var launchSettled = false
    private var backgroundMode = false

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        DefaultHandler.claimIfPossible()
        Notifier.requestAuthorization()

        // Settle launch once, after any open-file event has been delivered.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.settleLaunch()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receive(urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        receive(filenames.map { URL(fileURLWithPath: $0) })
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - File routing

    private func receive(_ urls: [URL]) {
        if launchSettled {
            extractSilently(urls: urls)
        } else {
            launchBuffer.append(contentsOf: urls)
        }
    }

    private func settleLaunch() {
        launchSettled = true
        let files = launchBuffer
        launchBuffer = []
        if backgroundMode { return }
        if files.isEmpty {
            showMainWindow()
        } else {
            backgroundMode = true
            extractSilently(urls: files)
        }
    }

    private func extractSilently(urls: [URL]) {
        let archives = ArchiveURL.expand(urls)
        guard !archives.isEmpty else {
            Notifier.alert(title: "Unparchive", message: "Không tìm thấy file RAR hợp lệ.")
            quitIfBackground()
            return
        }
        jobs.enqueue(
            archives: archives,
            mode: .extract,
            perItem: { archive, result in
                switch result {
                case .success(let dest):
                    Notifier.post(title: "Đã giải nén", body: dest.lastPathComponent)
                case .cancelled:
                    Notifier.post(title: "Đã huỷ", body: archive.lastPathComponent)
                case .failure(let message):
                    Notifier.alert(
                        title: "Giải nén không thành công",
                        message: "\(archive.lastPathComponent)\n\n\(message)"
                    )
                }
            },
            completion: {
                self.quitIfBackground()
            }
        )
    }

    private func quitIfBackground() {
        guard backgroundMode, windowController == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Window

    private func showMainWindow(preloadedFile: URL? = nil, action: JobMode = .convertToZip) {
        backgroundMode = false
        NSApp.setActivationPolicy(.regular)
        if windowController == nil {
            windowController = MainWindowController()
        }
        windowController?.showWindow(nil)
        if let file = preloadedFile {
            windowController?.configure(withFile: file, action: action)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openMainWindowFromMenu(_ sender: Any?) {
        showMainWindow()
    }

    // MARK: - Services

    @objc func convertRARService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let archives = ArchiveURL.expand(Self.urls(from: pboard))
        guard let first = archives.first else { return }
        showMainWindow(preloadedFile: first, action: .convertToZip)
    }

    @objc func extractRARService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        if windowController == nil { backgroundMode = true }
        extractSilently(urls: Self.urls(from: pboard))
    }

    // MARK: - Menu

    func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Thoát Unparchive", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        let openItem = NSMenuItem(title: "Mở cửa sổ chuyển đổi…", action: #selector(openMainWindowFromMenu(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)
        fileMenuItem.submenu = fileMenu

        // Edit menu — enables Cmd+C/V/X/A in text fields
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cắt", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Sao chép", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Dán", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Chọn tất cả", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        return mainMenu
    }

    // MARK: - Helpers

    private static func urls(from pboard: NSPasteboard) -> [URL] {
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            return urls
        }
        if let paths = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            return paths.map { URL(fileURLWithPath: $0) }
        }
        return []
    }
}
