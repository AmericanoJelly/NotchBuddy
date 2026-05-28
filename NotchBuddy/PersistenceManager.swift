import AppKit

final class PersistenceManager {
    static let shared = PersistenceManager()
    private let defaults = UserDefaults.standard

    private var appSupportURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotchBuddy", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var savedXPosition: CGFloat? {
        guard defaults.object(forKey: "xPos") != nil else { return nil }
        return CGFloat(defaults.double(forKey: "xPos"))
    }

    var savedGIFURL: URL? {
        let dest = appSupportURL.appendingPathComponent("custom.gif")
        return FileManager.default.fileExists(atPath: dest.path) ? dest : nil
    }

    func saveXPosition(_ x: CGFloat) {
        defaults.set(Double(x), forKey: "xPos")
    }

    func saveGIF(from source: URL) {
        let dest = appSupportURL.appendingPathComponent("custom.gif")
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: source, to: dest)
    }

    func clearCustomGIF() {
        let dest = appSupportURL.appendingPathComponent("custom.gif")
        try? FileManager.default.removeItem(at: dest)
    }
}
