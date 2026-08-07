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

    @EnvironmentObject var cardStore: CardStore
    @State private var isEndDropTargeted = false

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

                // Drop here to move a dragged deck to the end of the order.
                Rectangle()
                    .fill(isEndDropTargeted ? AC.goldSoft : Color.clear)
                    .frame(height: 8)
                    .dropDestination(for: String.self, action: { items, _ in
                        guard let draggedDeckID = items.first else { return false }
                        cardStore.moveDeck(id: draggedDeckID, before: nil)
                        return true
                    }, isTargeted: { isEndDropTargeted = $0 })

                Rectangle().fill(AC.borderDim).frame(height: 1).padding(.vertical, 2)

                InlineCreateRow(placeholder: "New deck name…") { name in
                    let newDeck = cardStore.createDeck(name: name)
                    selectedDeckID = newDeck.id
                    selectedSuiteID = nil
                }
            }
            .padding(6)
        }
        .background(AC.surface)
        .colorScheme(.dark)
    }
}

private struct DeckRow: View {
    let deck: KnowledgeDeck
    let suits: [CardSuit]
    @Binding var selectedDeckID: String?
    @Binding var selectedSuiteID: String?

    @EnvironmentObject var cardStore: CardStore
    @State private var isExpanded = false
    @State private var isDropTargeted = false

    private var rootSuits: [CardSuit] { suits.rootSuits(deckID: deck.id) }
    private var isSelected: Bool { selectedDeckID == deck.id && selectedSuiteID == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 10)
                }
                .buttonStyle(.plain)
                Button {
                    selectedDeckID = deck.id
                    selectedSuiteID = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: deck.iconName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(deck.name)
                            .font(.system(size: 11, weight: .semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 8))
                            .foregroundStyle(AC.textGhost)
                    }
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(isSelected ? AC.cyan : AC.text)
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .background(
                AngularCardShape(cornerRadius: 5, cornerCut: 8)
                    .fill(isDropTargeted ? AC.goldSoft : (isSelected ? AC.cyanSoft : Color.clear))
            )
            .overlay(
                AngularCardShape(cornerRadius: 5, cornerCut: 8)
                    .stroke(isDropTargeted ? AC.gold.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .draggable(deck.id)
            .dropDestination(for: String.self, action: { items, _ in
                guard let draggedDeckID = items.first, draggedDeckID != deck.id else { return false }
                cardStore.moveDeck(id: draggedDeckID, before: deck.id)
                return true
            }, isTargeted: { isDropTargeted = $0 })

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
                InlineCreateRow(placeholder: "New suite name…") { name in
                    let newSuit = cardStore.createSuit(deckID: deck.id, name: name)
                    selectedDeckID = deck.id
                    selectedSuiteID = newSuit.id
                }
                .padding(.leading, 12)
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

    @EnvironmentObject var cardStore: CardStore
    @State private var isExpanded = true
    @State private var showingColorPicker = false

    private var children: [CardSuit] { allSuits.children(of: suit.id) }
    private var isSelected: Bool { selectedSuiteID == suit.id }
    private var suiteColor: Color { SuiteColors.color(for: suit) }

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
                    Button(action: { showingColorPicker = true }) {
                        Circle().fill(suiteColor).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(AC.text.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingColorPicker) {
                        SuiteColorPicker(selected: suit.colorToken) { token in
                            cardStore.setSuitColor(id: suit.id, colorToken: token)
                        }
                    }
                }
                .foregroundStyle(isSelected ? AC.cyan : AC.textSub)
                .padding(.vertical, 2.5)
                .padding(.leading, CGFloat(depth) * 12)
                .padding(.trailing, 4)
                .background(
                    AngularCardShape(cornerRadius: 5, cornerCut: 8)
                        .fill(isSelected ? AC.cyanSoft : Color.clear)
                )
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

/// Tap a swatch to pick a suite's accent color; "Default" clears it back to
/// the automatic per-ID color in `SuiteColors`.
private struct SuiteColorPicker: View {
    let selected: StatusColorToken?
    let onPick: (StatusColorToken?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { onPick(nil) }) {
                Circle()
                    .strokeBorder(AC.textDim, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(AC.text, lineWidth: selected == nil ? 1.5 : 0).padding(-2))
            }
            .buttonStyle(.plain)
            .help("Default")

            ForEach(StatusColorToken.allCases, id: \.self) { token in
                Button(action: { onPick(token) }) {
                    Circle()
                        .fill(token.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(AC.text, lineWidth: selected == token ? 1.5 : 0).padding(-2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(AC.bg)
        .colorScheme(.dark)
    }
}
