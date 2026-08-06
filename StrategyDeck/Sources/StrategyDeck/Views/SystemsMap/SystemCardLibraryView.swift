import SwiftUI
import StrategyDeckCore

/// The complete card library, always shown in full beneath the diagram —
/// every card, grouped by its dynamically computed ``SystemCardStatus``, so
/// the user can see the whole action vocabulary and understand why each
/// card is or isn't available right now. Filterable by suite and by status
/// together; selecting a suite never changes the underlying evaluations.
struct SystemCardLibraryView: View {
    let cards: [KnowledgeCard]
    let suits: [CardSuit]
    /// Suits scoped to the currently selected deck — used for Quick Add /
    /// Bulk Add's suite pickers (`suits` above is the global list, used
    /// only for the suite filter chips).
    let deckSuits: [CardSuit]
    let evaluations: [SystemCardEvaluation]
    let selectionLabel: String
    let isEditable: Bool
    let onViewDetails: (KnowledgeCard) -> Void
    let onEditCard: ((KnowledgeCard) -> Void)?
    let onApplyIntervention: (KnowledgeCard) -> Void
    let onChangeStatus: (KnowledgeCard, SystemCardStatus, SystemOverrideScope) -> Void
    let onResetToAutomatic: (KnowledgeCard) -> Void
    let onChooseAnotherDeck: (() -> Void)?
    let onCreateCard: (() -> Void)?
    let onAssignToSelectedElement: ((KnowledgeCard) -> Void)?
    let onDropCardToStatus: ((UUID, SystemCardStatus) -> Void)?
    let onQuickCreateCard: ((String, String?, String) -> Void)?
    let onQuickCreateAndEdit: ((String, String?, String) -> Void)?
    let onCreateSuiteInline: ((String) -> CardSuit)?
    let onBulkCreateCards: (([(title: String, suitID: String?)]) -> Void)?

    init(
        cards: [KnowledgeCard],
        suits: [CardSuit],
        deckSuits: [CardSuit] = [],
        evaluations: [SystemCardEvaluation],
        selectionLabel: String,
        isEditable: Bool,
        onViewDetails: @escaping (KnowledgeCard) -> Void,
        onEditCard: ((KnowledgeCard) -> Void)? = nil,
        onApplyIntervention: @escaping (KnowledgeCard) -> Void,
        onChangeStatus: @escaping (KnowledgeCard, SystemCardStatus, SystemOverrideScope) -> Void,
        onResetToAutomatic: @escaping (KnowledgeCard) -> Void,
        onChooseAnotherDeck: (() -> Void)? = nil,
        onCreateCard: (() -> Void)? = nil,
        onAssignToSelectedElement: ((KnowledgeCard) -> Void)? = nil,
        onDropCardToStatus: ((UUID, SystemCardStatus) -> Void)? = nil,
        onQuickCreateCard: ((String, String?, String) -> Void)? = nil,
        onQuickCreateAndEdit: ((String, String?, String) -> Void)? = nil,
        onCreateSuiteInline: ((String) -> CardSuit)? = nil,
        onBulkCreateCards: (([(title: String, suitID: String?)]) -> Void)? = nil
    ) {
        self.cards = cards
        self.suits = suits
        self.deckSuits = deckSuits
        self.evaluations = evaluations
        self.selectionLabel = selectionLabel
        self.isEditable = isEditable
        self.onViewDetails = onViewDetails
        self.onEditCard = onEditCard
        self.onApplyIntervention = onApplyIntervention
        self.onChangeStatus = onChangeStatus
        self.onResetToAutomatic = onResetToAutomatic
        self.onChooseAnotherDeck = onChooseAnotherDeck
        self.onCreateCard = onCreateCard
        self.onAssignToSelectedElement = onAssignToSelectedElement
        self.onDropCardToStatus = onDropCardToStatus
        self.onQuickCreateCard = onQuickCreateCard
        self.onQuickCreateAndEdit = onQuickCreateAndEdit
        self.onCreateSuiteInline = onCreateSuiteInline
        self.onBulkCreateCards = onBulkCreateCards
    }

