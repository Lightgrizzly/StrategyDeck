import SwiftUI
import StrategyDeckCore

/// A fast, keyboard-driven way to find and act on a card for the selected
/// element — triggered by pressing Space while an element is selected.
/// Every action here is already available without the keyboard (context
/// menus, the Contextual Hand, drag-and-drop); this is a faster path to
/// the same actions, not a new capability.
struct NodeCommandPaletteView: View {
    let selectionLabel: String
    let cards: [KnowledgeCard]
    let evaluationByID: [UUID: SystemCardEvaluation]
    let statusCatalog: StatusCatalog
    let suits: [CardSuit]
    let onViewDetails: (KnowledgeCard) -> Void
    let onChangeStatus: (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void
    let onApplyIntervention: (KnowledgeCard) -> Void
    let onTogglePin: (KnowledgeCard) -> Void
    let onAssignToSelectedElement: (KnowledgeCard) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var statusFilter: SystemCardStatus?
    @State private var selectedSuitID: String?
    @State private var highlightedIndex = 0
    @FocusState private var searchFocused: Bool

    private var usedSuits: [CardSuit] {
        let usedIDs = Set(cards.flatMap(\.suitIDs))
        return suits.filter { usedIDs.contains($0.id) }
    }

    /// Simple, transparent fuzzy match: every character of the query must
    /// appear in order somewhere in the title — no scoring model to explain.
    private func fuzzyMatches(_ title: String, _ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        var titleChars = title.lowercased()[...]
        for ch in query.lowercased() {
            guard let range = titleChars.range(of: String(ch)) else { return false }
            titleChars = titleChars[range.upperBound...]
        }
        return true
    }

    private var results: [KnowledgeCard] {
        cards.filter { card in
            if !fuzzyMatches(card.title, query) { return false }
            if let statusFilter, evaluationByID[card.id]?.effectiveStatus != statusFilter { return false }
            if let selectedSuitID, !card.suitIDs.contains(selectedSuitID) { return false }
            return true
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(AC.cyan)
                Text("Apply a card to \(selectionLabel)…").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(0.5)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(AC.textDim).keyboardShortcut(.escape)
            }
            .padding(.horizontal, 12).padding(.top, 10)

            TextField("Search…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(AC.surfaceHi))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .focused($searchFocused)
                .onChange(of: query) { _, _ in highlightedIndex = 0 }
                .onKeyPress(.downArrow) { highlightedIndex = min(highlightedIndex + 1, max(results.count - 1, 0)); return .handled }
                .onKeyPress(.upArrow) { highlightedIndex = max(highlightedIndex - 1, 0); return .handled }
                .onKeyPress(.return) {
                    if let card = results[safe: highlightedIndex] { onAssignToSelectedElement(card) }
                    return .handled
                }

            HStack(spacing: 6) {
                Picker("Status", selection: $statusFilter) {
                    Text("All Statuses").tag(SystemCardStatus?.none)
                    ForEach(SystemCardStatus.allCases, id: \.self) { s in
                        Text(statusCatalog.labelOverrides[s.rawValue] ?? s.displayName).tag(Optional(s))
                    }
                }
                .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                Picker("Suite", selection: $selectedSuitID) {
                    Text("All Suites").tag(String?.none)
                    ForEach(usedSuits) { s in Text(s.name).tag(Optional(s.id)) }
                }
                .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                Spacer()
                Text("↑↓ navigate · ⏎ assign · esc close").font(.system(size: 8)).foregroundStyle(AC.textGhost)
            }
            .padding(.horizontal, 12).padding(.bottom, 6)

            Rectangle().fill(AC.borderDim).frame(height: 1)

            if results.isEmpty {
                Text("No cards match.").font(.system(size: 11)).foregroundStyle(AC.textSub).padding(14)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, card in
                            paletteRow(card, isHighlighted: index == highlightedIndex)
                                .onTapGesture { onAssignToSelectedElement(card) }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 460)
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear { searchFocused = true }
    }

    private func paletteRow(_ card: KnowledgeCard, isHighlighted: Bool) -> some View {
        let evaluation = evaluationByID[card.id]
        let display = evaluation?.displayInfo(catalog: statusCatalog) ?? StatusDisplayInfo(
            name: SystemCardStatus.available.displayName, icon: SystemCardStatus.available.systemImage, color: SystemCardStatus.available.arenaColor
        )
        return HStack(spacing: 8) {
            Image(systemName: display.icon).font(.system(size: 10)).foregroundStyle(display.color)
            Text(card.title).font(.system(size: 12, weight: .medium)).foregroundStyle(AC.text)
            Spacer()
            Text(display.name.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(display.color)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 5).fill(isHighlighted ? AC.cyanSoft : Color.clear))
        .contextMenu {
            Button("View Details") { onViewDetails(card) }
            if evaluation?.isPlayable == true {
                Button("Apply Intervention") { onApplyIntervention(card) }
            }
            Button("Pin to Contextual Hand") { onTogglePin(card) }
            Button("Assign to Selected Element") { onAssignToSelectedElement(card) }
            Menu("Change Status") {
                ForEach(SystemCardStatus.allCases, id: \.self) { s in
                    Button(s.displayName) { onChangeStatus(card, s, nil, .thisElementOnly) }
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
