import AppKit
import Foundation

/// Persists the panel's last frame and pinned state to UserDefaults.
struct PanelFrameStore {
    private enum Key {
        static let frame = "panelFrame"
        static let pinned = "panelPinned"
        static let defaultWidth: CGFloat = 400
        static let defaultHeight: CGFloat = 620
    }

    static func savedFrame() -> NSRect? {
        guard let stored = UserDefaults.standard.string(forKey: Key.frame),
              let rect = NSRectFromString(stored) as NSRect?,
              rect.width >= 1 else { return nil }
        return rect
    }

    static func save(frame: NSRect) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: Key.frame)
    }

    static func savedPinned() -> Bool {
        UserDefaults.standard.bool(forKey: Key.pinned)
    }

    static func save(pinned: Bool) {
        UserDefaults.standard.set(pinned, forKey: Key.pinned)
    }

    /// A sensible default frame centred in the screen.
    static func defaultFrame() -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w = Key.defaultWidth
        let h = Key.defaultHeight
        return NSRect(
            x: screen.maxX - w - 40,
            y: screen.midY - h / 2,
            width: w,
            height: h
        )
    }
}
