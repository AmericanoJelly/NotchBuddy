import AppKit

final class NotchOverlay {
    private var panel: NSPanel!
    private var animationView: GIFAnimationView!

    init() { setup() }

    private func setup() {
        guard let screen = NSScreen.main else { return }
        let h = menuBarHeight(screen: screen)
        let x = PersistenceManager.shared.savedXPosition ?? defaultX(screen: screen)
        let frame = NSRect(x: x, y: screen.frame.maxY - h, width: 60, height: h)

        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.hasShadow = false
        panel.acceptsMouseMovedEvents = true

        animationView = GIFAnimationView(frame: NSRect(origin: .zero, size: frame.size))
        animationView.onDrag = { [weak self] dx in self?.handleDrag(dx) }
        panel.contentView = animationView
        panel.orderFrontRegardless()
    }

    func loadGIF(from url: URL) {
        Task {
            let frames = await GIFLoader.load(from: url)
            guard !frames.isEmpty else { return }
            let processed = await BackgroundRemover.process(frames: frames)
            await MainActor.run {
                resize(for: processed)
                animationView.setFrames(processed)
            }
            PersistenceManager.shared.saveGIF(from: url)
        }
    }

    func loadDefaultGIF() {
        if let url = Bundle.main.url(forResource: "default", withExtension: "gif") {
            Task {
                let frames = await GIFLoader.load(from: url)
                await MainActor.run {
                    resize(for: frames)
                    animationView.setFrames(frames)
                }
            }
        } else {
            let frames = GIFLoader.placeholder()
            resize(for: frames)
            animationView.setFrames(frames)
        }
    }

    private func resize(for frames: [GIFFrame]) {
        guard let screen = NSScreen.main, let first = frames.first else { return }
        let maxH = menuBarHeight(screen: screen)
        let ratio = first.image.size.width / max(first.image.size.height, 1)
        let h = min(first.image.size.height, maxH)
        let w = min(h * ratio, 80)
        var f = panel.frame
        f.size = NSSize(width: max(w, 20), height: max(h, 20))
        f.origin.y = screen.frame.maxY - f.size.height
        f.origin.x = min(f.origin.x, screen.frame.width - f.size.width)
        panel.setFrame(f, display: true)
        animationView.frame = NSRect(origin: .zero, size: f.size)
    }

    private func handleDrag(_ deltaX: CGFloat) {
        guard let screen = NSScreen.main else { return }
        var origin = panel.frame.origin
        origin.x = (origin.x + deltaX).clamped(to: 0...(screen.frame.width - panel.frame.width))
        panel.setFrameOrigin(origin)
        PersistenceManager.shared.saveXPosition(origin.x)
    }

    private func menuBarHeight(screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0 {
            return screen.safeAreaInsets.top
        }
        return 24
    }

    private func defaultX(screen: NSScreen) -> CGFloat {
        screen.frame.midX + 160 + 16
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
