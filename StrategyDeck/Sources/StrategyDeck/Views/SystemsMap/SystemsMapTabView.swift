import SwiftUI
import AppKit
import StrategyDeckCore

struct SystemsMapTabView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    @EnvironmentObject var cardStore: CardStore
    @State private var selectedFolderID: UUID?

    var body: some View {
        Group {
            if systemMapStore.currentSystemMap != nil {
                SystemsMapEditorView(selectedFolderID: $selectedFolderID)
            } else {
                SystemsMapEmptyStateView(selectedFolderID: $selectedFolderID)
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
    }
}

// MARK: - Empty state / list

private struct SystemsMapEmptyStateView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    @Binding var selectedFolderID: UUID?
    @State private var showingNewSheet = false
    @State private var newTitle = ""
    @State private var newDescription = ""
    @State private var newGoal = ""
    @State private var pendingCreateFolderID: UUID?

    var body: some View {
        ZStack {
            DigitalArenaBackground()
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SYSTEMS MAP")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.cyan)
                        .kerning(2)
                    Text("Build a Donella Meadows–style stock-and-flow diagram of the system you're working in. Select a stock, flow, or relationship and a scenario to immediately see which strategy cards are active, available, locked, or disabled — and why. The diagram is the map of the system; the cards are the available interventions; the scenario sets the surrounding conditions.")
                        .font(.system(size: 12))
                        .foregroundStyle(AC.textSub)
                    Button(action: loadExample) {
                        Label("LOAD EXAMPLE: INVENTORY RESILIENCE", systemImage: "shippingbox")
                    }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                SystemMapExplorerView(
                    selectedFolderID: $selectedFolderID,
                    onCreateMap: { folderID in
                        pendingCreateFolderID = folderID
                        showingNewSheet = true
                    },
                    onOpenMap: { id in systemMapStore.openSystemMap(id: id) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showingNewSheet) {
            NewSystemMapSheet(
                title: $newTitle,
                description: $newDescription,
                goal: $newGoal,
                isPresented: $showingNewSheet,
                onCreate: {
                    guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    systemMapStore.createSystemMap(title: newTitle, description: newDescription, primaryGoal: newGoal, folderID: pendingCreateFolderID)
                    newTitle = ""; newDescription = ""; newGoal = ""
                }
            )
            .frame(minWidth: 420, minHeight: 260)
        }
    }

    private func loadExample() {
        systemMapStore.addAndOpen(SystemMapTemplates.inventoryResilience())
    }
}

struct SystemMapSummaryRow: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    let map: SystemMap
    var isFavorite: Bool = false
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    var onToggleFavorite: (() -> Void)? = nil
    var onMoveTo: ((UUID?) -> Void)? = nil
    var onExport: (() -> Void)? = nil
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(isFavorite ? AC.gold : AC.textGhost)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(map.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(AC.text)
                if !map.primaryGoal.isEmpty {
                    Text("Goal: \(map.primaryGoal)").font(.system(size: 11)).foregroundStyle(AC.textSub).lineLimit(1)
                } else if !map.description.isEmpty {
                    Text(map.description).font(.system(size: 11)).foregroundStyle(AC.textSub).lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text("Scenarios: \(map.scenarios.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(AC.textDim)
                    Text("Elements: \(map.elements.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(AC.textDim)
                    Text("Updated: \(map.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))").font(.system(size: 10, design: .monospaced)).foregroundStyle(AC.textDim)
                }
            }
            Spacer()
            Button(action: onOpen) { Text("OPEN") }.buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
            Button(action: onDuplicate) { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).foregroundStyle(AC.textDim)
            if let onExport {
                Button(action: onExport) { Image(systemName: "square.and.arrow.up") }.buttonStyle(.plain).foregroundStyle(AC.textDim)
            }
            if let onMoveTo {
                Menu {
                    Button("Root") { onMoveTo(nil) }
                    ForEach(systemMapStore.folders.filter { $0.id != map.folderID }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { folder in
                        Button(folder.name) { onMoveTo(folder.id) }
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16)
                .foregroundStyle(AC.textDim)
            }
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(AC.threat.opacity(0.75))
        }
        .padding(12)
        .background(AngularCardShape(cornerRadius: 10, cornerCut: 16).fill(AC.surface))
        .overlay(AngularCardShape(cornerRadius: 10, cornerCut: 16).stroke(AC.borderDim, lineWidth: 0.75))
    }
}

private struct NewSystemMapSheet: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var goal: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CREATE A SYSTEM MAP").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1.5)
            VStack(alignment: .leading, spacing: 10) {
                labeledField("TITLE") { TextField("e.g. Inventory Resilience", text: $title).arenaFieldStyle() }
                labeledField("DESCRIPTION") { TextField("What system is this?", text: $description).arenaFieldStyle() }
                labeledField("PRIMARY GOAL") { TextField("What outcome are you trying to reach?", text: $goal).arenaFieldStyle() }
            }
            HStack {
                Button("Cancel") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { onCreate(); isPresented = false }
                    .buttonStyle(ArenaButtonStyle(isDisabled: title.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .background(AC.bg)
        .colorScheme(.dark)
    }

    @ViewBuilder
    private func labeledField<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
            content()
        }
    }
}

// MARK: - Editor
//
// The mental model: the selected diagram element determines the immediate
// card context; the selected scenario determines the surrounding
// conditions. There is no chronological "step" here — switching scenarios
// or selection reevaluates the whole card library immediately.

private struct SystemsMapEditorView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    @EnvironmentObject var cardStore: CardStore
    @Binding var selectedFolderID: UUID?

    @State private var tool: DiagramTool = .select
    @State private var selection: DiagramSelection?
    @State private var pendingConnectSourceID: UUID?
    @State private var contextPanelTab: ContextPanelTab = .details
    @State private var libraryDrawerState: LibraryDrawerState = .closed
    @State private var isFocusMode = false
    @State private var showingInterventionSheetFor: KnowledgeCard?
    @State private var showingDetailsFor: KnowledgeCard?
    @State private var showingRenameMapSheet = false
    @State private var renameMapText = ""
    @State private var showingNewScenarioSheet = false
    @State private var newScenarioName = ""
    @State private var newScenarioDescription = ""
    @State private var showingRenameScenarioSheet = false
    @State private var renameScenarioText = ""
    @State private var showingCompareSheet = false
    @State private var showingDeckPicker = false
    @State private var editingDeckID: String?
    @State private var showingCreateCardSheet = false
    @State private var newCard = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, metadata: .softwareStrategy(SoftwareStrategyFields()), title: "")
    @State private var editingCardFromTray: KnowledgeCard?
    @State private var showingManageStatuses = false
    @State private var editingIssue: SystemIssue?
    @State private var showingCommandPalette = false
    @State private var alertState: AlertState?
    @State private var undoStack: [EditorSnapshot] = []
    @State private var redoStack: [EditorSnapshot] = []
    @State private var pendingDrop: PendingCardDrop?

    /// One undo entry — diagram structure plus the current scenario's
    /// override state, so a drag-driven status change or target assignment
    /// is just as undoable as a diagram edit, in the same stack.
    private struct EditorSnapshot {
        var elements: [SystemElement]
        var flows: [SystemFlow]
        var relationships: [SystemRelationship]
        var scenario: SystemScenario
    }

    private var map: SystemMap { systemMapStore.currentSystemMap ?? SystemMap(title: "") }
    private var scenario: SystemScenario { map.selectedScenario ?? SystemScenario(name: "Scenario") }

    private var effectiveElements: [SystemElement] { map.effectiveElements(for: scenario) }
    private var effectiveFlows: [SystemFlow] { map.effectiveFlows(for: scenario) }

    private var elementActiveCardCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for override in scenario.cardStatusOverrides where override.scope == .thisElementOnly && override.overriddenStatus == .active {
            if let id = override.targetElementID { counts[id, default: 0] += 1 }
        }
        return counts
    }

    /// Active issues (bugs, blockers, risks, etc.) in the current scenario,
    /// regardless of which element they're attached to — used for node
    /// badges and the issues panel.
    private var activeIssuesInScenario: [SystemIssue] {
        map.issues.filter { $0.status.isActive && $0.appliesTo(scenarioID: scenario.id) }
    }

    /// Issue/blocker counts for the SELECTED header — scoped to the current
    /// selection when something's selected, otherwise map-wide (matches
    /// `issuesForSelection`'s own nil-selection fallback below).
    private var selectionIssueCount: Int { issuesForSelection.filter { $0.status.isActive }.count }
    private var selectionBlockerCount: Int { issuesForSelection.filter { $0.status.isActive && ($0.severity == .critical || $0.type == .blocker) }.count }
    private var selectionActiveCardCount: Int { relevantEvaluations.filter { $0.effectiveStatus == .active }.count }
    private var selectionAvailableCardCount: Int { relevantEvaluations.filter { $0.isPlayable }.count }

    private var elementIssueCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for issue in activeIssuesInScenario {
            for id in issue.affectedElementIDs { counts[id, default: 0] += 1 }
        }
        return counts
    }

    private var elementCriticalBlockerCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for issue in activeIssuesInScenario where issue.severity == .critical || issue.type == .blocker {
            for id in issue.affectedElementIDs { counts[id, default: 0] += 1 }
        }
        return counts
    }

    /// Broader than `selectedElementID` — flows and relationships can also
    /// have issues attached, even though only elements participate in card
    /// target-kind evaluation.
    private var selectedAnyID: UUID? { elementID(for: selection) }

    /// Resolves any diagram selection (element, flow, or relationship) to
    /// the UUID an issue attachment or the Contextual Hand should key off —
    /// broader than `selectedElementID`, which only ever populates for
    /// `.element` since that's all card target-kind evaluation needs.
    private func elementID(for target: DiagramSelection?) -> UUID? {
        switch target {
        case .element(let id): return id
        case .flow(let id): return id
        case .relationship(let id): return id
        case .none: return nil
        }
    }

    private var issuesForSelection: [SystemIssue] {
        activeIssuesInScenario.filter { selectedAnyID == nil || $0.affects(elementID: selectedAnyID!) }
    }

    private var elementStates: [UUID: SystemElementState] {
        var result: [UUID: SystemElementState] = [:]
        for (id, override) in scenario.elementOverrides { if let s = override.state { result[id] = s } }
        for (id, override) in scenario.flowOverrides { if let s = override.state { result[id] = s } }
        return result
    }

    private var selectedTargetKind: SystemTargetKind? {
        switch selection {
        case .element(let id):
            guard let el = map.elements.first(where: { $0.id == id }) else { return nil }
            return SystemMapEvaluator.targetKind(for: el.kind)
        case .flow: return .flow
        case .relationship: return .relationship
        case .none: return nil
        }
    }

    private var selectedElementID: UUID? {
        if case .element(let id) = selection { return id }
        return nil
    }

    private var selectionLabel: String {
        switch selection {
        case .element(let id): return map.elements.first(where: { $0.id == id })?.name ?? "Element"
        case .flow(let id): return map.flows.first(where: { $0.id == id })?.name ?? "Flow"
        case .relationship: return "Relationship"
        case .none: return "Entire System"
        }
    }

    /// Deck resolution: scenario override → map default → All Cards. Only
    /// the resulting card *pool* is affected — overrides/statuses remain
    /// keyed by card ID regardless of which deck is currently selected, so
    /// switching decks never loses saved state for cards outside the pool.
    private var effectiveDeckID: String? { map.effectiveDeckID(for: scenario) }

    private var deckName: String {
        guard let effectiveDeckID else { return "All Cards" }
        return cardStore.decks.first(where: { $0.id == effectiveDeckID })?.name ?? "All Cards"
    }

    private var isUsingScenarioDeckOverride: Bool { scenario.deckOverrideID != nil }

    private var deckScopedCards: [KnowledgeCard] {
        guard let effectiveDeckID else { return cardStore.cards }
        return cardStore.cards.filter { $0.deckIDs.contains(effectiveDeckID) }
    }

    private var evaluations: [SystemCardEvaluation] {
        SystemMapEvaluator.evaluateAll(
            cards: deckScopedCards,
            map: map,
            scenario: scenario,
            selectedTargetKind: selectedTargetKind,
            selectedElementID: selectedElementID
        )
    }

    private var evaluationByID: [UUID: SystemCardEvaluation] {
        Dictionary(uniqueKeysWithValues: evaluations.map { ($0.cardID, $0) })
    }

    /// Relevant to the current selection — the pool the Contextual Hand
    /// ranks from and the "View All N Relevant Cards" count refers to.
    /// Irrelevant cards (wrong target type) are excluded outright.
    private var relevantEvaluations: [SystemCardEvaluation] {
        evaluations.filter { $0.effectiveStatus != .irrelevant }
    }

    /// Cards with an override touched in the last 10 minutes in this
    /// scenario — a real, deterministic "recently changed" signal reusing
    /// timestamps the override model already tracks, no new field needed.
    private var recentlyChangedCardIDs: Set<UUID> {
        let cutoff = Date().addingTimeInterval(-600)
        return Set(scenario.cardStatusOverrides.filter { $0.updatedAt > cutoff }.map(\.cardID))
    }

    private var contextualHandEntries: [ContextualHandEntry] {
        let relevantIDs = Set(relevantEvaluations.map(\.cardID))
        return ContextualHandRanker.rank(
            cards: deckScopedCards.filter { relevantIDs.contains($0.id) },
            evaluationsByCardID: evaluationByID,
            pins: map.cardPins,
            elementID: selectedElementID,
            targetKind: selectedTargetKind,
            scenarioID: scenario.id,
            selectedSuitIDs: [],
            recentlyChangedCardIDs: recentlyChangedCardIDs,
            respondsToCriticalBlocker: { card in
                issuesForSelection.contains { issue in
                    issue.status.isActive && (issue.severity == .critical || issue.type == .blocker)
                        && issue.relatedCards.contains { $0.cardID == card.id }
                }
            },
            respondsToIssue: { card in
                for issue in issuesForSelection where issue.status.isActive {
                    if let rel = issue.relatedCards.first(where: { $0.cardID == card.id }) {
                        return (true, "\(rel.relationshipType.displayName) \(issue.title)")
                    }
                }
                return (false, nil)
            }
        )
    }

    var body: some View {
        GeometryReader { geo in
        let isCompactWidth = geo.size.width < 900
        VStack(spacing: 0) {
            SystemsMapCompactHeaderView(
                mapTitle: map.title,
                folderID: map.folderID,
                primaryGoal: map.primaryGoal,
                deckName: deckName,
                isUsingScenarioDeckOverride: isUsingScenarioDeckOverride,
                isFocusMode: isFocusMode,
                scenarios: map.scenarios,
                selectedScenarioID: map.selectedScenarioID,
                onNavigateFolder: { folderID in
                    selectedFolderID = folderID
                    systemMapStore.closeCurrentSystemMap()
                },
                onClose: { systemMapStore.closeCurrentSystemMap() },
                onRenameMap: { renameMapText = map.title; showingRenameMapSheet = true },
                onToggleFocusMode: { isFocusMode.toggle() },
                onExport: exportJSON,
                onOpenDeckPicker: { showingDeckPicker = true },
                onOverrideDeckForScenario: {
                    systemMapStore.setScenarioDeckOverride(scenarioID: scenario.id, deckID: map.defaultDeckID)
                    showingDeckPicker = true
                },
                onResetDeckOverride: { systemMapStore.setScenarioDeckOverride(scenarioID: scenario.id, deckID: nil) },
                onSelectScenario: { systemMapStore.selectScenario(id: $0); selection = nil },
                onNewScenario: {
                    newScenarioName = ""
                    newScenarioDescription = ""
                    showingNewScenarioSheet = true
                },
                onDuplicateCurrentScenario: { systemMapStore.duplicateScenario(id: scenario.id) },
                onRenameCurrentScenario: {
                    renameScenarioText = scenario.name
                    showingRenameScenarioSheet = true
                },
                onSetCurrentScenarioDefault: { systemMapStore.setDefaultScenario(id: scenario.id) },
                onResetCurrentScenario: {
                    alertState = .destructive(
                        title: "Reset “\(scenario.name)”?",
                        message: "Every override in this scenario will be cleared, returning it to the shared base workflow.",
                        confirmLabel: "Reset"
                    ) { systemMapStore.resetScenario(id: scenario.id) }
                },
                onDeleteCurrentScenario: {
                    alertState = .destructive(
                        title: "Delete “\(scenario.name)”?",
                        message: "This scenario and its overrides will be removed permanently.",
                        confirmLabel: "Delete"
                    ) { systemMapStore.deleteScenario(id: scenario.id) }
                },
                onCompareScenarios: { showingCompareSheet = true }
            )
            Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)

            // Space opens the node command palette when something's
            // selected — invisible, doesn't compete with any visible
            // control's own Space activation.
            Button("") { if selection != nil { showingCommandPalette = true } }
                .keyboardShortcut(.space, modifiers: [])
                .hidden()
                .frame(width: 0, height: 0)

            HStack(spacing: 0) {
                SystemDiagramToolbar(
                    tool: $tool,
                    isEditable: true,
                    hasSelection: selection != nil,
                    canUndo: !undoStack.isEmpty,
                    canRedo: !redoStack.isEmpty,
                    onDelete: deleteSelection,
                    onUndo: undo,
                    onRedo: redo,
                    onZoomIn: {}, onZoomOut: {}, onFit: {}, onCenterSelection: {}
                )
                Button(action: { isFocusMode.toggle() }) {
                    Image(systemName: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isFocusMode ? AC.cyan : AC.textSub)
                .help(isFocusMode ? "Exit Focus Mode (⌘⇧F)" : "Focus Mode (⌘⇧F)")
                .padding(.trailing, 10)
            }
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            Button("") { isFocusMode.toggle() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .hidden().frame(width: 0, height: 0)
            Button("") { contextPanelTab = .details }
                .keyboardShortcut("1", modifiers: .command)
                .hidden().frame(width: 0, height: 0)
            Button("") { contextPanelTab = .cards }
                .keyboardShortcut("2", modifiers: .command)
                .hidden().frame(width: 0, height: 0)
            Button("") {
                switch libraryDrawerState {
                case .closed: libraryDrawerState = .expanded
                case .peek, .expanded: libraryDrawerState = .closed
                }
            }
            .keyboardShortcut("l", modifiers: .command)
            .hidden().frame(width: 0, height: 0)
            Button("") {
                if libraryDrawerState != .closed { libraryDrawerState = .closed }
                else if showingCommandPalette { showingCommandPalette = false }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .hidden().frame(width: 0, height: 0)

            VSplitView {
            HSplitView {
                SystemDiagramCanvasView(
                    elements: effectiveElements,
                    flows: effectiveFlows,
                    relationships: map.relationships,
                    elementStates: elementStates,
                    elementActiveCardCounts: elementActiveCardCounts,
                    elementIssueCounts: elementIssueCounts,
                    elementCriticalBlockerCounts: elementCriticalBlockerCounts,
                    isEditable: true,
                    selection: $selection,
                    tool: $tool,
                    pendingConnectSourceID: $pendingConnectSourceID,
                    onAddElement: { element in pushUndo(); systemMapStore.addElement(element) },
                    onMoveElement: { id, pos in pushUndo(); moveElement(id: id, to: pos) },
                    onAddFlow: { flow in pushUndo(); systemMapStore.addFlow(flow) },
                    onAddRelationship: { rel in pushUndo(); systemMapStore.addRelationship(rel) },
                    onDropCard: { cardID, targetSelection in handleCardDrop(cardID: cardID, onto: targetSelection) },
                    onDropIssue: { issueID, targetSelection in
                        guard let targetID = elementID(for: targetSelection) else { return }
                        pushOverrideUndo()
                        systemMapStore.attachIssue(id: issueID, toElementID: targetID)
                    },
                    onTapActiveCardBadge: { elementID in
                        selection = .element(elementID)
                        contextPanelTab = .cards
                    },
                    onTapIssueBadge: { elementID in
                        selection = .element(elementID)
                        contextPanelTab = .details
                    }
                )
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .overlay(alignment: .trailing) {
                    if !isFocusMode && isCompactWidth {
                        contextPanel
                            .transition(.move(edge: .trailing))
                    }
                }
                if !isFocusMode && !isCompactWidth {
                    contextPanel
                }
            }
            .frame(minHeight: 180, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.15), value: isCompactWidth)

            if !isFocusMode {
                libraryDrawer
                    .frame(
                        minHeight: libraryDrawerState == .expanded ? 150 : nil,
                        maxHeight: libraryDrawerState == .expanded ? .infinity : nil
                    )
            }
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
        .alertState($alertState)
        .sheet(item: $showingInterventionSheetFor) { card in
            ApplyInterventionSheet(
                card: card,
                targetLabel: selectionLabel,
                targetKind: selectedTargetKind ?? .system,
                linkedIssueEffects: linkedIssueEffects(for: card),
                onConfirm: { notes, issueResolutions in
                    systemMapStore.applyIntervention(card: card, targetElementID: selectedElementID, scenarioID: scenario.id, notes: notes)
                    for (issueID, status) in issueResolutions {
                        systemMapStore.setIssueStatus(id: issueID, status: status)
                    }
                    showingInterventionSheetFor = nil
                },
                onCancel: { showingInterventionSheetFor = nil }
            )
            .frame(minWidth: 420, minHeight: 320)
        }
        .sheet(item: $showingDetailsFor) { card in
            KnowledgeCardDetailView(
                card: card,
                suite: cardStore.suits.first(where: { card.suitIDs.contains($0.id) }),
                allCards: cardStore.cards,
                relationships: cardStore.relationships,
                onEdit: {
                    showingDetailsFor = nil
                    editingCardFromTray = card
                },
                onAddToTray: {},
                onDismiss: { showingDetailsFor = nil }
            )
            .frame(minWidth: 420, minHeight: 520)
        }
        .sheet(isPresented: $showingRenameMapSheet) {
            RenameSheet(
                title: "RENAME SYSTEM MAP",
                name: $renameMapText,
                isPresented: $showingRenameMapSheet,
                onSave: { systemMapStore.renameSystemMap(id: map.id, title: renameMapText) }
            )
            .frame(minWidth: 360, minHeight: 160)
        }
        .sheet(isPresented: $showingNewScenarioSheet) {
            NewScenarioSheet(
                name: $newScenarioName,
                description: $newScenarioDescription,
                isPresented: $showingNewScenarioSheet,
                onCreate: {
                    guard !newScenarioName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    systemMapStore.createScenario(name: newScenarioName, description: newScenarioDescription)
                    selection = nil
                }
            )
            .frame(minWidth: 380, minHeight: 220)
        }
        .sheet(isPresented: $showingRenameScenarioSheet) {
            RenameSheet(
                title: "RENAME SCENARIO",
                name: $renameScenarioText,
                isPresented: $showingRenameScenarioSheet,
                onSave: { systemMapStore.renameScenario(id: scenario.id, name: renameScenarioText) }
            )
            .frame(minWidth: 360, minHeight: 160)
        }
        .sheet(isPresented: $showingCompareSheet) {
            ScenarioComparisonSheet(map: map, allCards: cardStore.cards, isPresented: $showingCompareSheet)
                .frame(minWidth: 480, minHeight: 440)
        }
        .sheet(item: $pendingDrop) { drop in
            PendingCardDropSheet(
                drop: drop,
                onAction: { action in handleDropAction(action, for: drop) },
                onCancel: { pendingDrop = nil }
            )
            .frame(minWidth: 420, minHeight: 300)
        }
        .sheet(isPresented: $showingDeckPicker) {
            SystemDeckSelectorSheet(
                decks: cardStore.decks,
                allCards: cardStore.cards,
                map: map,
                scenario: scenario,
                selectedTargetKind: selectedTargetKind,
                selectedElementID: selectedElementID,
                currentDeckID: effectiveDeckID,
                onSelectDeck: { deckID in
                    if isUsingScenarioDeckOverride {
                        systemMapStore.setScenarioDeckOverride(scenarioID: scenario.id, deckID: deckID)
                    } else {
                        systemMapStore.setDefaultDeck(deckID)
                    }
                },
                onCreateDeck: { name in
                    let newDeck = cardStore.createDeck(name: name)
                    systemMapStore.setDefaultDeck(newDeck.id)
                },
                onRenameDeck: { id, name in cardStore.renameDeck(id: id, name: name) },
                onDuplicateDeck: { id in cardStore.duplicateDeck(id: id) },
                onDeleteDeck: { id in
                    cardStore.deleteDeck(id: id)
                    if map.defaultDeckID == id { systemMapStore.setDefaultDeck(nil) }
                    if scenario.deckOverrideID == id { systemMapStore.setScenarioDeckOverride(scenarioID: scenario.id, deckID: nil) }
                },
                onEditDeck: { id in editingDeckID = id },
                onDropCardOntoDeck: { cardID, deckID in cardStore.addCardToDeck(cardID: cardID, deckID: deckID) },
                isPresented: $showingDeckPicker
            )
        }
        .sheet(item: Binding(get: { editingDeckID.map { EditingDeckTarget(id: $0) } }, set: { editingDeckID = $0?.id })) { target in
            EditDeckSheet(deckID: target.id, decks: cardStore.decks, isPresented: Binding(get: { editingDeckID != nil }, set: { if !$0 { editingDeckID = nil } }))
                .environmentObject(cardStore)
                .frame(minWidth: 380, minHeight: 460)
        }
        .sheet(isPresented: $showingCreateCardSheet) {
            KnowledgeCardEditorView(
                mode: .create,
                card: $newCard,
                suits: suitsForSelectedDeck(),
                onSave: { created in
                    cardStore.add(created)
                    showingCreateCardSheet = false
                },
                onCancel: { showingCreateCardSheet = false }
            )
            .frame(minWidth: 380, minHeight: 500)
        }
        .sheet(item: $editingCardFromTray) { card in
            KnowledgeCardEditorView(
                mode: .edit,
                card: Binding(get: { editingCardFromTray ?? card }, set: { editingCardFromTray = $0 }),
                suits: suitsForSelectedDeck(),
                onSave: { updated in
                    cardStore.update(updated)
                    editingCardFromTray = nil
                },
                onCancel: { editingCardFromTray = nil }
            )
            .frame(minWidth: 380, minHeight: 500)
        }
        .sheet(item: $editingIssue) { issue in
            IssueEditorSheet(
                issue: Binding(get: { editingIssue ?? issue }, set: { editingIssue = $0 }),
                allElements: map.elements,
                allScenarios: map.scenarios,
                availableCards: deckScopedCards,
                onSave: { updated in
                    systemMapStore.updateIssue(updated)
                    editingIssue = nil
                },
                onCancel: { editingIssue = nil }
            )
            .frame(minWidth: 460, minHeight: 560)
        }
        .sheet(isPresented: $showingManageStatuses) {
            ManageStatusesSheet(
                map: map,
                onSetLabel: { status, label in systemMapStore.setStatusLabel(for: status, label: label) },
                onCreateCustomStatus: { name, iconName, colorToken, behavesLike in
                    systemMapStore.createCustomStatus(name: name, iconName: iconName, colorToken: colorToken, behavesLike: behavesLike)
                },
                onUpdateCustomStatus: { systemMapStore.updateCustomStatus($0) },
                onDeleteCustomStatus: { systemMapStore.deleteCustomStatus(id: $0) },
                isPresented: $showingManageStatuses
            )
        }
        .sheet(isPresented: $showingCommandPalette) {
            NodeCommandPaletteView(
                selectionLabel: selectionLabel,
                cards: deckScopedCards.filter { relevantEvaluations.map(\.cardID).contains($0.id) },
                evaluationByID: evaluationByID,
                statusCatalog: map.statusCatalog,
                suits: cardStore.suits,
                onViewDetails: { showingDetailsFor = $0; showingCommandPalette = false },
                onChangeStatus: { card, status, customStatusID, scope in
                    systemMapStore.setCardStatusOverride(
                        cardID: card.id, targetElementID: selectedElementID,
                        scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                    )
                },
                onApplyIntervention: { showingInterventionSheetFor = $0; showingCommandPalette = false },
                onTogglePin: { card in togglePin(for: card) },
                onAssignToSelectedElement: { card in
                    handleCardDrop(cardID: card.id, onto: selection)
                    showingCommandPalette = false
                },
                onClose: { showingCommandPalette = false }
            )
        }
        }
    }

    private func blankCard() -> KnowledgeCard {
        let deckSuits = suitsForSelectedDeck()
        return KnowledgeCard(
            deckIDs: effectiveDeckID.map { [$0] } ?? [],
            suitIDs: deckSuits.first.map { [$0.id] } ?? [],
            kind: .action,
            metadata: .softwareStrategy(SoftwareStrategyFields()),
            title: ""
        )
    }

    private func suitsForSelectedDeck() -> [CardSuit] {
        guard let effectiveDeckID else { return cardStore.suits }
        let filtered = cardStore.suits.filter { $0.deckID == effectiveDeckID }
        return filtered.isEmpty ? cardStore.suits : filtered
    }

    private struct EditingDeckTarget: Identifiable { let id: String }

    private var contextPanel: some View {
        SystemContextPanelView(
            selectionLabel: selectionLabel,
            selectionKindLabel: selectedTargetKind?.displayName,
            scenarioName: scenario.name,
            issueCount: selectionIssueCount,
            blockerCount: selectionBlockerCount,
            activeCardCount: selectionActiveCardCount,
            availableCardCount: selectionAvailableCardCount,
            tab: $contextPanelTab,
            hasSelection: selection != nil,
            inspector: SystemElementInspectorView(
                elements: map.elements,
                flows: map.flows,
                relationships: map.relationships,
                scenario: scenario,
                selection: selection,
                onUpdateElement: { el in pushUndo(); systemMapStore.updateElement(el) },
                onUpdateFlow: { flow in pushUndo(); systemMapStore.updateFlow(flow) },
                onUpdateRelationship: { rel in
                    pushUndo()
                    systemMapStore.deleteRelationship(id: rel.id)
                    systemMapStore.addRelationship(rel)
                },
                onUpdateElementOverride: { id, override in
                    systemMapStore.setElementOverride(
                        elementID: id, currentValue: override.currentValue,
                        state: override.state, notes: override.notes, inScenario: scenario.id
                    )
                },
                onUpdateFlowOverride: { id, override in
                    systemMapStore.setFlowOverride(
                        flowID: id, rate: override.rate,
                        isEnabled: override.isEnabled, state: override.state, inScenario: scenario.id
                    )
                },
                relatedCardCount: { kind in
                    cardStore.cards.filter { $0.playabilityRules.systemTargetTypes.isEmpty || $0.playabilityRules.systemTargetTypes.contains(kind) }.count
                }
            ),
            issuesPanel: SystemIssuesPanelView(
                issues: issuesForSelection,
                attachableIssues: selectedAnyID == nil ? [] : activeIssuesInScenario.filter { !$0.affects(elementID: selectedAnyID!) },
                selectionLabel: selectionLabel,
                onCreateIssue: { title, type, severity in
                    systemMapStore.createIssue(
                        title: title, type: type, severity: severity,
                        affectedElementIDs: selectedAnyID.map { [$0] } ?? [],
                        scenarioIDs: [scenario.id]
                    )
                },
                onAttachExisting: { issue in
                    if let selectedAnyID { systemMapStore.attachIssue(id: issue.id, toElementID: selectedAnyID) }
                },
                onEdit: { editingIssue = $0 },
                onSetStatus: { issue, status in systemMapStore.setIssueStatus(id: issue.id, status: status) },
                onSetSeverity: { issue, severity in systemMapStore.setIssueSeverity(id: issue.id, severity: severity) },
                onDuplicate: { systemMapStore.duplicateIssue(id: $0.id) },
                onRemoveFromElement: { issue in
                    if let selectedAnyID { systemMapStore.detachIssue(id: issue.id, fromElementID: selectedAnyID) }
                },
                onDelete: { issue in
                    alertState = .destructive(
                        title: "Delete “\(issue.title)”?",
                        message: "This issue will be removed permanently from the map.",
                        confirmLabel: "Delete"
                    ) { systemMapStore.deleteIssue(id: issue.id) }
                }
            ),
            systemOverview: SystemOverviewContent(
                stockCount: map.elements.filter { $0.kind == .stock }.count,
                flowCount: map.flows.count,
                constraintCount: map.elements.filter { $0.kind == .constraint }.count,
                activeIssueCount: activeIssuesInScenario.count,
                onViewCards: { contextPanelTab = .cards }
            ),
            contextualHand: SystemContextualHandView(
                entries: contextualHandEntries,
                totalRelevantCount: relevantEvaluations.count,
                selectionLabel: selectionLabel,
                statusCatalog: map.statusCatalog,
                isEditable: true,
                onViewDetails: { showingDetailsFor = $0 },
                onEditCard: { editingCardFromTray = $0 },
                onApplyIntervention: { showingInterventionSheetFor = $0 },
                onChangeStatus: { card, status, customStatusID, scope in
                    systemMapStore.setCardStatusOverride(
                        cardID: card.id, targetElementID: selectedElementID,
                        scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                    )
                },
                onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
                onTogglePin: { card in togglePin(for: card) },
                onSetPinScope: { card, scope in setPinScope(for: card, scope: scope) },
                onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
                onOpenFullLibrary: { libraryDrawerState = .expanded }
            )
        )
    }

    private var libraryDrawer: some View {
        SystemCardDrawerView(
            state: libraryDrawerState,
            onCycleState: {
                switch libraryDrawerState {
                case .closed: libraryDrawerState = .peek
                case .peek: libraryDrawerState = .expanded
                case .expanded: libraryDrawerState = .expanded
                }
            },
            onClose: { libraryDrawerState = .closed },
            deckName: deckName,
            statusCounts: SystemCardStatus.allCases.map { status in
                (status, evaluations.filter { $0.effectiveStatus == status }.count)
            },
            statusCatalog: map.statusCatalog,
            cards: deckScopedCards,
            suits: cardStore.suits,
            deckSuits: suitsForSelectedDeck(),
            evaluations: evaluations,
            selectionLabel: selectionLabel,
            isEditable: true,
            onViewDetails: { showingDetailsFor = $0 },
            onEditCard: { editingCardFromTray = $0 },
            onApplyIntervention: { showingInterventionSheetFor = $0 },
            onChangeStatus: { card, status, customStatusID, scope in
                systemMapStore.setCardStatusOverride(
                    cardID: card.id, targetElementID: selectedElementID,
                    scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                )
            },
            onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
            onChooseAnotherDeck: { showingDeckPicker = true },
            onCreateCard: {
                newCard = blankCard()
                showingCreateCardSheet = true
            },
            onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
            onDropCardToStatus: { cardID, status, customStatusID in
                guard let card = cardStore.cards.first(where: { $0.id == cardID }) else { return }
                pushOverrideUndo()
                systemMapStore.setCardStatusOverride(
                    cardID: card.id, targetElementID: selectedElementID,
                    scope: .thisElementOnly, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                )
            },
            onQuickCreateCard: { title, suitID, description in
                cardStore.quickCreateCard(title: title, deckID: effectiveDeckID, suitID: suitID, shortDescription: description)
            },
            onQuickCreateAndEdit: { title, suitID, description in
                editingCardFromTray = cardStore.quickCreateCard(title: title, deckID: effectiveDeckID, suitID: suitID, shortDescription: description)
            },
            onCreateSuiteInline: effectiveDeckID.map { deckID in
                { name in cardStore.createSuit(deckID: deckID, name: name) }
            },
            onBulkCreateCards: { entries in
                cardStore.bulkCreateCards(entries, deckID: effectiveDeckID)
            },
            onManageStatuses: { showingManageStatuses = true }
        )
    }

    // MARK: - Actions

    private func moveElement(id: UUID, to position: SystemPoint) {
        guard var element = map.elements.first(where: { $0.id == id }) else { return }
        element.position = position
        systemMapStore.updateElement(element)
    }

    private func deleteSelection() {
        pushUndo()
        switch selection {
        case .element(let id): systemMapStore.deleteElement(id: id)
        case .flow(let id): systemMapStore.deleteFlow(id: id)
        case .relationship(let id): systemMapStore.deleteRelationship(id: id)
        case .none: break
        }
        selection = nil
    }

    private func currentSnapshot() -> EditorSnapshot {
        EditorSnapshot(elements: map.elements, flows: map.flows, relationships: map.relationships, scenario: scenario)
    }

    private func restoreSnapshot(_ snapshot: EditorSnapshot) {
        systemMapStore.replaceDiagram(elements: snapshot.elements, flows: snapshot.flows, relationships: snapshot.relationships)
        systemMapStore.restoreScenario(snapshot.scenario)
    }

    private func pushUndo() {
        undoStack.append(currentSnapshot())
        redoStack.removeAll()
    }

    /// Same undo mechanism as diagram edits — a drag-driven status change,
    /// target assignment, or deck override is its own discrete entry, never
    /// combined with an unrelated action.
    private func pushOverrideUndo() { pushUndo() }

    private func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        restoreSnapshot(last)
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        restoreSnapshot(next)
    }

    /// Pinning always defaults to the safest scope (this element, this
    /// scenario). Changing scope afterward is a separate, explicit action
    /// from the Contextual Hand / Full Library's pin menu.
    private func togglePin(for card: KnowledgeCard) {
        if let existing = pin(for: card) {
            systemMapStore.unpinCard(id: existing.id)
        } else {
            systemMapStore.pinCard(
                cardID: card.id, scope: .thisElementThisScenario,
                elementID: selectedElementID, targetKind: selectedTargetKind, scenarioID: scenario.id
            )
        }
    }

    private func pin(for card: KnowledgeCard) -> ContextualCardPin? {
        map.cardPins.first {
            $0.cardID == card.id && $0.matches(elementID: selectedElementID, targetKind: selectedTargetKind, scenarioID: scenario.id)
        }
    }

    private func setPinScope(for card: KnowledgeCard, scope: PinScope) {
        if let existing = pin(for: card) {
            systemMapStore.updatePinScope(id: existing.id, scope: scope)
        } else {
            systemMapStore.pinCard(
                cardID: card.id, scope: scope,
                elementID: selectedElementID, targetKind: selectedTargetKind, scenarioID: scenario.id
            )
        }
    }

    /// "Reset to Automatic" clears whichever override the evaluator actually
    /// matched for the current selection — narrowest scope wins, so this
    /// clears exactly the override that's currently in effect.
    /// Issues affecting the current selection that this card is explicitly
    /// related to as a mitigating/resolving response — offered as optional
    /// effects when applying the card, never auto-resolved.
    private func linkedIssueEffects(for card: KnowledgeCard) -> [(issue: SystemIssue, resultingStatus: IssueStatus)] {
        issuesForSelection.compactMap { issue in
            guard let rel = issue.relatedCards.first(where: { $0.cardID == card.id }) else { return nil }
            switch rel.relationshipType {
            case .resolves: return (issue, .resolved)
            case .mitigates: return (issue, .mitigated)
            default: return nil
            }
        }
    }

    private func clearOverrideMatchingSelection(for card: KnowledgeCard) {
        guard let eval = evaluations.first(where: { $0.cardID == card.id }), let scope = eval.overrideScope else { return }
        systemMapStore.clearCardStatusOverride(
            cardID: card.id,
            scope: scope,
            targetElementID: scope == .thisElementOnly ? selectedElementID : nil,
            scenarioID: scenario.id
        )
    }

    private func exportJSON() {
        guard let encoded = try? JSONCoding.encoder.encode(map) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(map.title)-system-map.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? encoded.write(to: url, options: [.atomic])
        }
    }

    // MARK: - Card drag-and-drop onto the diagram
    //
    // Dropping never changes state by itself — it opens `pendingDrop`, whose
    // sheet shows status-appropriate actions and only commits on explicit
    // confirmation. The same entry point backs the drag gesture (from
    // `SystemDiagramCanvasView`) and the click-based "Assign to Selected
    // Element" menu item, so both paths behave identically.

    private func handleCardDrop(cardID: UUID, onto targetSelection: DiagramSelection?) {
        guard let card = cardStore.cards.first(where: { $0.id == cardID }) else { return }

        let targetElementID: UUID?
        let targetKind: SystemTargetKind
        let targetLabel: String
        switch targetSelection {
        case .element(let id):
            targetElementID = id
            if let element = map.elements.first(where: { $0.id == id }) {
                targetKind = SystemMapEvaluator.targetKind(for: element.kind)
                targetLabel = element.name
            } else {
                targetKind = .system
                targetLabel = "Entire System"
            }
        case .flow(let id):
            targetElementID = nil
            targetKind = .flow
            targetLabel = map.flows.first(where: { $0.id == id })?.name ?? "Flow"
        case .relationship:
            targetElementID = nil
            targetKind = .relationship
            targetLabel = "Relationship"
        case .none:
            targetElementID = nil
            targetKind = .system
            targetLabel = "Entire System"
        }

        let evaluation = SystemMapEvaluator.evaluate(
            card: card, map: map, scenario: scenario,
            selectedTargetKind: targetKind, selectedElementID: targetElementID, allCards: cardStore.cards
        )

        // Is this card already Active somewhere else specific, so dropping
        // here could mean "retarget" rather than "add a new target"?
        let otherActive = scenario.cardStatusOverrides.first {
            $0.cardID == card.id && $0.scope == .thisElementOnly && $0.overriddenStatus == .active && $0.targetElementID != targetElementID
        }
        let otherActiveLabel = otherActive?.targetElementID.flatMap { id in map.elements.first(where: { $0.id == id })?.name }

        pendingDrop = PendingCardDrop(
            card: card,
            targetElementID: targetElementID,
            targetLabel: targetLabel,
            targetKind: targetKind,
            evaluation: evaluation,
            otherActiveTargetID: otherActive?.targetElementID,
            otherActiveTargetLabel: otherActiveLabel
        )
    }

    private func handleDropAction(_ action: PendingDropAction, for drop: PendingCardDrop) {
        switch action {
        case .applyIntervention:
            pushOverrideUndo()
            systemMapStore.applyIntervention(card: drop.card, targetElementID: drop.targetElementID, scenarioID: scenario.id)
        case .setActive:
            pushOverrideUndo()
            systemMapStore.setCardStatusOverride(
                cardID: drop.card.id, targetElementID: drop.targetElementID,
                scope: drop.scope, status: .active, reason: "", scenarioID: scenario.id
            )
        case .setTargetOnly:
            selection = drop.targetElementID.map { .element($0) } ?? selection
        case .changeTarget:
            pushOverrideUndo()
            if let oldID = drop.otherActiveTargetID {
                systemMapStore.clearCardStatusOverride(cardID: drop.card.id, scope: .thisElementOnly, targetElementID: oldID, scenarioID: scenario.id)
            }
            systemMapStore.setCardStatusOverride(
                cardID: drop.card.id, targetElementID: drop.targetElementID,
                scope: drop.scope, status: .active, reason: "", scenarioID: scenario.id
            )
        case .addAdditionalTarget:
            pushOverrideUndo()
            systemMapStore.setCardStatusOverride(
                cardID: drop.card.id, targetElementID: drop.targetElementID,
                scope: drop.scope, status: .active, reason: "", scenarioID: scenario.id
            )
        case .overrideStatus(let status):
            pushOverrideUndo()
            systemMapStore.setCardStatusOverride(
                cardID: drop.card.id, targetElementID: drop.targetElementID,
                scope: drop.scope, status: status, reason: "", scenarioID: scenario.id
            )
        case .viewDetails:
            showingDetailsFor = drop.card
        }
        pendingDrop = nil
    }
}

