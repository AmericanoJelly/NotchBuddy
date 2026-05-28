import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlay: NotchOverlay!
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupOverlay()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "NotchBuddy")

        let menu = NSMenu()
        let changeItem = NSMenuItem(title: "캐릭터 변경", action: #selector(changeCharacter), keyEquivalent: "")
        changeItem.target = self
        menu.addItem(changeItem)
        menu.addItem(.separator())
        let resetItem = NSMenuItem(title: "기본으로 초기화", action: #selector(resetToDefault), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func setupOverlay() {
        overlay = NotchOverlay()
        if let customURL = PersistenceManager.shared.savedGIFURL {
            overlay.loadGIF(from: customURL)
        } else {
            overlay.loadDefaultGIF()
        }
    }

    @objc private func changeCharacter() {
        if popover == nil {
            let vc = DropZoneViewController { [weak self] url in
                self?.popover?.close()
                self?.overlay.loadGIF(from: url)
            }
            let p = NSPopover()
            p.contentViewController = vc
            p.behavior = .transient
            p.contentSize = NSSize(width: 240, height: 170)
            popover = p
        }
        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func resetToDefault() {
        PersistenceManager.shared.clearCustomGIF()
        overlay.loadDefaultGIF()
    }
}
