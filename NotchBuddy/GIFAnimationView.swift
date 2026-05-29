import AppKit

final class GIFAnimationView: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onTap: (() -> Void)?

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

    // MARK: - Mouse Events

    private var mouseDownLocation: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
    }

    override func mouseUp(with event: NSEvent) {
        let loc = event.locationInWindow
        let dist = hypot(loc.x - mouseDownLocation.x, loc.y - mouseDownLocation.y)
        if dist < 5 { onTap?() }
    }

    override func mouseDragged(with event: NSEvent) {
        onDrag?(event.deltaX)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override var acceptsFirstResponder: Bool { true }
}