// MARK: - Small shared sheets

private struct RenameSheet: View {
    let title: String
    @Binding var name: String
    @Binding var isPresented: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
            TextField("Name", text: $name).arenaFieldStyle()
            HStack {
                Button("Cancel") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onSave(); isPresented = false }
                    .buttonStyle(ArenaButtonStyle(isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .background(AC.bg)
        .colorScheme(.dark)
    }
}

private struct NewScenarioSheet: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NEW SCENARIO").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
            Text("A scenario is a different configuration or condition of this same workflow — e.g. “Supplier Failure” or “High Demand” — not a step in a sequence.")
                .font(.system(size: 10))
                .foregroundStyle(AC.textSub)
            VStack(alignment: .leading, spacing: 4) {
                Text("NAME").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                TextField("e.g. Supplier Failure", text: $name).arenaFieldStyle()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("DESCRIPTION").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                TextField("What conditions define this scenario?", text: $description).arenaFieldStyle()
            }
            HStack {
                Button("Cancel") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { onCreate(); isPresented = false }
                    .buttonStyle(ArenaButtonStyle(isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .background(AC.bg)
        .colorScheme(.dark)
    }
}

// MARK: - Apply Intervention sheet
//
// One of several ways to change a card's status (see SystemCardLibraryView's
// Change Status menu for the purely descriptive path) — this one also lets
// the user attach a note describing the intervention's effect.

private struct ApplyInterventionSheet: View {
    let card: KnowledgeCard
    let targetLabel: String
    let targetKind: SystemTargetKind
    /// Issues this card is explicitly related to as a mitigating/resolving
    /// response, and the status applying it would offer to set them to.
    /// Never auto-applied — the user always confirms or opts out.
    let linkedIssueEffects: [(issue: SystemIssue, resultingStatus: IssueStatus)]
    let onConfirm: (String, [UUID: IssueStatus]) -> Void
    let onCancel: () -> Void

    @State private var notes: String = ""
    @State private var issueToggles: [UUID: Bool] = [:]

    private var softwareFields: SoftwareStrategyFields? {
        if case .softwareStrategy(let f) = card.metadata { return f }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("APPLY INTERVENTION").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(card.kind.arenaColor).kerning(1.5)
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.title).font(.system(size: 16, weight: .bold)).foregroundStyle(AC.text)
                    HStack(spacing: 5) {
                        Image(systemName: "scope").font(.system(size: 9)).foregroundStyle(AC.cyan)
                        Text("Target: \(targetLabel) (\(targetKind.displayName))").font(.system(size: 11)).foregroundStyle(AC.cyan)
                    }
                    if let f = softwareFields {
                        if !f.trigger.isEmpty { detail("When", f.trigger, AC.cyan) }
                        if !f.mechanism.isEmpty { detail("Effect", f.mechanism, card.kind.arenaColor) }
                        if !f.desiredResult.isEmpty { detail("Result", f.desiredResult, AC.available) }
                        if !f.costs.isEmpty { detail("Costs", f.costs.joined(separator: "; "), AC.threat) }
                        if !f.failureModes.isEmpty { detail("Risks", f.failureModes.joined(separator: "; "), .orange) }
                    } else if !card.frontText.isEmpty {
                        detail("Description", card.frontText, card.kind.arenaColor)
                    }
                    if !card.playabilityRules.unlocksCardTitles.isEmpty {
                        detail("Unlocks", card.playabilityRules.unlocksCardTitles.joined(separator: ", "), AC.available)
                    }

                    if !linkedIssueEffects.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("THIS MAY").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.gold).kerning(1)
                            ForEach(linkedIssueEffects, id: \.issue.id) { effect in
                                Toggle(isOn: Binding(
                                    get: { issueToggles[effect.issue.id] ?? true },
                                    set: { issueToggles[effect.issue.id] = $0 }
                                )) {
                                    Text("\(effect.resultingStatus == .resolved ? "Resolve" : "Mark Mitigated"): \(effect.issue.title)")
                                        .font(.system(size: 11)).foregroundStyle(AC.text)
                                }
                                .tint(AC.gold)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTES (OPTIONAL)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                        TextField("What changed as a result?", text: $notes, axis: .vertical).arenaFieldStyle()
                    }
                }
                .padding(14)
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)
            HStack {
                Spacer()
                if !linkedIssueEffects.isEmpty {
                    Button("Apply Without Resolving Issues") {
                        onConfirm(notes, [:])
                    }
                    .buttonStyle(ArenaOutlineButtonStyle())
                }
                Button(action: {
                    let resolutions = linkedIssueEffects.reduce(into: [UUID: IssueStatus]()) { acc, effect in
                        if issueToggles[effect.issue.id] ?? true { acc[effect.issue.id] = effect.resultingStatus }
                    }
                    onConfirm(notes, resolutions)
                }) {
                    Text(card.playabilityRules.exhaustsAfterUse ? "APPLY (WILL EXHAUST)" : "APPLY INTERVENTION")
                }
                .buttonStyle(ArenaButtonStyle(color: card.kind.arenaColor))
            }
            .padding(14)
            .background(AC.surface)
        }
        .background(AC.bg)
        .colorScheme(.dark)
    }

    private func detail(_ label: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(color.opacity(0.8)).kerning(1)
            Text(text).font(.system(size: 11)).foregroundStyle(AC.text)
        }
    }
}

