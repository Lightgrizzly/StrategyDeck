import SwiftUI

@main
struct StrategyDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // MenuBarExtra is the primary UI access point.
        // The floating panel is created by AppDelegate.
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appDelegate.environment)
        } label: {
            Image(systemName: "square.stack.3d.up")
        }
        .menuBarExtraStyle(.window)
    }
}
