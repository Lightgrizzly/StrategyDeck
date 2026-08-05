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
                        Text("New Deck")
                            .font(.system(size: 10.5, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                
                Divider()
                    .padding(.vertical, 2)
                
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
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add category to this deck")
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

private struct NewDeckDialog: View {
    @Binding var name: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Deck")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Deck Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g., Engineering", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                    name = ""
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create", action: {
                    onCreate()
                    isPresented = false
                })
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 300, minHeight: 140)
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
            Text("Create New Category")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Category Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g., Best Practices", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                    name = ""
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create", action: {
                    onCreate()
                    isPresented = false
                })
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 300, minHeight: 140)
        .onAppear {
            isFocused = true
        }
    }
}

