import SwiftUI
import AppKit

/// The app's menu bar glyph — a custom template image (so it tints
/// correctly in both light and dark menu bars) instead of a generic SF
/// Symbol placeholder. Falls back to the old symbol if the bundled asset
/// can't be loaded for some reason.
struct MenuBarIconView: View {
    var size: CGFloat = 18

    private static let image: NSImage = {
        if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            return img
        }
        return NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Strategy Deck") ?? NSImage()
    }()

    var body: some View {
        Image(nsImage: Self.image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
