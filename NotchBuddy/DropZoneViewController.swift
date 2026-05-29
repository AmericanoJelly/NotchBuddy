import AppKit
import UniformTypeIdentifiers

private let supportedExtensions = Set(["gif", "jpeg", "jpg", "png"])

final class DropZoneViewController: NSViewController {
    private let onSelected: (URL) -> Void
    private let dropView = GIFDropView()
    private let errorLabel = NSTextField(labelWithString: "")
    private var errorHideTimer: Timer?

    init(onSelected: @escaping (URL) -> Void) {
        self.onSelected = onSelected
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 170))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dropView.translatesAutoresizingMaskIntoConstraints = false
        dropView.onDrop = { [weak self] url in self?.onSelected(url) }
        dropView.onUnsupportedFile = { [weak self] in self?.showError() }
        view.addSubview(dropView)

        let hintLabel = NSTextField(labelWithString: "GIF · JPG · PNG 드래그하세요 🐾")
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.alignment = .center
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .secondaryLabelColor
        dropView.addSubview(hintLabel)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.alignment = .center
        errorLabel.font = .systemFont(ofSize: 11, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true
        view.addSubview(errorLabel)

        let orLabel = NSTextField(labelWithString: "또는")
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        orLabel.alignment = .center
        orLabel.font = .systemFont(ofSize: 11)
        orLabel.textColor = .tertiaryLabelColor
        view.addSubview(orLabel)

        let btn = NSButton(title: "파일 선택", target: self, action: #selector(browse))
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.bezelStyle = .rounded
        view.addSubview(btn)

        NSLayoutConstraint.activate([
            dropView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            dropView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            dropView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            dropView.heightAnchor.constraint(equalToConstant: 90),
            hintLabel.centerXAnchor.constraint(equalTo: dropView.centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: dropView.centerYAnchor),
            errorLabel.topAnchor.constraint(equalTo: dropView.bottomAnchor, constant: 6),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            orLabel.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 2),
            orLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 6),
            btn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func showError() {
        errorHideTimer?.invalidate()
        errorLabel.stringValue = "GIF · JPG · PNG 파일만 지원합니다"
        errorLabel.isHidden = false
        errorHideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.errorLabel.isHidden = true
        }
    }

    @objc private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif, .jpeg, .png]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            onSelected(url)
        }
    }
}

final class GIFDropView: NSView {
    var onDrop: ((URL) -> Void)?
    var onUnsupportedFile: (() -> Void)?

    private enum HighlightState { case none, valid, invalid }
    private var highlightState: HighlightState = .none { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor
        let border: NSColor
        switch highlightState {
        case .none:
            bg = .quaternaryLabelColor.withAlphaComponent(0.08)
            border = .tertiaryLabelColor
        case .valid:
            bg = .controlAccentColor.withAlphaComponent(0.15)
            border = .controlAccentColor
        case .invalid:
            bg = .systemRed.withAlphaComponent(0.1)
            border = .systemRed
        }
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        border.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7)
        path.lineWidth = 1.5
        path.setLineDash([5, 4], count: 2, phase: 0)
        path.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let url = fileURL(from: sender) else { return [] }
        if supportedExtensions.contains(url.pathExtension.lowercased()) {
            highlightState = .valid
        } else {
            highlightState = .invalid
        }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { highlightState = .none }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        highlightState = .none
        guard let url = fileURL(from: sender) else { return false }
        if supportedExtensions.contains(url.pathExtension.lowercased()) {
            onDrop?(url)
        } else {
            onUnsupportedFile?()
        }
        return true
    }

    private func fileURL(from info: NSDraggingInfo) -> URL? {
        (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])?.first
    }
}
