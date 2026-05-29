import AppKit
import CoreGraphics

final class NotchOverlay {
    private var panel: NSPanel!
    private var animationView: GIFAnimationView!
    private var frames: [GIFFrame] = []

    private var isExpanded = false
    private var expandedPanel: NSPanel?
    private var expandedAnimView: GIFAnimationView?
    private var globalEventMonitor: Any?

    init() { setup() }

    private func setup() {
        guard let screen = builtinScreen() else { return }
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
        animationView.onTap = { [weak self] in self?.toggleExpanded() }
        panel.contentView = animationView
        panel.orderFrontRegardless()
    }

    func loadGIF(from url: URL) {
        Task {
            let loaded = await GIFLoader.load(from: url)
            guard !loaded.isEmpty else { return }
            let processed = await BackgroundRemover.process(frames: loaded)
            await MainActor.run {
                frames = processed
                resize(for: processed)
                animationView.setFrames(processed)
                if isExpanded { expandedAnimView?.setFrames(processed) }
            }
            PersistenceManager.shared.saveGIF(from: url)
        }
    }

    func loadDefaultGIF() {
        if let url = Bundle.main.url(forResource: "default", withExtension: "gif") {
            Task {
                let loaded = await GIFLoader.load(from: url)
                let processed = await BackgroundRemover.process(frames: loaded)
                await MainActor.run {
                    frames = processed
                    resize(for: processed)
                    animationView.setFrames(processed)
                    if isExpanded { expandedAnimView?.setFrames(processed) }
                }
            }
        } else {
            let loaded = GIFLoader.placeholder()
            frames = loaded
            resize(for: loaded)
            animationView.setFrames(loaded)
        }
    }

    // MARK: - Expand / Collapse

    private func toggleExpanded() {
        isExpanded ? hideExpanded() : showExpanded()
    }

    private func showExpanded() {
        guard let screen = builtinScreen(), !frames.isEmpty else { return }
        isExpanded = true
        animationView.isHidden = true

        let first = frames[0]
        let ratio = first.image.size.width / max(first.image.size.height, 1)
        let h: CGFloat = min(200, max(first.image.size.height * 5, 100))
        let w: CGFloat = h * ratio
        let notchMidX = panel.frame.midX
        let x = (notchMidX - w / 2).clamped(to: 0...(screen.frame.width - w))
        let y = screen.frame.maxY - menuBarHeight(screen: screen) - h - 8

        let ep = NSPanel(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        ep.backgroundColor = .clear
        ep.isOpaque = false
        ep.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        ep.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        ep.hasShadow = false

        let eav = GIFAnimationView(frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)))
        eav.onTap = { [weak self] in self?.hideExpanded() }
        eav.setFrames(frames)
        ep.contentView = eav
        ep.orderFrontRegardless()

        expandedPanel = ep
        expandedAnimView = eav

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.hideExpanded() }
        }
    }

    private func hideExpanded() {
        guard isExpanded else { return }
        isExpanded = false
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        expandedPanel?.close()
        expandedPanel = nil
        expandedAnimView = nil
        animationView.isHidden = false
    }

    // MARK: - Layout

    private func resize(for frames: [GIFFrame]) {
        guard let screen = builtinScreen(), let first = frames.first else { return }
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
        guard let screen = builtinScreen() else { return }
        var origin = panel.frame.origin
        origin.x = (origin.x + deltaX).clamped(to: 0...(screen.frame.width - panel.frame.width))
        panel.setFrameOrigin(origin)
        PersistenceManager.shared.saveXPosition(origin.x)
    }

    private func builtinScreen() -> NSScreen? {
        NSScreen.screens.first {
            guard let id = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        } ?? NSScreen.main
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
