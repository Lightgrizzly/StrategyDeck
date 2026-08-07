import SwiftUI
import StrategyDeckCore

/// How densely the Full Library renders cards. Compact List uses a single
/// lightweight row per card instead of the full card treatment, so a
/// deck with hundreds or thousands of cards doesn't construct that many
/// full card views — combined with `LazyVGrid`/`LazyVStack`'s native
/// viewport virtualization, only what's actually visible gets rendered.
enum CardDisplayMode: String, CaseIterable {
    case compactList
    case detailed

    var displayName: String {
        switch self {
        case .compactList: return "Compact List"
        case .detailed: return "Detailed Cards"
        }
    }

    var icon: String {
        switch self {
        case .compactList: return "list.bullet"
        case .detailed: return "rectangle.grid.2x2"
        }
    }
}

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
    let statusCatalog: StatusCatalog
    let selectionLabel: String
    let isEditable: Bool
    let onViewDetails: (KnowledgeCard) -> Void
    let onEditCard: ((KnowledgeCard) -> Void)?
    let onApplyIntervention: (KnowledgeCard) -> Void
    let onChangeStatus: (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void
    let onResetToAutomatic: (KnowledgeCard) -> Void
    let onChooseAnotherDeck: (() -> Void)?
    let onCreateCard: (() -> Void)?
    let onAssignToSelectedElement: ((KnowledgeCard) -> Void)?
    let onDropCardToStatus: ((UUID, SystemCardStatus, String?) -> Void)?
    let onQuickCreateCard: ((String, String?, String) -> Void)?
    let onQuickCreateAndEdit: ((String, String?, String) -> Void)?
    let onCreateSuiteInline: ((String) -> CardSuit)?
    let onBulkCreateCards: (([(title: String, suitID: String?)]) -> Void)?
    let onManageStatuses: (() -> Void)?
    let onCollapseDrawer: (() -> Void)?
    let onOpenContextualHand: (() -> Void)?

    init(
        cards: [KnowledgeCard],
        suits: [CardSuit],
        deckSuits: [CardSuit] = [],
        evaluations: [SystemCardEvaluation],
        statusCatalog: StatusCatalog = .empty,
        selectionLabel: String,
        isEditable: Bool,
        onViewDetails: @escaping (KnowledgeCard) -> Void,
        onEditCard: ((KnowledgeCard) -> Void)? = nil,
        onApplyIntervention: @escaping (KnowledgeCard) -> Void,
        onChangeStatus: @escaping (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void,
        onResetToAutomatic: @escaping (KnowledgeCard) -> Void,
        onChooseAnotherDeck: (() -> Void)? = nil,
        onCreateCard: (() -> Void)? = nil,
        onAssignToSelectedElement: ((KnowledgeCard) -> Void)? = nil,
        onDropCardToStatus: ((UUID, SystemCardStatus, String?) -> Void)? = nil,
        onQuickCreateCard: ((String, String?, String) -> Void)? = nil,
        onQuickCreateAndEdit: ((String, String?, String) -> Void)? = nil,
        onCreateSuiteInline: ((String) -> CardSuit)? = nil,
        onBulkCreateCards: (([(title: String, suitID: String?)]) -> Void)? = nil,
        onManageStatuses: (() -> Void)? = nil,
        onCollapseDrawer: (() -> Void)? = nil,
        onOpenContextualHand: (() -> Void)? = nil
    ) {
        self.cards = cards
        self.suits = suits
        self.deckSuits = deckSuits
        self.evaluations = evaluations
        self.statusCatalog = statusCatalog
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
        self.onManageStatuses = onManageStatuses
        self.onCollapseDrawer = onCollapseDrawer
        self.onOpenContextualHand = onOpenContextualHand
    }

    @State private var searchText = ""
    @State private var statusFilter: SystemCardStatus?
    @State private var selectedSuitIDs: Set<String> = []
    @State private var favoritesOnly = false
    @State private var manualDisplayMode: CardDisplayMode?

    /// Above this many cards in the deck, Compact List becomes the default
    /// so the Full Library doesn't construct hundreds of full card views
    /// per render — the user can still switch back manually.
    private static let compactModeThreshold = 200

    private var displayMode: CardDisplayMode {
        manualDisplayMode ?? (cards.count > Self.compactModeThreshold ? .compactList : .detailed)
    }
    @State private var isDropTargetedGroup: StatusGroupKey?
    @State private var showingQuickCreate = false
    @State private var showingBulkAdd = false
    /// Which group ranks the user has manually expanded/collapsed this
    /// session, layered on top of the defaults in `isExpandedByDefault`.
    @State private var manuallyToggledRanks: Set<Int> = []

    /// Active (rank 0) and Available (rank 1) are expanded by default;
    /// everything else — Locked/Disabled, Pending, Exhausted/Resolved,
    /// Irrelevant — starts collapsed so a large deck doesn't render
    /// hundreds of cards the moment a node is selected. A custom status
    /// inherits its `behavesLike` rank, so it starts in the same state as
    /// whatever built-in group it behaves like.
    private func isExpandedByDefault(rank: Int) -> Bool { rank <= 1 }

    private func isExpanded(rank: Int) -> Bool {
        manuallyToggledRanks.contains(rank) ? !isExpandedByDefault(rank: rank) : isExpandedByDefault(rank: rank)
    }

    private func toggleExpanded(rank: Int) {
        if manuallyToggledRanks.contains(rank) { manuallyToggledRanks.remove(rank) } else { manuallyToggledRanks.insert(rank) }
    }

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

    /// Groups by custom status when the matching override named one, so a
    /// custom status gets its own section instead of merging into whichever
    /// built-in status it behaves like. Built-in groups sort by groupRank
    /// first; custom groups follow, sorted by their own display order.
    private enum StatusGroupKey: Hashable {
        case builtIn(SystemCardStatus)
        case custom(String)
    }

    private var groupedCards: [(key: StatusGroupKey, title: String, color: Color, rank: Int, dropStatus: SystemCardStatus, dropCustomStatusID: String?, cards: [KnowledgeCard])] {
        let groups = Dictionary(grouping: filteredCards) { card -> StatusGroupKey in
            guard let eval = evaluationByID[card.id] else { return .builtIn(.available) }
            if let customID = eval.effectiveCustomStatusID { return .custom(customID) }
            return .builtIn(eval.effectiveStatus)
        }
        var result: [(StatusGroupKey, String, Color, Int, SystemCardStatus, String?, [KnowledgeCard])] = []
        for status in SystemCardStatus.allCases.sorted(by: { $0.groupRank < $1.groupRank }) {
            let key = StatusGroupKey.builtIn(status)
            guard let inGroup = groups[key], !inGroup.isEmpty else { continue }
            let title = statusCatalog.labelOverrides[status.rawValue] ?? status.groupTitle
            if let lastIdx = result.indices.last, result[lastIdx].1 == title {
                result[lastIdx].6.append(contentsOf: inGroup)
            } else {
                result.append((key, title, status.arenaColor, status.groupRank, status, nil, inGroup))
            }
        }
        for custom in statusCatalog.customStatuses.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            let key = StatusGroupKey.custom(custom.id)
            guard let inGroup = groups[key], !inGroup.isEmpty else { continue }
            result.append((key, custom.name, custom.colorToken.color, custom.behavesLike.groupRank, custom.behavesLike, custom.id, inGroup))
        }
        return result
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
                        ForEach(groupedCards, id: \.key) { group in
                            let expanded = isExpanded(rank: group.rank)
                            VStack(alignment: .leading, spacing: 6) {
                                Button(action: { toggleExpanded(rank: group.rank) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(group.color.opacity(0.75))
                                        ArenaSectionLabel(text: "\(group.title) (\(group.cards.count))", color: group.color)
                                        if isDropTargetedGroup == group.key {
                                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 9)).foregroundStyle(group.color)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                if expanded {
                                    switch displayMode {
                                    case .detailed:
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 8)], spacing: 8) {
                                            ForEach(group.cards) { card in
                                                SystemLibraryCardView(
                                                    card: card,
                                                    suite: suits.first(where: { card.suitIDs.contains($0.id) }),
                                                    evaluation: evaluationByID[card.id],
                                                    statusCatalog: statusCatalog,
                                                    isEditable: isEditable,
                                                    selectionLabel: selectionLabel,
                                                    onViewDetails: { onViewDetails(card) },
                                                    onEdit: onEditCard.map { edit in { edit(card) } },
                                                    onApplyIntervention: { onApplyIntervention(card) },
                                                    onChangeStatus: { status, customID, scope in onChangeStatus(card, status, customID, scope) },
                                                    onResetToAutomatic: { onResetToAutomatic(card) },
                                                    onAssignToSelectedElement: onAssignToSelectedElement.map { assign in { assign(card) } }
                                                )
                                            }
                                        }
                                    case .compactList:
                                        LazyVStack(alignment: .leading, spacing: 3) {
                                            ForEach(group.cards) { card in
                                                CompactCardRow(
                                                    card: card,
                                                    suite: suits.first(where: { card.suitIDs.contains($0.id) }),
                                                    evaluation: evaluationByID[card.id],
                                                    statusCatalog: statusCatalog,
                                                    isEditable: isEditable,
                                                    onViewDetails: { onViewDetails(card) },
                                                    onApplyIntervention: { onApplyIntervention(card) },
                                                    onChangeStatus: { status, customID, scope in onChangeStatus(card, status, customID, scope) }
                                                )
                                            }
                                        }
                                    }
                                } else {
                                    collapsedGroupSummary(group)
                                }
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDropTargetedGroup == group.key ? group.color.opacity(0.12) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isDropTargetedGroup == group.key ? group.color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                            )
                            .dropDestination(for: String.self, action: { items, _ in
                                guard let onDropCardToStatus else { return false }
                                var accepted = false
                                for item in items {
                                    if let cardID = UUID(uuidString: item) {
                                        onDropCardToStatus(cardID, group.dropStatus, group.dropCustomStatusID)
                                        accepted = true
                                    }
                                }
                                return accepted
                            }, isTargeted: { targeted in
                                isDropTargetedGroup = targeted ? group.key : (isDropTargetedGroup == group.key ? nil : isDropTargetedGroup)
                            })
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

    /// A cheap, structured summary shown instead of rendering every card in
    /// a collapsed group — real counts from data already computed, not a
    /// guess at the reasons' free text.
    private func collapsedGroupSummary(_ group: (key: StatusGroupKey, title: String, color: Color, rank: Int, dropStatus: SystemCardStatus, dropCustomStatusID: String?, cards: [KnowledgeCard])) -> some View {
        let overriddenCount = group.cards.filter { evaluationByID[$0.id]?.isOverridden == true }.count
        let withMissing = group.cards.filter { !(evaluationByID[$0.id]?.missingRequirements.isEmpty ?? true) }.count
        let withBlocking = group.cards.filter { !(evaluationByID[$0.id]?.blockingConditions.isEmpty ?? true) }.count
        return HStack(spacing: 10) {
            if withMissing > 0 {
                Text("\(withMissing) missing prerequisites").font(.system(size: 9)).foregroundStyle(AC.textDim)
            }
            if withBlocking > 0 {
                Text("\(withBlocking) blocked by active conditions").font(.system(size: 9)).foregroundStyle(AC.textDim)
            }
            if overriddenCount > 0 {
                Text("\(overriddenCount) manually overridden").font(.system(size: 9)).foregroundStyle(AC.textDim)
            }
        }
        .padding(.leading, 16)
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
                ArenaSectionLabel(text: "Full Library — \(selectionLabel)", icon: "square.stack.3d.up")
                Spacer()
                if let onCollapseDrawer {
                    Button(action: onCollapseDrawer) { Image(systemName: "chevron.down.circle") }
                        .buttonStyle(.plain).foregroundStyle(AC.textDim).help("Collapse")
                }
                if let onOpenContextualHand {
                    Button(action: onOpenContextualHand) { Image(systemName: "hand.raised") }
                        .buttonStyle(.plain).foregroundStyle(AC.textDim).help("Back to Contextual Hand")
                }
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
                Menu {
                    ForEach(CardDisplayMode.allCases, id: \.self) { mode in
                        Button(action: { manualDisplayMode = mode }) {
                            Label(mode.displayName, systemImage: mode.icon)
                        }
                    }
                } label: {
                    Image(systemName: displayMode.icon)
                }
                .buttonStyle(ArenaOutlineButtonStyle())
                .menuStyle(.button)
                .help("Display: \(displayMode.displayName)")
                if let onManageStatuses {
                    Button(action: onManageStatuses) {
                        Image(systemName: "tag.circle")
                    }
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .help("Manage Statuses")
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
                        Text(statusCatalog.labelOverrides[status.rawValue] ?? status.displayName).tag(Optional(status))
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
                        color: SuiteColors.color(for: suit)
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
    let statusCatalog: StatusCatalog
    let isEditable: Bool
    let selectionLabel: String
    let onViewDetails: () -> Void
    let onEdit: (() -> Void)?
    let onApplyIntervention: () -> Void
    let onChangeStatus: (SystemCardStatus, String?, SystemOverrideScope) -> Void
    let onResetToAutomatic: () -> Void
    let onAssignToSelectedElement: (() -> Void)?

    @State private var showingWhy = false

    /// Behavioral status — drives playability/menu logic, never displayed
    /// directly (use `display`/`automaticDisplay` for that).
    private var status: SystemCardStatus { evaluation?.effectiveStatus ?? .available }
    private var display: StatusDisplayInfo {
        evaluation?.displayInfo(catalog: statusCatalog) ?? StatusDisplayInfo(name: status.displayName, icon: status.systemImage, color: status.arenaColor)
    }
    private var automaticDisplay: StatusDisplayInfo? {
        evaluation?.automaticDisplayInfo(catalog: statusCatalog)
    }
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

            if showingWhy, let evaluation, let automaticDisplay {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUTOMATIC: \(automaticDisplay.name.uppercased())")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(automaticDisplay.color.opacity(0.85))
                    Text(evaluation.automaticExplanation)
                        .font(.system(size: 9))
                        .foregroundStyle(AC.textSub)
                        .fixedSize(horizontal: false, vertical: true)
                    if evaluation.isOverridden {
                        Text("OVERRIDE (\(evaluation.overrideScope?.displayName.uppercased() ?? "")): \(display.name.uppercased())")
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
                .stroke(display.color.opacity(0.5), lineWidth: 1)
        )
        .opacity(status == .irrelevant ? 0.55 : 1.0)
        .draggable(card.id.uuidString) {
            // Compact drag preview: title, suite initials, effective status.
            HStack(spacing: 5) {
                if let suite { SuiteBadge(suite: suite, size: 14) }
                Text(card.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.text)
                Text(display.name.uppercased()).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(display.color)
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
    private func statusOptions(for scope: SystemOverrideScope) -> some View {
        ForEach(SystemCardStatus.allCases, id: \.self) { s in
            Button(statusCatalog.labelOverrides[s.rawValue] ?? s.displayName) { onChangeStatus(s, nil, scope) }
        }
        if !statusCatalog.customStatuses.isEmpty {
            Divider()
            ForEach(statusCatalog.customStatuses.sorted { $0.displayOrder < $1.displayOrder }) { custom in
                Button(custom.name) { onChangeStatus(custom.behavesLike, custom.id, scope) }
            }
        }
    }

    @ViewBuilder
    private var statusMenu: some View {
        Menu {
            Section("Change Status — This Element") {
                statusOptions(for: .thisElementOnly)
            }
            Menu("Change Status — Entire Scenario") {
                statusOptions(for: .entireScenario)
            }
            Menu("Change Status — Default For Workflow") {
                statusOptions(for: .workflowDefault)
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
            Image(systemName: display.icon).font(.system(size: 8))
            Text(display.name.uppercased()).font(.system(size: 7.5, weight: .black, design: .monospaced)).kerning(0.5)
            if evaluation?.isOverridden == true {
                Image(systemName: "hand.raised.fill").font(.system(size: 7))
            }
            Image(systemName: "chevron.down").font(.system(size: 6))
        }
        .foregroundStyle(display.color)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(display.color.opacity(0.15)))
    }
}

// MARK: - Compact List row (large-deck display mode)
//
// A single lightweight line per card — no "Why?" panel, no drag preview
// construction beyond the string payload itself. Keeps drag-and-drop,
// status changes, and detail/apply actions available without the cost of
// a full card view per row.

private struct CompactCardRow: View {
    let card: KnowledgeCard
    let suite: CardSuit?
    let evaluation: SystemCardEvaluation?
    let statusCatalog: StatusCatalog
    let isEditable: Bool
    let onViewDetails: () -> Void
    let onApplyIntervention: () -> Void
    let onChangeStatus: (SystemCardStatus, String?, SystemOverrideScope) -> Void

    private var status: SystemCardStatus { evaluation?.effectiveStatus ?? .available }
    private var display: StatusDisplayInfo {
        evaluation?.displayInfo(catalog: statusCatalog) ?? StatusDisplayInfo(name: status.displayName, icon: status.systemImage, color: status.arenaColor)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let suite { SuiteBadge(suite: suite, size: 12) }
            Text(card.title).font(.system(size: 11)).foregroundStyle(AC.text).lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 3) {
                Image(systemName: display.icon).font(.system(size: 7))
                Text(display.name.uppercased()).font(.system(size: 7, weight: .black, design: .monospaced))
            }
            .foregroundStyle(display.color)
            if isEditable, evaluation?.isPlayable == true {
                Button("Apply", action: onApplyIntervention).buttonStyle(ArenaOutlineButtonStyle(color: AC.available.opacity(0.6)))
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 4).fill(AC.surface))
        .opacity(status == .irrelevant ? 0.55 : 1.0)
        .draggable(card.id.uuidString)
        .contextMenu {
            Button("View Details", action: onViewDetails)
            if isEditable, evaluation?.isPlayable == true {
                Button("Apply Intervention", action: onApplyIntervention)
            }
            Menu("Change Status") {
                ForEach(SystemCardStatus.allCases, id: \.self) { s in
                    Button(s.displayName) { onChangeStatus(s, nil, .thisElementOnly) }
                }
            }
        }
    }
}
