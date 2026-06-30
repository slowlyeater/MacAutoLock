import AppKit
import SwiftUI

@main
struct MacAutoLockMacApp: App {
    @NSApplicationDelegateAdaptor(MacStatusItemController.self) private var statusItemController

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class MacStatusItemController: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = MacAppModel()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()

        Task { @MainActor in
            model.start()
        }
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Mac AutoLock")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Mac AutoLock"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 520, height: 720)
        popover.contentViewController = NSHostingController(
            rootView: MacMenuView()
                .environmentObject(model)
                .frame(width: 520, height: 720)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
