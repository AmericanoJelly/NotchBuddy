import AppKit

final class GIFAnimationView: NSView {
    var onDrag: ((CGFloat) -> Void)?

    private var frames: [GIFFrame] = []
    private var currentIndex = 0
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
    }

    required init?(coder: NSCoder) { fatalError() }

    func setFrames(_ frames: [GIFFrame]) {
        timer?.invalidate()
        self.frames = frames
        currentIndex = 0
        needsDisplay = true
        guard !frames.isEmpty else { return }
        scheduleNext()
    }

    private func scheduleNext() {
        guard !frames.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: frames[currentIndex].delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.currentIndex = (self.currentIndex + 1) % self.frames.count
            self.needsDisplay = true
            self.scheduleNext()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !frames.isEmpty else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        frames[currentIndex].image.draw(in: bounds)
    }

    // MARK: - Drag to reposition (X axis only)

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        onDrag?(event.deltaX)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override var acceptsFirstResponder: Bool { true }
}