// MARK: - Pending card drop
//
// Dropping a card never changes state by itself — this sheet decides what's
// actually appropriate for the card's *effective* status and only commits
// on explicit confirmation. The same model backs both the drag gesture and
// the click-based "Assign to Selected Element" alternative.

private struct PendingCardDrop: Identifiable {
    let id = UUID()
    let card: KnowledgeCard
    let targetElementID: UUID?
    let targetLabel: String
    let targetKind: SystemTargetKind
    let evaluation: SystemCardEvaluation
    let otherActiveTargetID: UUID?
    let otherActiveTargetLabel: String?

    /// Flow/relationship/background targets have no specific element ID to
    /// scope an override to, so they fall back to the next-narrowest scope.
    var scope: SystemOverrideScope { targetElementID != nil ? .thisElementOnly : .entireScenario }
}

private enum PendingDropAction {
    case applyIntervention
    case setActive
    case setTargetOnly
    case changeTarget
    case addAdditionalTarget
    case overrideStatus(SystemCardStatus)
    case viewDetails
}

private struct PendingCardDropSheet: View {
    let drop: PendingCardDrop
    let onAction: (PendingDropAction) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DROP CARD").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(drop.card.kind.arenaColor).kerning(1.5)
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(drop.card.title).font(.system(size: 16, weight: .bold)).foregroundStyle(AC.text)
                    HStack(spacing: 5) {
                        Image(systemName: "scope").font(.system(size: 9)).foregroundStyle(AC.cyan)
                        Text("Target: \(drop.targetLabel) (\(drop.targetKind.displayName))").font(.system(size: 11)).foregroundStyle(AC.cyan)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: drop.evaluation.effectiveStatus.systemImage).font(.system(size: 9))
                        Text(drop.evaluation.effectiveStatus.displayName.uppercased()).font(.system(size: 10, weight: .black, design: .monospaced)).kerning(0.5)
                    }
                    .foregroundStyle(drop.evaluation.effectiveStatus.arenaColor)

                    statusContent
                }
                .padding(14)
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)
            actionRow
                .padding(14)
                .background(AC.surface)
        }
        .background(AC.bg)
        .colorScheme(.dark)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch drop.evaluation.effectiveStatus {
        case .available, .recommended:
            Text("Apply “\(drop.card.title)” to \(drop.targetLabel)?")
                .font(.system(size: 12)).foregroundStyle(AC.textSub)
        case .active:
            if let otherLabel = drop.otherActiveTargetLabel {
                Text("This card is already Active on \(otherLabel). Changing its target here would remove that association unless you add this as an additional target instead.")
                    .font(.system(size: 12)).foregroundStyle(AC.textSub)
            } else {
                Text("This card is already Active on \(drop.targetLabel).")
                    .font(.system(size: 12)).foregroundStyle(AC.textSub)
            }
        case .locked:
            requirementsList("MISSING", drop.evaluation.missingRequirements, AC.threat)
        case .disabled:
            requirementsList("BLOCKING", drop.evaluation.blockingConditions, AC.threat)
        case .irrelevant:
            let targets = drop.evaluation.validTargetKinds.map(\.displayName).joined(separator: " or ")
            Text("Invalid target — this card can only target \(targets.isEmpty ? "specific element types" : targets).")
                .font(.system(size: 12)).foregroundStyle(AC.threat)
        case .pending:
            Text("This card is playable here but hasn't been marked available. Set it as Active, or make it Available first.")
                .font(.system(size: 12)).foregroundStyle(AC.textSub)
        case .exhausted, .resolved:
            Text("This card is \(drop.evaluation.effectiveStatus.displayName) and won't be replayed automatically.")
                .font(.system(size: 12)).foregroundStyle(AC.textSub)
        }
    }

    private func requirementsList(_ label: String, _ items: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(color).kerning(1)
            if items.isEmpty {
                Text("No further detail available.").font(.system(size: 11)).foregroundStyle(AC.textSub)
            }
            ForEach(items, id: \.self) { item in
                Text("· \(item)").font(.system(size: 11)).foregroundStyle(AC.textSub)
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch drop.evaluation.effectiveStatus {
        case .available, .recommended:
            HStack(spacing: 6) {
                Button("Apply Intervention") { onAction(.applyIntervention) }
                    .buttonStyle(ArenaButtonStyle(color: drop.card.kind.arenaColor))
                Button("Set as Active") { onAction(.setActive) }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
                Button("Set Target Only") { onAction(.setTargetOnly) }
                    .buttonStyle(ArenaOutlineButtonStyle())
            }
        case .active:
            HStack(spacing: 6) {
                if drop.otherActiveTargetLabel != nil {
                    Button("Change Target") { onAction(.changeTarget) }
                        .buttonStyle(ArenaButtonStyle(color: AC.gold))
                    Button("Add As Additional Target") { onAction(.addAdditionalTarget) }
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
                } else {
                    Button("View Details") { onAction(.viewDetails) }
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
                }
            }
        case .locked:
            HStack(spacing: 6) {
                Button("Override as Available") { onAction(.overrideStatus(.available)) }
                    .buttonStyle(ArenaButtonStyle(color: AC.available))
                Button("View Details") { onAction(.viewDetails) }
                    .buttonStyle(ArenaOutlineButtonStyle())
            }
        case .disabled:
            HStack(spacing: 6) {
                Button("Override as Available") { onAction(.overrideStatus(.available)) }
                    .buttonStyle(ArenaButtonStyle(color: AC.available))
                Button("View Details") { onAction(.viewDetails) }
                    .buttonStyle(ArenaOutlineButtonStyle())
            }
        case .irrelevant:
            HStack(spacing: 6) {
                Button("Override Relevance → Available") { onAction(.overrideStatus(.available)) }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.threat.opacity(0.5)))
            }
        case .pending:
            HStack(spacing: 6) {
                Button("Mark as Available") { onAction(.overrideStatus(.available)) }
                    .buttonStyle(ArenaButtonStyle(color: AC.available))
                Button("Set as Active") { onAction(.setActive) }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
                Button("View Details") { onAction(.viewDetails) }
                    .buttonStyle(ArenaOutlineButtonStyle())
            }
        case .exhausted, .resolved:
            HStack(spacing: 6) {
                Button("View Details") { onAction(.viewDetails) }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
                Button("Reset to Available") { onAction(.overrideStatus(.available)) }
                    .buttonStyle(ArenaOutlineButtonStyle())
            }
        }
    }
}

