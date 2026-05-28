import AppKit
import ImageIO

struct GIFFrame {
    let image: NSImage
    let delay: TimeInterval
}

enum GIFLoader {
    static func load(from url: URL) async -> [GIFFrame] {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
            let count = CGImageSourceGetCount(source)
            guard count > 0 else { return [] }
            return (0..<count).compactMap { i -> GIFFrame? in
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { return nil }
                let delay = frameDelay(source: source, index: i)
                return GIFFrame(image: NSImage(cgImage: cgImage, size: .zero), delay: delay)
            }
        }.value
    }

    static func placeholder() -> [GIFFrame] {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemPink.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 28, height: 28)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 9, y: 14, width: 5, height: 5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 18, y: 14, width: 5, height: 5)).fill()
        image.unlockFocus()
        return [GIFFrame(image: image, delay: 0.5)]
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? TimeInterval
        return max(unclamped ?? clamped ?? 0.1, 0.02)
    }
}