    @State private var searchText = ""
    @State private var statusFilter: SystemCardStatus?
    @State private var selectedSuitIDs: Set<String> = []
    @State private var favoritesOnly = false
    @State private var isDropTargetedStatus: SystemCardStatus?
    @State private var showingQuickCreate = false
    @State private var showingBulkAdd = false

    private var evaluationByID: [UUID: SystemCardEvaluation] {
        Dictionary(uniqueKeysWithValues: evaluations.map { ($0.cardID, $0) })
    }

    /// Cards used by suite filter counts and the suite bar — after
    /// search/favorites, but before suite/status filters, so counts stay
    /// stable reference numbers rather than shrinking as filters narrow.
    private var baselineCards: [KnowledgeCard] {
        cards.filter { card in
            if favoritesOnly && !card.isFavorite { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                guard card.searchableText.contains(where: { $0.lowercased().contains(q) }) else { return false }
            }
            return true
        }
    }

    private var usedSuits: [CardSuit] {
        let usedIDs = Set(cards.flatMap(\.suitIDs))
        return suits.filter { usedIDs.contains($0.id) }.sorted { $0.displayOrder < $1.displayOrder }
    }

    private var filteredCards: [KnowledgeCard] {
        baselineCards.filter { card in
            if !selectedSuitIDs.isEmpty && !card.suitIDs.contains(where: { selectedSuitIDs.contains($0) }) { return false }
            if let statusFilter, evaluationByID[card.id]?.effectiveStatus != statusFilter { return false }
            return true
        }
    }

