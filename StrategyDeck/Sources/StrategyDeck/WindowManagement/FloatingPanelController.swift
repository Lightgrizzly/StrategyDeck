import AppKit
import SwiftUI
import StrategyDeckCore

/// Creates, owns, and drives the single floating NSPanel.
///
/// Separate from the AppDelegate so window management stays cohesive and is
/// independently editable.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let environment: AppEnvironment

    @objc dynamic var isPinned: Bool = false {
        didSet {
            updateLevel()
            PanelFrameStore.save(pinned: isPinned)
        }
    }

    init(environment: AppEnvironment) {
        self.environment = environment

        let frame = PanelFrameStore.savedFrame() ?? PanelFrameStore.defaultFrame()

        panel = FloatingPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        super.init()

        isPinned = PanelFrameStore.savedPinned()
        updateLevel()
        panel.delegate = self

        installContent()
    }

    // MARK: - Public interface

    func show() {
        panel.orderFront(nil)
        panel.makeKey()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func setPin(_ pinned: Bool) {
        isPinned = pinned
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_ notification: Notification) {
        PanelFrameStore.save(frame: panel.frame)
    }

    func windowDidMove(_ notification: Notification) {
        PanelFrameStore.save(frame: panel.frame)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    // MARK: - Private

    private func updateLevel() {
        panel.level = isPinned ? .floating : .normal
    }

    private func installContent() {
        let root = PanelRootView(panelController: self)
            .environmentObject(environment)
            .environmentObject(environment.cardStore)
            .environmentObject(environment.sequenceStore)
            .environmentObject(environment.duelStore)
        panel.contentView = NSHostingView(rootView: root)
    }
}
