import SwiftUI
import StrategyDeckCore

/// Collapsible Deck → Suit → Sub-suit tree for library navigation.
/// Selecting a deck row shows all its cards; selecting a suit row scopes to
/// that suit and every sub-suit nested underneath it.
struct DeckSuitTreeView: View {
    let decks: [KnowledgeDeck]
    let suits: [CardSuit]
    @Binding var selectedDeckID: String?
    @Binding var selectedSuiteID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(decks.sorted { $0.displayOrder < $1.displayOrder }) { deck in
                    DeckRow(
                        deck: deck,
                        suits: suits,
                        selectedDeckID: $selectedDeckID,
                        selectedSuiteID: $selectedSuiteID
                    )
                }
            }
            .padding(6)
        }
        .background(.bar)
    }
}

private struct DeckRow: View {
    let deck: KnowledgeDeck
    let suits: [CardSuit]
    @Binding var selectedDeckID: String?
    @Binding var selectedSuiteID: String?

    @State private var isExpanded = true

    private var rootSuits: [CardSuit] { suits.rootSuits(deckID: deck.id) }
    private var isSelected: Bool { selectedDeckID == deck.id && selectedSuiteID == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                selectedDeckID = deck.id
                selectedSuiteID = nil
            } label: {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: deck.iconName)
                        .font(.system(size: 10, weight: .semibold))
                    Text(deck.name)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(rootSuits) { suit in
                    SuitRow(
                        suit: suit,
                        allSuits: suits,
                        deckID: deck.id,
                        selectedDeckID: $selectedDeckID,
                        selectedSuiteID: $selectedSuiteID,
                        depth: 1
                    )
                }
            }
        }
    }
}

private struct SuitRow: View {
    let suit: CardSuit
    let allSuits: [CardSuit]
    /// The deck this suit (and all its descendants) belongs to — set on
    /// selection alongside `selectedSuiteID` so selecting a sub-suit doesn't
    /// leave a stale `selectedDeckID` from whatever was selected before,
    /// which would otherwise AND against the wrong deck in `CardFilter`.
    let deckID: String
    @Binding var selectedDeckID: String?
    @Binding var selectedSuiteID: String?
    let depth: Int

    @State private var isExpanded = true

    private var children: [CardSuit] { allSuits.children(of: suit.id) }
    private var isSelected: Bool { selectedSuiteID == suit.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                selectedDeckID = deckID
                selectedSuiteID = suit.id
            } label: {
                HStack(spacing: 4) {
                    if !children.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .frame(width: 10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer().frame(width: 10)
                    }
                    Image(systemName: suit.iconName)
                        .font(.system(size: 9))
                    Text(suit.name)
                        .font(.system(size: 10.5))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.vertical, 2.5)
                .padding(.leading, CGFloat(depth) * 12)
                .padding(.trailing, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(children) { child in
                    SuitRow(
                        suit: child,
                        allSuits: allSuits,
                        deckID: deckID,
                        selectedDeckID: $selectedDeckID,
                        selectedSuiteID: $selectedSuiteID,
                        depth: depth + 1
                    )
                }
            }
        }
    }
}
