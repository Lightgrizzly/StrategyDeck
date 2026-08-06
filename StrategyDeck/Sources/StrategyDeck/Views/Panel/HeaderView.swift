import SwiftUI
import StrategyDeckCore

struct HeaderView: View {
    @Binding var searchText: String
    @Binding var favoritesOnly: Bool
    let isPinned: Bool
    @Binding var isSidebarVisible: Bool
    let onTogglePin: () -> Void
    let onAddCard: () -> Void
    let onShowSettings: () -> Void
    let onResetSeed: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AC.cyan)
                    Text("STRATEGY DECK")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .kerning(1.2)
                }
                .foregroundStyle(AC.text)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isSidebarVisible.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSidebarVisible ? AC.cyan : AC.textDim)
                .help(isSidebarVisible ? "Hide library sidebar" : "Show library sidebar")

                Button(action: onAddCard) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textSub)
                .help("New card")

                Toggle(isOn: Binding(get: { isPinned }, set: { _ in onTogglePin() })) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(isPinned ? AC.cyan : AC.textDim)
                .help(isPinned ? "Unpin panel" : "Pin panel on top")

                Menu {
                    Toggle("Show Favorites Only", isOn: $favoritesOnly)
                    Divider()
                    Button("Settings…", action: onShowSettings)
                    Divider()
                    Button("Reset to Default Cards…", action: onResetSeed)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(AC.textDim)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(AC.textDim)
                TextField("Search cards…", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(AC.text)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AC.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                AngularCardShape(cornerRadius: 6, cornerCut: 9)
                    .fill(AC.surface)
                    .overlay(AngularCardShape(cornerRadius: 6, cornerCut: 9).stroke(AC.borderDim, lineWidth: 0.75))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .background(AC.surface)
        .colorScheme(.dark)
    }
}
