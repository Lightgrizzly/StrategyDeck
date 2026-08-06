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
    @State private var showingNewDeckDialog = false
    @State private var newDeckName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                // Add Deck Button
                Button(action: { showingNewDeckDialog = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10, weight: .semibold))
                        Text("NEW DECK")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .kerning(0.5)
                        Spacer()
                    }
                    .foregroundStyle(AC.cyan)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(
                        AngularCardShape(cornerRadius: 5, cornerCut: 7)
                            .fill(AC.cyanSoft)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)

                Rectangle().fill(AC.borderDim).frame(height: 1).padding(.vertical, 2)

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
        .background(AC.surface)
        .colorScheme(.dark)
        .sheet(isPresented: $showingNewDeckDialog) {
            NewDeckDialog(
                name: $newDeckName,
                isPresented: $showingNewDeckDialog,
                onCreate: {
                    if !newDeckName.trimmingCharacters(in: .whitespaces).isEmpty {
                        let newDeck = cardStore.createDeck(name: newDeckName)
                        selectedDeckID = newDeck.id
                        selectedSuiteID = nil
                        newDeckName = ""
                    }
                }
            )
        }
    }
}

private struct DeckRow: View {
    let deck: KnowledgeDeck
    let suits: [CardSuit]
    @Binding var selectedDeckID: String?
    @Binding var selectedSuiteID: String?

    @EnvironmentObject var cardStore: CardStore
    @State private var isExpanded = true
    @State private var showingNewSuitDialog = false
    @State private var newSuitName = ""

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

                    // Add category button for this deck
                    Button(action: { showingNewSuitDialog = true }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(AC.textDim)
                    }
                    .buttonStyle(.plain)
                    .help("Add category to this deck")
                }
                .foregroundStyle(isSelected ? AC.cyan : AC.text)
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .background(
                    AngularCardShape(cornerRadius: 5, cornerCut: 8)
                        .fill(isSelected ? AC.cyanSoft : Color.clear)
                )
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
        .sheet(isPresented: $showingNewSuitDialog) {
            NewSuitDialog(
                name: $newSuitName,
                isPresented: $showingNewSuitDialog,
                onCreate: {
                    if !newSuitName.trimmingCharacters(in: .whitespaces).isEmpty {
                        let newSuit = cardStore.createSuit(deckID: deck.id, name: newSuitName)
                        selectedDeckID = deck.id
                        selectedSuiteID = newSuit.id
                        newSuitName = ""
                    }
                }
            )
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

private struct NewDeckDialog: View {
    @Binding var name: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("CREATE NEW DECK")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(AC.cyan)
                .kerning(1.5)

            VStack(alignment: .leading, spacing: 6) {
                Text("DECK NAME")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(1)
                TextField("e.g., Engineering", text: $name)
                    .arenaFieldStyle()
                    .focused($isFocused)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                    name = ""
                }
                .buttonStyle(ArenaOutlineButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create", action: {
                    onCreate()
                    isPresented = false
                })
                .buttonStyle(ArenaButtonStyle(isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty))
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 300, minHeight: 140)
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear {
            isFocused = true
        }
    }
}

private struct NewSuitDialog: View {
    @Binding var name: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("CREATE NEW CATEGORY")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(AC.cyan)
                .kerning(1.5)

            VStack(alignment: .leading, spacing: 6) {
                Text("CATEGORY NAME")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(1)
                TextField("e.g., Best Practices", text: $name)
                    .arenaFieldStyle()
                    .focused($isFocused)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                    name = ""
                }
                .buttonStyle(ArenaOutlineButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create", action: {
                    onCreate()
                    isPresented = false
                })
                .buttonStyle(ArenaButtonStyle(isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty))
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 300, minHeight: 140)
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear {
            isFocused = true
        }
    }
}
