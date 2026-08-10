import AppKit
import SwiftUI
import StrategyDeckCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // This must exist before StrategyDeckApp.body is evaluated.
    let environment = AppEnvironment()

    private var panelController: FloatingPanelController?
    private var shortcutManager: GlobalShortcutManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show the app in the Dock and Cmd+Tab switcher, with a custom icon.
        NSApplication.shared.setActivationPolicy(.regular)
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }

        // The environment already exists, so only boot it here.
        environment.boot()

        // Create and show the floating panel.
        let controller = FloatingPanelController(environment: environment)
        panelController = controller
        controller.show()

        // Register the global hotkey.
        let manager = GlobalShortcutManager()

        manager.onActivate = { [weak self] in
            Task { @MainActor in
                self?.panelController?.toggle()
            }
        }

        shortcutManager = manager
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        panelController?.show()
        return true
    }
}