// MARK: - Scenario comparison sheet

private struct ScenarioComparisonSheet: View {
    let map: SystemMap
    let allCards: [KnowledgeCard]
    @Binding var isPresented: Bool

    @State private var scenarioAID: UUID?
    @State private var scenarioBID: UUID?

    private var scenarioA: SystemScenario? {
        map.scenarios.first(where: { $0.id == scenarioAID }) ?? map.sortedScenarios.first
    }
    private var scenarioB: SystemScenario? {
        let fallback = map.sortedScenarios.dropFirst().first?.id ?? map.sortedScenarios.first?.id
        return map.scenarios.first(where: { $0.id == scenarioBID }) ?? map.scenarios.first(where: { $0.id == fallback })
    }

    private struct CardDiff: Identifiable {
        let id: UUID
        let title: String
        let statusA: SystemCardStatus
        let statusB: SystemCardStatus
    }

    private struct StockDiff: Identifiable {
        let id: UUID
        let name: String
        let valueA: Double?
        let valueB: Double?
        let unit: String
    }

    private var cardDiffs: [CardDiff] {
        guard let scenarioA, let scenarioB, scenarioA.id != scenarioB.id else { return [] }
        let evalA = SystemMapEvaluator.evaluateAll(cards: allCards, map: map, scenario: scenarioA, selectedTargetKind: nil, selectedElementID: nil)
        let evalB = SystemMapEvaluator.evaluateAll(cards: allCards, map: map, scenario: scenarioB, selectedTargetKind: nil, selectedElementID: nil)
        let byIDB = Dictionary(uniqueKeysWithValues: evalB.map { ($0.cardID, $0) })
        return evalA.compactMap { a in
            guard let b = byIDB[a.cardID], a.effectiveStatus != b.effectiveStatus else { return nil }
            guard let card = allCards.first(where: { $0.id == a.cardID }) else { return nil }
            return CardDiff(id: card.id, title: card.title, statusA: a.effectiveStatus, statusB: b.effectiveStatus)
        }.sorted { $0.title < $1.title }
    }

