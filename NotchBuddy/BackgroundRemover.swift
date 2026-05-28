import AppKit
import Vision

enum BackgroundRemover {
    static func process(frames: [GIFFrame]) async -> [GIFFrame] {
        guard #available(macOS 14.0, *) else { return frames }
        return await withTaskGroup(of: (Int, GIFFrame).self) { group in
            for (i, frame) in frames.enumerated() {
                group.addTask {
                    let processed = await removeBG(from: frame.image)
                    return (i, GIFFrame(image: processed, delay: frame.delay))
                }
            }
            var results = [(Int, GIFFrame)]()
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    @available(macOS 14.0, *)
    private static func removeBG(from image: NSImage) async -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
            guard let obs = request.results?.first else { return image }
            let pixelBuffer = try obs.generateMaskedImage(
                ofInstances: obs.allInstances, from: handler, croppedToInstancesExtent: false
            )
            let ci = CIImage(cvPixelBuffer: pixelBuffer)
            let ctx = CIContext()
            guard let out = ctx.createCGImage(ci, from: ci.extent) else { return image }
            return NSImage(cgImage: out, size: image.size)
        } catch {
            return image
        }
    }
}
