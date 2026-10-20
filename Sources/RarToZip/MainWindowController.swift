import AppKit
import UniformTypeIdentifiers

// Root content view that accepts drag-and-drop of .rar/.cbr files.
final class DropView: NSView {
    var onDropURLs: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepted = acceptableURLs(sender)
        setHighlight(!accepted.isEmpty)
        return accepted.isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setHighlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = acceptableURLs(sender)
        defer { setHighlight(false) }
        guard !urls.isEmpty else { return false }
        onDropURLs?(urls)
        return true
    }

    private func acceptableURLs(_ sender: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }
        return urls.filter { ["rar", "cbr"].contains($0.pathExtension.lowercased()) }
    }

    private func setHighlight(_ on: Bool) {
        wantsLayer = true
        layer?.backgroundColor = (on ? NSColor.controlAccentColor.withAlphaComponent(0.10) : NSColor.clear).cgColor
    }
}

@MainActor
final class MainWindowController: NSWindowController {

    private let jobs = JobQueue()

    private var inputField: NSTextField!
    private var outputDirField: NSTextField!
    private var nameField: NSTextField!
    private var actionPopup: NSPopUpButton!
    private var compressionPopup: NSPopUpButton!
    private var progressIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var startButton: NSButton!
    private var revealButton: NSButton!
    private var lastResultURL: URL?

    // MARK: - Init

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RarToZip"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        let dropView = DropView(frame: NSRect(x: 0, y: 0, width: 660, height: 430))
        dropView.onDropURLs = { [weak self] urls in
            self?.handleDrop(urls)
        }
        window.contentView = dropView

        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(withFile url: URL, action: JobMode) {
        inputField.stringValue = url.path
        outputDirField.stringValue = url.deletingLastPathComponent().path
        nameField.stringValue = url.deletingPathExtension().lastPathComponent
        actionPopup.selectItem(at: action == .convertToZip ? 0 : 1)
        updateActionUI()
    }

