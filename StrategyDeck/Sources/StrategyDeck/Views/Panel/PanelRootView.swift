import SwiftUI
import StrategyDeckCore

/// The root content view hosted inside the floating NSPanel.
struct PanelRootView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var sequenceStore: SequenceStore

    // Reference back to the controller so the header can toggle pin.
    let panelController: FloatingPanelController

    @State private var searchText = ""
    @State private var selectedDeckID: String?
    @State private var selectedSuiteID: String?
    @State private var favoritesOnly = false
    @State private var isSidebarVisible = true
    @State private var showingSettings = false
    @State private var alertState: AlertState?
    @State private var cardGridRef = CardGridViewProxy()

    private var filter: CardFilter {
        CardFilter(query: searchText, deckID: selectedDeckID, suitID: selectedSuiteID, favoritesOnly: favoritesOnly)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                searchText: $searchText,
                favoritesOnly: $favoritesOnly,
                isPinned: panelController.isPinned,
                isSidebarVisible: $isSidebarVisible,
                onTogglePin: { panelController.setPin(!panelController.isPinned) },
                onAddCard: { cardGridRef.presentCreate?() },
                onShowSettings: { showingSettings = true },
                onResetSeed: {
                    alertState = .destructive(
                        title: "Reset to Default Cards?",
                        message: "Your custom cards will be permanently replaced with the built-in defaults. Saved sequences are not affected.",
                        confirmLabel: "Reset"
                    ) { cardStore.resetToSeed() }
                }
            )

            Divider()

            HStack(spacing: 0) {
                if isSidebarVisible {
                    DeckSuitTreeView(
                        decks: cardStore.decks,
                        suits: cardStore.suits,
                        selectedDeckID: $selectedDeckID,
                        selectedSuiteID: $selectedSuiteID
                    )
                    .frame(width: 150)
                    Divider()
                }

                VStack(spacing: 0) {
                    KnowledgeCardGridContainer(filter: filter, suits: cardStore.suits, selectedDeckID: selectedDeckID, proxy: cardGridRef)
                    SequenceTrayView()
                        .environmentObject(sequenceStore)
                        .environmentObject(cardStore)
                }
            }
        }
        .background(Color(.windowBackgroundColor))
        .alertState($alertState)
        .onAppear {
            if selectedDeckID == nil { selectedDeckID = cardStore.decks.first?.id }
        }
        .onChange(of: cardStore.lastError as? NSError) { _, _ in
            if let err = cardStore.lastError { alertState = .error(err) }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(environment)
                .frame(minWidth: 360, minHeight: 420)
        }
    }
}

/// A thin proxy class so HeaderView can trigger card grid actions
/// without creating a circular view dependency.
final class CardGridViewProxy: ObservableObject {
    var presentCreate: (() -> Void)?
}

/// Wrapper that captures the proxy reference and hands it to the grid.
struct KnowledgeCardGridContainer: View {
    let filter: CardFilter
    let suits: [CardSuit]
    let selectedDeckID: String?
    let proxy: CardGridViewProxy

    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var sequenceStore: SequenceStore

    var body: some View {
        InternalGrid(filter: filter, suits: suits, selectedDeckID: selectedDeckID, proxy: proxy)
    }
}

private struct InternalGrid: View {
    let filter: CardFilter
    let suits: [CardSuit]
    let selectedDeckID: String?
    let proxy: CardGridViewProxy

    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var sequenceStore: SequenceStore

    @State private var selectedCardID: UUID?
    @State private var detailCard: KnowledgeCard?
    @State private var editingCard: KnowledgeCard?
    @State private var isCreating = false
    @State private var newCard = InternalGrid.blankCard(suits: [], deckID: nil)
    @State private var alertState: AlertState?
    @State private var pendingDeleteID: UUID?

