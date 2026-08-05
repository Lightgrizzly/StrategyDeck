import AppKit

/// A custom NSPanel configured as a floating utility panel.
///
/// Key choices:
/// - `.utilityWindow` gives the compact title-bar look.
/// - `hidesOnDeactivate = false` keeps the panel visible when the user
///   switches to another application.
/// - `isFloatingPanel = true` causes it to float above `.normal`-level windows.
/// - We manage the window level ourselves for the pin/unpin feature.
final class FloatingPanel: NSPanel {

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
        configure()
    }

    private func configure() {
        title = "Strategy Deck"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false

        // Float above full-screen apps and across all Spaces.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Allow the content view to extend under the title bar area.
        styleMask.insert(.fullSizeContentView)

        minSize = NSSize(width: 320, height: 400)
        maxSize = NSSize(width: 900, height: 1100)
    }

    /// Panels can become key so text fields work normally.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
