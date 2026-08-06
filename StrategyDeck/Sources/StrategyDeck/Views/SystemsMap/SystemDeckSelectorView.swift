import SwiftUI
import StrategyDeckCore

/// The deck picker for a Systems Map. Shows every deck plus "All Cards,"
/// with status counts computed only while this sheet is open (not on every
/// frame) — see `SystemDeckSelectorSheet.counts(for:)`. Deck management
/// (create/rename/duplicate/delete/edit-suits) all routes through the
/// application's existing `CardStore` deck API; this view owns no deck data
/// of its own.
struct SystemDeckSelectorSheet: View {
    let decks: [KnowledgeDeck]
    let allCards: [KnowledgeCard]
    let map: SystemMap
    let scenario: SystemScenario
    let selectedTargetKind: SystemTargetKind?
    let selectedElementID: UUID?
    let currentDeckID: String?
    let onSelectDeck: (String?) -> Void
    let onCreateDeck: (String) -> Void
    let onRenameDeck: (String, String) -> Void
    let onDuplicateDeck: (String) -> Void
    let onDeleteDeck: (String) -> Void
    let onEditDeck: (String) -> Void
    let onDropCardOntoDeck: (UUID, String) -> Void
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var newDeckName = ""
    @State private var renamingDeckID: String?
    @State private var renameText = ""
    @State private var alertState: AlertState?

    private var filteredDecks: [KnowledgeDeck] {
        let sorted = decks.sorted { $0.displayOrder < $1.displayOrder }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private struct DeckCounts {
        let total: Int
        let available: Int
        let active: Int
        let locked: Int
    }

    private func counts(for deckID: String?) -> DeckCounts {
        let inDeck = deckID == nil ? allCards : allCards.filter { $0.deckIDs.contains(deckID!) }
        let evaluations = SystemMapEvaluator.evaluateAll(
            cards: inDeck, map: map, scenario: scenario,
            selectedTargetKind: selectedTargetKind, selectedElementID: selectedElementID
        )
        let available = evaluations.filter { $0.effectiveStatus == .available || $0.effectiveStatus == .recommended }.count
        let active = evaluations.filter { $0.effectiveStatus == .active }.count
        let locked = evaluations.filter { $0.effectiveStatus == .locked }.count
        return DeckCounts(total: inDeck.count, available: available, active: active, locked: locked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CHOOSE DECK").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1.5)
                Spacer()
                Button("Done") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(AC.textDim)
                TextField("Search decks…", text: $searchText)
                    .font(.system(size: 11)).textFieldStyle(.plain).foregroundStyle(AC.text)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 5).fill(AC.surfaceHi))
            .padding(12)

            ScrollView {
                VStack(spacing: 6) {
                    deckRow(title: "All Cards", subtitle: "Every card in the library", deckID: nil, iconName: "square.stack.3d.up.fill")

                    ForEach(filteredDecks) { deck in
                        deckRow(title: deck.name, subtitle: deck.description, deckID: deck.id, iconName: deck.iconName)
                            .contextMenu {
                                Button("Rename") { renamingDeckID = deck.id; renameText = deck.name }
                                Button("Duplicate") { onDuplicateDeck(deck.id) }
                                Button("Edit Suits…") { onEditDeck(deck.id) }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    alertState = .destructive(
                                        title: "Delete “\(deck.name)”?",
                                        message: "This removes the deck, its suits, and any cards that exist only in this deck's suits. Cards that also belong to other suits are kept.",
                                        confirmLabel: "Delete"
                                    ) { onDeleteDeck(deck.id) }
                                }
                            }
                    }
                }
                .padding(.horizontal, 12)

                HStack(spacing: 6) {
                    TextField("New deck name…", text: $newDeckName).arenaFieldStyle()
                    Button("Create") {
                        let trimmed = newDeckName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onCreateDeck(trimmed)
                        newDeckName = ""
                    }
                    .buttonStyle(ArenaButtonStyle(isDisabled: newDeckName.trimmingCharacters(in: .whitespaces).isEmpty))
                    .disabled(newDeckName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
            }
        }
        .frame(minWidth: 420, minHeight: 420)
        .background(AC.bg)
        .colorScheme(.dark)
        .alertState($alertState)
        .sheet(item: Binding(
            get: { renamingDeckID.map { RenameDeckTarget(id: $0) } },
            set: { renamingDeckID = $0?.id }
        )) { target in
            VStack(alignment: .leading, spacing: 16) {
                Text("RENAME DECK").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
                TextField("Name", text: $renameText).arenaFieldStyle()
                HStack {
                    Button("Cancel") { renamingDeckID = nil }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save") {
                        onRenameDeck(target.id, renameText)
                        renamingDeckID = nil
                    }
                    .buttonStyle(ArenaButtonStyle(isDisabled: renameText.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .background(AC.bg)
            .colorScheme(.dark)
            .frame(minWidth: 320, minHeight: 140)
        }
    }

    private struct RenameDeckTarget: Identifiable { let id: String }

    @ViewBuilder
    private func deckRow(title: String, subtitle: String, deckID: String?, iconName: String) -> some View {
        let isSelected = currentDeckID == deckID
        let c = counts(for: deckID)
        Button(action: { onSelectDeck(deckID); isPresented = false }) {
            HStack(spacing: 10) {
                Image(systemName: iconName).font(.system(size: 14)).foregroundStyle(isSelected ? AC.cyan : AC.textSub).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(AC.text)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(AC.cyan)
                        }
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 10)).foregroundStyle(AC.textDim).lineLimit(1)
                    }
                    Text("\(c.total) cards • \(c.available) available • \(c.active) active • \(c.locked) locked")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AC.textSub)
                }
                Spacer()
            }
            .padding(10)
            .background(AngularCardShape(cornerRadius: 8, cornerCut: 12).fill(isSelected ? AC.cyanSoft : AC.surface))
            .overlay(AngularCardShape(cornerRadius: 8, cornerCut: 12).stroke(isSelected ? AC.cyan.opacity(0.6) : AC.borderDim, lineWidth: isSelected ? 1.25 : 0.75))
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let deckID else { return false }
            var accepted = false
            for item in items {
                if let cardID = UUID(uuidString: item) {
                    onDropCardOntoDeck(cardID, deckID)
                    accepted = true
                }
            }
            return accepted
        }
    }
}
