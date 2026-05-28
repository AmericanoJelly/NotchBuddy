import AppKit
import UniformTypeIdentifiers

final class DropZoneViewController: NSViewController {
    private let onSelected: (URL) -> Void
    private let dropView = GIFDropView()

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
        view.addSubview(dropView)

        let label = NSTextField(labelWithString: "GIF을 여기에 드래그하세요 🐾")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        dropView.addSubview(label)

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
            label.centerXAnchor.constraint(equalTo: dropView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: dropView.centerYAnchor),
            orLabel.topAnchor.constraint(equalTo: dropView.bottomAnchor, constant: 8),
            orLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 6),
            btn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            onSelected(url)
        }
    }
}

final class GIFDropView: NSView {
    var onDrop: ((URL) -> Void)?
    private var highlighted = false { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor = highlighted ? .controlAccentColor.withAlphaComponent(0.15) : .quaternaryLabelColor.withAlphaComponent(0.08)
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        let border: NSColor = highlighted ? .controlAccentColor : .tertiaryLabelColor
        border.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7)
        path.lineWidth = 1.5
        path.setLineDash([5, 4], count: 2, phase: 0)
        path.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard gifURL(from: sender) != nil else { return [] }
        highlighted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { highlighted = false }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        highlighted = false
        guard let url = gifURL(from: sender) else { return false }
        onDrop?(url)
        return true
    }

    private func gifURL(from info: NSDraggingInfo) -> URL? {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              let url = urls.first,
              url.pathExtension.lowercased() == "gif" else { return nil }
        return url
    }
}