    private var stockDiffs: [StockDiff] {
        guard let scenarioA, let scenarioB, scenarioA.id != scenarioB.id else { return [] }
        let effectiveA = map.effectiveElements(for: scenarioA)
        let effectiveB = map.effectiveElements(for: scenarioB)
        let byIDB = Dictionary(uniqueKeysWithValues: effectiveB.map { ($0.id, $0) })
        return effectiveA.filter { $0.kind == .stock }.compactMap { a in
            guard let b = byIDB[a.id], a.currentValue != b.currentValue else { return nil }
            return StockDiff(id: a.id, name: a.name, valueA: a.currentValue, valueB: b.currentValue, unit: a.unit)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMPARE SCENARIOS").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1.5)
                Spacer()
                Button("Done") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            HStack(spacing: 10) {
                scenarioPicker("Scenario A", selection: Binding(get: { scenarioA?.id }, set: { scenarioAID = $0 }))
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 11)).foregroundStyle(AC.textDim)
                scenarioPicker("Scenario B", selection: Binding(get: { scenarioB?.id }, set: { scenarioBID = $0 }))
            }
            .padding(14)

            if scenarioA?.id == scenarioB?.id {
                Text("Choose two different scenarios to compare.")
                    .font(.system(size: 11))
                    .foregroundStyle(AC.textSub)
                    .padding(.horizontal, 14)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !stockDiffs.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ArenaSectionLabel(text: "Stock Value Differences", color: AC.cyan)
                                ForEach(stockDiffs) { diff in
                                    HStack {
                                        Text(diff.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.text)
                                        Spacer()
                                        Text("\(formatted(diff.valueA)) \(diff.unit) → \(formatted(diff.valueB)) \(diff.unit)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(AC.textSub)
                                    }
                                    .padding(8)
                                    .background(AngularCardShape(cornerRadius: 6, cornerCut: 9).fill(AC.surface))
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ArenaSectionLabel(text: "Card Status Differences (\(cardDiffs.count))", color: AC.gold)
                            if cardDiffs.isEmpty {
                                Text("No card status differences between these two scenarios.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AC.textSub)
                            }
                            ForEach(cardDiffs) { diff in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(diff.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.text)
                                    HStack(spacing: 6) {
                                        statusChip(diff.statusA, label: scenarioA?.name ?? "A")
                                        Image(systemName: "arrow.right").font(.system(size: 8)).foregroundStyle(AC.textDim)
                                        statusChip(diff.statusB, label: scenarioB?.name ?? "B")
                                    }
                                }
                                .padding(9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AngularCardShape(cornerRadius: 6, cornerCut: 9).fill(AC.surface))
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
    }

    private func scenarioPicker(_ label: String, selection: Binding<UUID?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim)
            Picker(label, selection: selection) {
                ForEach(map.sortedScenarios) { s in Text(s.name).tag(Optional(s.id)) }
            }
            .pickerStyle(.menu)
            .tint(AC.cyan)
            .labelsHidden()
        }
    }

    private func statusChip(_ status: SystemCardStatus, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased()).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(AC.textDim)
            Text(status.displayName.uppercased()).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(status.arenaColor)
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Edit deck sheet
//
// Reuses the existing Library-tab deck/suit manager verbatim rather than
// building a Systems Map–specific deck editor.

private struct EditDeckSheet: View {
    let deckID: String
    let decks: [KnowledgeDeck]
    @Binding var isPresented: Bool
    @EnvironmentObject var cardStore: CardStore

    @State private var selectedDeckID: String?
    @State private var selectedSuiteID: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EDIT DECK").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1.5)
                Spacer()
                Button("Done") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            DeckSuitTreeView(
                decks: decks.filter { $0.id == deckID },
                suits: cardStore.suits,
                selectedDeckID: $selectedDeckID,
                selectedSuiteID: $selectedSuiteID
            )
        }
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear { selectedDeckID = deckID }
    }
}
