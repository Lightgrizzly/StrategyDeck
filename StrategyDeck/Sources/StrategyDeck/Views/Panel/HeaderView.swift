import SwiftUI
import StrategyDeckCore

struct HeaderView: View {
    @Binding var searchText: String
    @Binding var favoritesOnly: Bool
    let isPinned: Bool
    @Binding var isSidebarVisible: Bool
    let selectedDeckID: String?
    let cardGridProxy: CardGridViewProxy
    let onTogglePin: () -> Void
    let onShowSettings: () -> Void
    let onResetSeed: () -> Void

    @EnvironmentObject var cardStore: CardStore
    @State private var showingQuickCreate = false
    @State private var showingBulkAdd = false

    private var currentDeckSuits: [CardSuit] {
        guard let selectedDeckID else { return cardStore.suits }
        return cardStore.suits.filter { $0.deckID == selectedDeckID }
    }

    private var existingTitlesInDeck: [String] {
        let inDeck = selectedDeckID.map { id in cardStore.cards.filter { $0.deckIDs.contains(id) } } ?? cardStore.cards
        return inDeck.map(\.title)
    }

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

                Button(action: { showingQuickCreate = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textSub)
                .help("Quick add card")
                .popover(isPresented: $showingQuickCreate, arrowEdge: .bottom) {
                    QuickCreateCardPopover(
                        suits: currentDeckSuits,
                        onCreate: { title, suitID, description in
                            cardStore.quickCreateCard(title: title, deckID: selectedDeckID, suitID: suitID, shortDescription: description)
                        },
                        onCreateAndEdit: { title, suitID, description in
                            let created = cardStore.quickCreateCard(title: title, deckID: selectedDeckID, suitID: suitID, shortDescription: description)
                            showingQuickCreate = false
                            cardGridProxy.presentEditCard?(created)
                        },
                        onCreateSuite: selectedDeckID.map { deckID in
                            { name in cardStore.createSuit(deckID: deckID, name: name) }
                        },
                        onOpenBlankFullEditor: {
                            showingQuickCreate = false
                            cardGridProxy.presentCreate?()
                        },
                        onClose: { showingQuickCreate = false }
                    )
                }

                Button(action: { showingBulkAdd = true }) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textSub)
                .help("Bulk add cards")
                .sheet(isPresented: $showingBulkAdd) {
                    BulkAddCardsSheet(
                        suits: currentDeckSuits,
                        existingTitles: existingTitlesInDeck,
                        onCommit: { entries in
                            cardStore.bulkCreateCards(entries, deckID: selectedDeckID)
                        },
                        onDone: { showingBulkAdd = false }
                    )
                }

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