    private var filteredCards: [KnowledgeCard] {
        filter.apply(to: cardStore.cards, suits: suits)
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 6)]

    var body: some View {
        ScrollView {
            if filteredCards.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(filteredCards) { card in
                        KnowledgeCardView(
                            card: card,
                            suite: primarySuite(for: card),
                            isSelected: selectedCardID == card.id,
                            onTap: { selectedCardID = card.id; detailCard = card },
                            onAddToTray: { sequenceStore.addToTray(cardID: card.id) },
                            onFavorite: { cardStore.toggleFavorite(id: card.id) },
                            onEdit: { selectedCardID = card.id; editingCard = card },
                            onDuplicate: { cardStore.duplicate(card) },
                            onDelete: {
                                pendingDeleteID = card.id
                                alertState = .destructive(
                                    title: "Delete \"\(card.title)\"?",
                                    message: "This card will be permanently removed from your library.",
                                    confirmLabel: "Delete"
                                ) {
                                    if let id = pendingDeleteID { cardStore.delete(id: id) }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .alertState($alertState)
        // Wire the proxy so the header can trigger "new card"
        .onAppear {
            proxy.presentCreate = { presentCreate() }
        }
        // Card detail
        .sheet(item: Binding(get: { detailCard }, set: { detailCard = $0 })) { card in
            KnowledgeCardDetailView(
                card: card,
                suite: primarySuite(for: card),
                allCards: cardStore.cards,
                relationships: cardStore.relationships,
                onEdit: { editingCard = card },
                onAddToTray: { sequenceStore.addToTray(cardID: card.id) },
                onDismiss: { detailCard = nil }
            )
            .frame(minWidth: 340, minHeight: 500)
        }
        // Edit
        .sheet(item: Binding(get: { editingCard }, set: { editingCard = $0 })) { card in
            KnowledgeCardEditorView(
                mode: .edit,
                card: Binding(get: { editingCard ?? card }, set: { editingCard = $0 }),
                suits: allowedSuits(for: card),
                onSave: { updated in cardStore.update(updated); editingCard = nil },
                onCancel: { editingCard = nil }
            )
            .frame(minWidth: 380, minHeight: 500)
        }
        // Create
        .sheet(isPresented: $isCreating) {
            KnowledgeCardEditorView(
                mode: .create,
                card: $newCard,
                suits: allowedSuits(for: newCard),
                onSave: { created in
                    cardStore.add(created)
                    isCreating = false
                    newCard = Self.blankCard(suits: suits, deckID: selectedDeckID)
                },
                onCancel: {
                    isCreating = false
                    newCard = Self.blankCard(suits: suits, deckID: selectedDeckID)
                }
            )
            .frame(minWidth: 380, minHeight: 500)
        }
        // Keyboard navigation
        .focusable()
        .onKeyPress(.space) { inspectSelected(); return .handled }
        .onKeyPress(.return) { inspectSelected(); return .handled }
    }

    // MARK: - Helpers

    private func primarySuite(for card: KnowledgeCard) -> CardSuit? {
        suits.first { card.suitIDs.contains($0.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(filter.query.isEmpty ? "No cards in this suite." : "No cards match \"\(filter.query)\".")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func inspectSelected() {
        guard let id = selectedCardID,
              let card = cardStore.cards.first(where: { $0.id == id }) else { return }
        detailCard = card
    }

    /// Called by the header's add-card button.
    private func presentCreate() {
        newCard = Self.blankCard(suits: suits, deckID: selectedDeckID)
        isCreating = true
    }

    private func allowedSuits(for card: KnowledgeCard) -> [CardSuit] {
        if let deckID = card.deckIDs.first {
            let filteredSuits = suits.filter { $0.deckID == deckID }
            if !filteredSuits.isEmpty { return filteredSuits }
        }
        if let selectedDeck = selectedDeckID {
            let filteredSuits = suits.filter { $0.deckID == selectedDeck }
            if !filteredSuits.isEmpty { return filteredSuits }
        }
        return suits
    }

    private static func blankCard(suits: [CardSuit], deckID: String?) -> KnowledgeCard {
        let filteredSuits = deckID.flatMap { deckID in suits.filter { $0.deckID == deckID } }
        return KnowledgeCard(
            deckIDs: filteredSuits?.first.map { [$0.deckID] } ?? [],
            suitIDs: filteredSuits?.first.map { [$0.id] } ?? [],
            kind: .action,
            metadata: .softwareStrategy(SoftwareStrategyFields()),
            title: ""
        )
    }
}