    private func handleDrop(_ urls: [URL]) {
        guard let first = urls.first else { return }
        inputField.stringValue = first.path
        outputDirField.stringValue = first.deletingLastPathComponent().path
        nameField.stringValue = first.deletingPathExtension().lastPathComponent
        lastResultURL = nil
        revealButton.isHidden = true
        if urls.count > 1 {
            statusLabel.stringValue = "Đã nhận \(urls.count) file — dùng file đầu: \(first.lastPathComponent)"
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    // MARK: - UI Building

    private func buildUI() {
        guard let content = window?.contentView else { return }

        func makeLabel(_ text: String) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.alignment = .right
            l.translatesAutoresizingMaskIntoConstraints = false
            l.setContentHuggingPriority(.required, for: .horizontal)
            l.setContentCompressionResistancePriority(.required, for: .horizontal)
            return l
        }

        func makeField(_ placeholder: String) -> NSTextField {
            let f = NSTextField()
            f.placeholderString = placeholder
            f.translatesAutoresizingMaskIntoConstraints = false
            f.lineBreakMode = .byTruncatingMiddle
            f.setContentHuggingPriority(.defaultLow, for: .horizontal)
            return f
        }

        func makeButton(_ title: String, _ action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.setContentHuggingPriority(.required, for: .horizontal)
            b.setContentCompressionResistancePriority(.required, for: .horizontal)
            return b
        }

        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 12
        form.translatesAutoresizingMaskIntoConstraints = false

        func addFormRow(_ views: [NSView]) {
            let row = NSStackView(views: views)
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.translatesAutoresizingMaskIntoConstraints = false
            form.addArrangedSubview(row)
        }

        // Hint
        let hint = NSTextField(labelWithString: "Kéo-thả file .rar/.cbr vào cửa sổ để điền nhanh.")
        hint.textColor = .tertiaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        hint.translatesAutoresizingMaskIntoConstraints = false
        form.addArrangedSubview(hint)

        // Row 1: input file
        inputField = makeField("Chọn file .rar")
        inputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        addFormRow([makeLabel("File RAR:"), inputField, makeButton("Chọn…", #selector(chooseInput(_:)))])

        // Row 2: output dir
        outputDirField = makeField("Nơi lưu kết quả")
        outputDirField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        addFormRow([makeLabel("Thư mục đích:"), outputDirField, makeButton("Chọn…", #selector(chooseOutputDir(_:)))])

        // Row 3: output name
        nameField = makeField("(mặc định theo tên file RAR)")
        nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        addFormRow([makeLabel("Tên file:"), nameField])

        // Row 4: action
        actionPopup = NSPopUpButton()
        actionPopup.addItems(withTitles: ["Convert sang ZIP", "Giải nén"])
        actionPopup.target = self
        actionPopup.action = #selector(actionChanged(_:))
        actionPopup.translatesAutoresizingMaskIntoConstraints = false
        actionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        addFormRow([makeLabel("Hành động:"), actionPopup])

        // Row 5: zip compression
        compressionPopup = NSPopUpButton()
        compressionPopup.addItems(withTitles: ["Nhanh", "Nhỏ"])
        compressionPopup.selectItem(at: 0)
        compressionPopup.translatesAutoresizingMaskIntoConstraints = false
        compressionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        addFormRow([makeLabel("Nén ZIP:"), compressionPopup])

        // Row 6: status
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusRow = NSStackView(views: [progressIndicator, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 8
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        form.addArrangedSubview(statusRow)

        // Row 7: buttons
        startButton = NSButton(title: "Bắt đầu", target: self, action: #selector(start(_:)))
        startButton.keyEquivalent = "\r"
        startButton.translatesAutoresizingMaskIntoConstraints = false

        revealButton = NSButton(title: "Mở trong Finder", target: self, action: #selector(revealResult(_:)))
        revealButton.isHidden = true
        revealButton.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(title: "Đóng", target: self, action: #selector(dismissWindow(_:)))
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = NSStackView(views: [startButton, revealButton, closeButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        form.addArrangedSubview(buttonRow)

        content.addSubview(form)

        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            form.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            form.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            form.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Actions

    @objc private func actionChanged(_ sender: Any?) {
        updateActionUI()
    }

    private func updateActionUI() {
        compressionPopup.isEnabled = actionPopup.indexOfSelectedItem == 0
    }

    @objc private func chooseInput(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Chọn file RAR"
        var allowed: [UTType] = []
        if let rar = UTType(filenameExtension: "rar") { allowed.append(rar) }
        if let cbr = UTType(filenameExtension: "cbr") { allowed.append(cbr) }
        if !allowed.isEmpty { panel.allowedContentTypes = allowed }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        inputField.stringValue = url.path
        outputDirField.stringValue = url.deletingLastPathComponent().path
        if nameField.stringValue.isEmpty {
            nameField.stringValue = url.deletingPathExtension().lastPathComponent
        }
    }

    @objc private func chooseOutputDir(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Chọn thư mục đích"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputDirField.stringValue = url.path
    }

    @objc private func start(_ sender: Any?) {
        let inputPath = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !inputPath.isEmpty else {
            showError("Hãy chọn file RAR trước.")
            return
        }
        let archive = URL(fileURLWithPath: inputPath)
        guard FileManager.default.fileExists(atPath: archive.path) else {
            showError("File không tồn tại: \(archive.path)")
            return
        }
        let ext = archive.pathExtension.lowercased()
        guard ext == "rar" || ext == "cbr" else {
            showError("File phải có phần mở rộng .rar hoặc .cbr.")
            return
        }

        let dirPath = outputDirField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !dirPath.isEmpty else {
            showError("Hãy chọn thư mục đích.")
            return
        }
        let outputDir = URL(fileURLWithPath: dirPath)
        if !FileManager.default.fileExists(atPath: outputDir.path) {
            do {
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            } catch {
                showError("Không tạo được thư mục đích: \(error.localizedDescription)")
                return
            }
        }

        var name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            name = archive.deletingPathExtension().lastPathComponent
            nameField.stringValue = name
        }

        let mode: JobMode = actionPopup.indexOfSelectedItem == 0 ? .convertToZip : .extract
        let compression: CompressionLevel = compressionPopup.indexOfSelectedItem == 0 ? .fast : .small

        setRunning(true)
        lastResultURL = nil
        revealButton.isHidden = true
        statusLabel.stringValue = ""

        jobs.enqueue(
            archives: [archive],
            mode: mode,
            compression: compression,
            perItem: { [weak self] _, result in
                self?.handleResult(result)
            },
            completion: {}
        )
    }

    @objc private func revealResult(_ sender: Any?) {
        guard let url = lastResultURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func dismissWindow(_ sender: Any?) {
        window?.close()
    }

    // MARK: - Helpers

    private func handleResult(_ result: JobResult) {
        setRunning(false)
        switch result {
        case .success(let dest):
            lastResultURL = dest
            statusLabel.stringValue = "Xong: \(dest.lastPathComponent)"
            statusLabel.textColor = .systemGreen
            revealButton.isHidden = false
        case .cancelled:
            statusLabel.stringValue = "Đã huỷ."
            statusLabel.textColor = .secondaryLabelColor
        case .failure(let message):
            statusLabel.stringValue = "Lỗi: \(message)"
            statusLabel.textColor = .systemRed
        }
    }

    private func setRunning(_ running: Bool) {
        if running {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
        startButton.isEnabled = !running
        inputField.isEnabled = !running
        outputDirField.isEnabled = !running
        nameField.isEnabled = !running
        actionPopup.isEnabled = !running
        if !running {
            updateActionUI()
        } else {
            compressionPopup.isEnabled = false
        }
    }

    private func showError(_ message: String) {
        guard let window = window else { return }
        let alert = NSAlert()
        alert.messageText = "RarToZip"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
}