    private var groupedCards: [(status: SystemCardStatus, title: String, cards: [KnowledgeCard])] {
        let groups = Dictionary(grouping: filteredCards) { evaluationByID[$0.id]?.effectiveStatus ?? .available }
        return SystemCardStatus.allCases
            .sorted { $0.groupRank < $1.groupRank }
            .reduce(into: [(SystemCardStatus, String, [KnowledgeCard])]()) { acc, status in
                guard let inGroup = groups[status], !inGroup.isEmpty else { return }
                // Avoid duplicate group headers for statuses sharing a groupRank/title.
                if let lastIdx = acc.indices.last, acc[lastIdx].1 == status.groupTitle {
                    acc[lastIdx].2.append(contentsOf: inGroup)
                } else {
                    acc.append((status, status.groupTitle, inGroup))
                }
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(AC.borderDim).frame(height: 1)
            suiteBar
            Rectangle().fill(AC.borderDim).frame(height: 1)

            if cards.isEmpty {
                emptyDeckState
            } else if filteredCards.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.badge.magnifyingglass").font(.system(size: 22)).foregroundStyle(AC.textGhost)
                    Text("No cards match the current filters.").font(.system(size: 11)).foregroundStyle(AC.textSub)
                    Button("Reset Filters", action: resetFilters)
                        .buttonStyle(ArenaOutlineButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedCards, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    ArenaSectionLabel(text: "\(group.title) (\(group.cards.count))", color: group.status.arenaColor)
                                    if isDropTargetedStatus == group.status {
                                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 9)).foregroundStyle(group.status.arenaColor)
                                    }
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 8)], spacing: 8) {
                                    ForEach(group.cards) { card in
                                        SystemLibraryCardView(
                                            card: card,
                                            suite: suits.first(where: { card.suitIDs.contains($0.id) }),
                                            evaluation: evaluationByID[card.id],
                                            isEditable: isEditable,
                                            selectionLabel: selectionLabel,
                                            onViewDetails: { onViewDetails(card) },
                                            onEdit: onEditCard.map { edit in { edit(card) } },
                                            onApplyIntervention: { onApplyIntervention(card) },
                                            onChangeStatus: { onChangeStatus(card, $0, $1) },
                                            onResetToAutomatic: { onResetToAutomatic(card) },
                                            onAssignToSelectedElement: onAssignToSelectedElement.map { assign in { assign(card) } }
                                        )
                                    }
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isDropTargetedStatus == group.status ? group.status.arenaColor.opacity(0.12) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isDropTargetedStatus == group.status ? group.status.arenaColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
                                )
                                .dropDestination(for: String.self, action: { items, _ in
                                    guard let onDropCardToStatus else { return false }
                                    var accepted = false
                                    for item in items {
                                        if let cardID = UUID(uuidString: item) {
                                            onDropCardToStatus(cardID, group.status)
                                            accepted = true
                                        }
                                    }
                                    return accepted
                                }, isTargeted: { targeted in
                                    isDropTargetedStatus = targeted ? group.status : (isDropTargetedStatus == group.status ? nil : isDropTargetedStatus)
                                })
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(AC.bg)
        .onChange(of: usedSuits.map(\.id)) { _, newIDs in
            // A deck change may drop the suit the user had selected — keep
            // whichever selected suits still exist in the new deck, or fall
            // back to "All Suites" if none of them do.
            let stillValid = selectedSuitIDs.intersection(Set(newIDs))
            if stillValid != selectedSuitIDs { selectedSuitIDs = stillValid }
        }
    }

    private var emptyDeckState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(AC.textGhost)
            Text("This deck does not contain any cards yet.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AC.textSub)
            HStack(spacing: 8) {
                if let onCreateCard {
                    Button("Create Card", action: onCreateCard).buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                }
                if let onChooseAnotherDeck {
                    Button("Choose Another Deck", action: onChooseAnotherDeck).buttonStyle(ArenaOutlineButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private func resetFilters() {
        searchText = ""
        statusFilter = nil
        selectedSuitIDs = []
        favoritesOnly = false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ArenaSectionLabel(text: "Card Library — \(selectionLabel)", icon: "square.stack.3d.up")
                Spacer()
                if onQuickCreateCard != nil {
                    Button(action: { showingQuickCreate = true }) {
                        Label("QUICK ADD", systemImage: "plus")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                    .popover(isPresented: $showingQuickCreate, arrowEdge: .bottom) {
                        QuickCreateCardPopover(
                            suits: deckSuits,
                            initialSuitID: selectedSuitIDs.count == 1 ? selectedSuitIDs.first : nil,
                            onCreate: { title, suitID, description in
                                onQuickCreateCard?(title, suitID, description)
                            },
                            onCreateAndEdit: { title, suitID, description in
                                showingQuickCreate = false
                                onQuickCreateAndEdit?(title, suitID, description)
                            },
                            onCreateSuite: onCreateSuiteInline,
                            onOpenBlankFullEditor: {
                                showingQuickCreate = false
                                onCreateCard?()
                            },
                            onClose: { showingQuickCreate = false }
                        )
                    }
                }
                if onBulkCreateCards != nil {
                    Button(action: { showingBulkAdd = true }) {
                        Image(systemName: "list.bullet.clipboard")
                    }
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .help("Bulk add cards")
                    .sheet(isPresented: $showingBulkAdd) {
                        BulkAddCardsSheet(
                            suits: deckSuits,
                            existingTitles: cards.map(\.title),
                            initialSuitID: selectedSuitIDs.count == 1 ? selectedSuitIDs.first : nil,
                            onCommit: { entries in onBulkCreateCards?(entries) },
                            onDone: { showingBulkAdd = false }
                        )
                    }
                }
                Text("\(filteredCards.count) / \(cards.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(AC.textDim)
            }
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(AC.textDim)
                    TextField("Search cards…", text: $searchText)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                        .foregroundStyle(AC.text)
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(AC.surface))

                Toggle("★", isOn: $favoritesOnly).toggleStyle(.button).font(.system(size: 10)).tint(AC.gold)

                Picker("Status", selection: $statusFilter) {
                    Text("All Statuses").tag(SystemCardStatus?.none)
                    ForEach(SystemCardStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(Optional(status))
                    }
                }
                .pickerStyle(.menu)
                .tint(AC.cyan)
                .frame(width: 140)

                if !searchText.isEmpty || statusFilter != nil || !selectedSuitIDs.isEmpty || favoritesOnly {
                    Button("Reset", action: resetFilters)
                        .buttonStyle(ArenaOutlineButtonStyle())
                }
            }
        }
        .padding(10)
        .background(AC.surface)
    }

    private var suiteBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                SuiteFilterChip(
                    title: "All Suites",
                    subtitle: "\(baselineCards.count) cards",
                    isSelected: selectedSuitIDs.isEmpty,
                    color: AC.cyan
                ) {
                    selectedSuitIDs = []
                }
                ForEach(usedSuits) { suit in
                    let summary = suiteSummary(suit)
                    SuiteFilterChip(
                        title: suit.name,
                        subtitle: "\(summary.total) cards • \(summary.available) available • \(summary.active) active",
                        isSelected: selectedSuitIDs.contains(suit.id),
                        color: SuiteColors.color(for: suit.id)
                    ) {
                        toggleSuit(suit.id)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(AC.surface.opacity(0.6))
    }

    private func toggleSuit(_ id: String) {
        if selectedSuitIDs.contains(id) {
            selectedSuitIDs.remove(id)
        } else {
            selectedSuitIDs.insert(id)
        }
    }

    private func suiteSummary(_ suit: CardSuit) -> (total: Int, available: Int, active: Int, locked: Int, disabled: Int) {
        let inSuite = baselineCards.filter { $0.suitIDs.contains(suit.id) }
        func count(_ statuses: SystemCardStatus...) -> Int {
            inSuite.filter { card in
                guard let status = evaluationByID[card.id]?.effectiveStatus else { return false }
                return statuses.contains(status)
            }.count
        }
        return (
            total: inSuite.count,
            available: count(.available, .recommended),
            active: count(.active),
            locked: count(.locked),
            disabled: count(.disabled)
        )
    }
}

// MARK: - Suite filter chip

private struct SuiteFilterChip: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .kerning(0.5)
                Text(subtitle)
                    .font(.system(size: 8))
            }
            .foregroundStyle(isSelected ? AC.bg : color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                AngularCardShape(cornerRadius: 5, cornerCut: 8)
                    .fill(isSelected ? color : color.opacity(0.12))
            )
            .overlay(
                AngularCardShape(cornerRadius: 5, cornerCut: 8)
                    .stroke(color.opacity(0.5), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - One card in the library

private struct SystemLibraryCardView: View {
    let card: KnowledgeCard
    let suite: CardSuit?
    let evaluation: SystemCardEvaluation?
    let isEditable: Bool
    let selectionLabel: String
    let onViewDetails: () -> Void
    let onEdit: (() -> Void)?
    let onApplyIntervention: () -> Void
    let onChangeStatus: (SystemCardStatus, SystemOverrideScope) -> Void
    let onResetToAutomatic: () -> Void
    let onAssignToSelectedElement: (() -> Void)?

    @State private var showingWhy = false

    private var status: SystemCardStatus { evaluation?.effectiveStatus ?? .available }
    private var kindColor: Color { card.kind.arenaColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let suite { SuiteBadge(suite: suite, size: 14) }
                Text(card.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AC.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                statusMenu
            }

            if let leverage = card.playabilityRules.leverageLevel {
                Text(leverage.displayName.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(0.5)
            }

            Button(action: { withAnimation(.easeInOut(duration: 0.12)) { showingWhy.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: showingWhy ? "chevron.down" : "chevron.right").font(.system(size: 7))
                    Text("Why?").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(AC.textDim)
            }
            .buttonStyle(.plain)

            if showingWhy, let evaluation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUTOMATIC: \(evaluation.automaticStatus.displayName.uppercased())")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(evaluation.automaticStatus.arenaColor.opacity(0.85))
                    Text(evaluation.automaticExplanation)
                        .font(.system(size: 9))
                        .foregroundStyle(AC.textSub)
                        .fixedSize(horizontal: false, vertical: true)
                    if evaluation.isOverridden {
                        Text("OVERRIDE (\(evaluation.overrideScope?.displayName.uppercased() ?? "")): \(evaluation.effectiveStatus.displayName.uppercased())")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.cyan)
                        if let reason = evaluation.overrideReason, !reason.isEmpty {
                            Text(reason)
                                .font(.system(size: 9))
                                .italic()
                                .foregroundStyle(AC.textSub)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Button("Details", action: onViewDetails)
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.borderDim))
                if isEditable, let onEdit {
                    Button("Edit", action: onEdit)
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.borderDim))
                }
                if isEditable, evaluation?.isPlayable == true {
                    Button(status == .recommended ? "APPLY (RECOMMENDED)" : "APPLY") {
                        onApplyIntervention()
                    }
                    .buttonStyle(ArenaButtonStyle(color: status == .recommended ? AC.gold : kindColor))
                }
            }
        }
        .padding(9)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(status == .irrelevant ? AC.surface.opacity(0.4) : AC.surface)
        )
        .overlay(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .stroke(status.arenaColor.opacity(0.5), lineWidth: 1)
        )
        .opacity(status == .irrelevant ? 0.55 : 1.0)
        .draggable(card.id.uuidString) {
            // Compact drag preview: title, suite initials, effective status.
            HStack(spacing: 5) {
                if let suite { SuiteBadge(suite: suite, size: 14) }
                Text(card.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.text)
                Text(status.displayName.uppercased()).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(status.arenaColor)
            }
            .padding(8)
            .background(AngularCardShape(cornerRadius: 6, cornerCut: 9).fill(AC.surfaceHi))
            .colorScheme(.dark)
        }
        .contextMenu {
            if let onAssignToSelectedElement {
                Button("Assign to \(selectionLabel)") { onAssignToSelectedElement() }
                Divider()
            }
            Button("View Details", action: onViewDetails)
            if isEditable, let onEdit {
                Button("Edit", action: onEdit)
            }
            if isEditable, evaluation?.isPlayable == true {
                Button("Apply Intervention", action: onApplyIntervention)
            }
            if evaluation?.isOverridden == true {
                Button("Reset to Automatic", action: onResetToAutomatic)
            }
        }
    }

    @ViewBuilder
    private var statusMenu: some View {
        Menu {
            Section("Change Status — This Element") {
                ForEach(SystemCardStatus.allCases, id: \.self) { s in
                    Button(s.displayName) { onChangeStatus(s, .thisElementOnly) }
                }
            }
            Menu("Change Status — Entire Scenario") {
                ForEach(SystemCardStatus.allCases, id: \.self) { s in
                    Button(s.displayName) { onChangeStatus(s, .entireScenario) }
                }
            }
            Menu("Change Status — Default For Workflow") {
                ForEach(SystemCardStatus.allCases, id: \.self) { s in
                    Button(s.displayName) { onChangeStatus(s, .workflowDefault) }
                }
            }
            if evaluation?.isOverridden == true {
                Divider()
                Button("Reset to Automatic", action: onResetToAutomatic)
            }
            Divider()
            Button("View Details", action: onViewDetails)
        } label: {
            statusBadge
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: status.systemImage).font(.system(size: 8))
            Text(status.displayName.uppercased()).font(.system(size: 7.5, weight: .black, design: .monospaced)).kerning(0.5)
            if evaluation?.isOverridden == true {
                Image(systemName: "hand.raised.fill").font(.system(size: 7))
            }
            Image(systemName: "chevron.down").font(.system(size: 6))
        }
        .foregroundStyle(status.arenaColor)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(status.arenaColor.opacity(0.15)))
    }
}
