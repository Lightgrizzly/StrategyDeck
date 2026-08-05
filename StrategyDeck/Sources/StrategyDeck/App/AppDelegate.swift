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
        // Remove the app from the Dock.
        NSApplication.shared.setActivationPolicy(.accessory)

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