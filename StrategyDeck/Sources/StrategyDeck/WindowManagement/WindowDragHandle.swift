import SwiftUI
import AppKit

/// An invisible view that lets the user move the window by clicking and
/// dragging wherever this is placed, without relying on
/// `NSWindow.isMovableByWindowBackground` (which claims mouse-down over the
/// *entire* window content and races with SwiftUI drag-and-drop gestures
/// like `.draggable`). Attach as a `.background()` to a specific header/tab
/// region instead.
struct WindowDragHandle: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}
}
