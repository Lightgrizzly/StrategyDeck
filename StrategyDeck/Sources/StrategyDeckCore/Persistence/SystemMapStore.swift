import Foundation

@MainActor
public final class SystemMapStore: ObservableObject {
    @Published public private(set) var systemMaps: [SystemMap] = []
    @Published public var currentSystemMap: SystemMap?
    @Published public var lastError: Error?

    private let persistence: PersistenceService
    private static let filename = "systemmaps.json"

    public init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    public func load() {
        guard persistence.fileExists(Self.filename) else { return }
        do {
            systemMaps = try persistence.load([SystemMap].self, from: Self.filename)
        } catch {
            lastError = error
        }
    }

    // MARK: - Map lifecycle

    public func createSystemMap(title: String, description: String = "", primaryGoal: String = "") {
        var map = SystemMap(title: title, description: description, primaryGoal: primaryGoal)
        let defaultScenario = SystemScenario(name: "Current State", isDefault: true)
        map.scenarios = [defaultScenario]
        map.selectedScenarioID = defaultScenario.id
        systemMaps.insert(map, at: 0)
        currentSystemMap = map
        persist()
    }

    /// Inserts an already-built map (e.g. a template) and opens it.
    public func addAndOpen(_ map: SystemMap) {
        systemMaps.insert(map, at: 0)
        currentSystemMap = map
        persist()
    }

    public func openSystemMap(id: UUID) {
        guard let map = systemMaps.first(where: { $0.id == id }) else { return }
        currentSystemMap = map
    }

    public func closeCurrentSystemMap() {
        currentSystemMap = nil
    }

    public func deleteSystemMap(id: UUID) {
        systemMaps.removeAll { $0.id == id }
        if currentSystemMap?.id == id { currentSystemMap = nil }
        persist()
    }

    public func duplicateSystemMap(id: UUID) {
        guard let map = systemMaps.first(where: { $0.id == id }) else { return }
        var copy = map
        copy.id = UUID()
        copy.title = map.title + " Copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        systemMaps.insert(copy, at: 0)
        persist()
    }

    public func renameSystemMap(id: UUID, title: String) {
        guard let idx = systemMaps.firstIndex(where: { $0.id == id }) else { return }
        systemMaps[idx].title = title
        systemMaps[idx].updatedAt = Date()
        if currentSystemMap?.id == id { currentSystemMap?.title = title }
        persist()
    }

    public func updateCurrentSystemMap(_ update: (inout SystemMap) -> Void) {
        guard var map = currentSystemMap else { return }
        update(&map)
        map.updatedAt = Date()
        currentSystemMap = map
        if let idx = systemMaps.firstIndex(where: { $0.id == map.id }) {
            systemMaps[idx] = map
        } else {
            systemMaps.insert(map, at: 0)
        }
        persist()
    }

    // MARK: - Scenario management
    //
    // A scenario is a different configuration of the same shared workflow —
    // not a step in a sequence. There is always at least one scenario once
    // a map has been created; `deleteScenario` refuses to remove the last one.

    public func createScenario(name: String, description: String = "") {
        updateCurrentSystemMap { map in
            let newOrder = (map.scenarios.map(\.order).max() ?? -1) + 1
            let scenario = SystemScenario(name: name, description: description, isDefault: map.scenarios.isEmpty, order: newOrder)
            map.scenarios.append(scenario)
            map.selectedScenarioID = scenario.id
        }
    }

    public func duplicateScenario(id: UUID) {
        updateCurrentSystemMap { map in
            guard let original = map.scenarios.first(where: { $0.id == id }) else { return }
            var copy = original
            copy.id = UUID()
            copy.name = original.name + " Copy"
            copy.isDefault = false
            copy.order = (map.scenarios.map(\.order).max() ?? -1) + 1
            copy.createdAt = Date()
            copy.updatedAt = Date()
            map.scenarios.append(copy)
            map.selectedScenarioID = copy.id
        }
    }

    public func renameScenario(id: UUID, name: String) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == id }) else { return }
            map.scenarios[idx].name = name
            map.scenarios[idx].updatedAt = Date()
        }
    }

    public func setScenarioDescription(id: UUID, description: String) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == id }) else { return }
            map.scenarios[idx].description = description
            map.scenarios[idx].updatedAt = Date()
        }
    }

    public func deleteScenario(id: UUID) {
        updateCurrentSystemMap { map in
            guard map.scenarios.count > 1 else { return }
            let wasDefault = map.scenarios.first(where: { $0.id == id })?.isDefault ?? false
            map.scenarios.removeAll { $0.id == id }
            if wasDefault, let firstIdx = map.scenarios.indices.first {
                map.scenarios[firstIdx].isDefault = true
            }
            if map.selectedScenarioID == id {
                map.selectedScenarioID = map.scenarios.first(where: { $0.isDefault })?.id ?? map.scenarios.first?.id
            }
        }
    }

    public func setDefaultScenario(id: UUID) {
        updateCurrentSystemMap { map in
            for idx in map.scenarios.indices {
                map.scenarios[idx].isDefault = (map.scenarios[idx].id == id)
            }
        }
    }

    public func selectScenario(id: UUID) {
        updateCurrentSystemMap { map in
            map.selectedScenarioID = id
        }
    }

    /// Clears all overrides for a scenario, returning it to the shared base
    /// workflow state, while keeping its name/description/position.
    public func resetScenario(id: UUID) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == id }) else { return }
            let existing = map.scenarios[idx]
            map.scenarios[idx] = SystemScenario(
                id: id,
                name: existing.name,
                description: existing.description,
                isDefault: existing.isDefault,
                order: existing.order
            )
        }
    }

    /// Moves a scenario earlier (-1) or later (+1) in display order.
    public func moveScenario(id: UUID, direction: Int) {
        updateCurrentSystemMap { map in
            var sorted = map.sortedScenarios
            guard let idx = sorted.firstIndex(where: { $0.id == id }) else { return }
            let newIdx = idx + direction
            guard sorted.indices.contains(newIdx) else { return }
            sorted.swapAt(idx, newIdx)
            for (order, scenario) in sorted.enumerated() {
                if let mapIdx = map.scenarios.firstIndex(where: { $0.id == scenario.id }) {
                    map.scenarios[mapIdx].order = order
                }
            }
        }
    }

    /// Records which element is selected within the currently selected
    /// scenario — each scenario remembers its own last selection.
    public func selectElement(id: UUID?) {
        updateCurrentSystemMap { map in
            guard let scenarioID = map.selectedScenarioID,
                  let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
            map.scenarios[idx].selectedElementID = id
        }
    }

    // MARK: - Deck selection
    //
    // The default deck belongs to the whole map; a scenario may override it.
    // Pass `nil` to mean "All Cards" (map default) or "inherit the map's
    // default deck" (scenario override).

    public func setDefaultDeck(_ deckID: String?) {
        updateCurrentSystemMap { $0.defaultDeckID = deckID }
    }

    public func setScenarioDeckOverride(scenarioID: UUID, deckID: String?) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
            map.scenarios[idx].deckOverrideID = deckID
            map.scenarios[idx].updatedAt = Date()
        }
    }

    // MARK: - Shared structure editing
    //
    // These edit the base workflow directly, so changes are visible in
    // every scenario — "editing shared workflow structure," distinct from
    // the scenario-scoped overrides below.

    public func addElement(_ element: SystemElement) {
        updateCurrentSystemMap { $0.elements.append(element) }
    }

    public func updateElement(_ element: SystemElement) {
        updateCurrentSystemMap { map in
            if let idx = map.elements.firstIndex(where: { $0.id == element.id }) {
                map.elements[idx] = element
            }
        }
    }

    public func deleteElement(id: UUID) {
        updateCurrentSystemMap { map in
            map.elements.removeAll { $0.id == id }
            map.flows.removeAll { $0.sourceElementID == id || $0.targetElementID == id }
            map.relationships.removeAll { $0.sourceElementID == id || $0.targetElementID == id }
            for idx in map.scenarios.indices {
                map.scenarios[idx].elementOverrides.removeValue(forKey: id)
                if map.scenarios[idx].selectedElementID == id {
                    map.scenarios[idx].selectedElementID = nil
                }
            }
        }
    }

    public func addFlow(_ flow: SystemFlow) {
        updateCurrentSystemMap { $0.flows.append(flow) }
    }

    public func updateFlow(_ flow: SystemFlow) {
        updateCurrentSystemMap { map in
            if let idx = map.flows.firstIndex(where: { $0.id == flow.id }) {
                map.flows[idx] = flow
            }
        }
    }

    public func deleteFlow(id: UUID) {
        updateCurrentSystemMap { map in
            map.flows.removeAll { $0.id == id }
            for idx in map.scenarios.indices {
                map.scenarios[idx].flowOverrides.removeValue(forKey: id)
            }
        }
    }

    public func addRelationship(_ relationship: SystemRelationship) {
        updateCurrentSystemMap { $0.relationships.append(relationship) }
    }

    public func deleteRelationship(id: UUID) {
        updateCurrentSystemMap { map in
            map.relationships.removeAll { $0.id == id }
            for idx in map.scenarios.indices {
                map.scenarios[idx].relationshipStates.removeValue(forKey: id)
            }
        }
    }

    /// Wholesale replace of the shared diagram — used by the editor's
    /// session-scoped undo/redo stack to restore a prior snapshot.
    public func replaceDiagram(elements: [SystemElement], flows: [SystemFlow], relationships: [SystemRelationship]) {
        updateCurrentSystemMap { map in
            map.elements = elements
            map.flows = flows
            map.relationships = relationships
        }
    }

    /// Wholesale replace of one scenario by ID — the override-state
    /// counterpart to `replaceDiagram`, so undo/redo can restore a card
    /// status override, target assignment, or deck-override change in one
    /// step alongside any diagram change from the same user action.
    public func restoreScenario(_ scenario: SystemScenario) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == scenario.id }) else { return }
            map.scenarios[idx] = scenario
        }
    }

    // MARK: - Scenario-scoped overrides
    //
    // These edit only the selected scenario — "editing the currently
    // selected scenario," distinct from the shared structure above.

    public func setElementOverride(elementID: UUID, currentValue: Double?, state: SystemElementState?, notes: String?, inScenario scenarioID: UUID) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
            map.scenarios[idx].elementOverrides[elementID] = SystemElementOverride(currentValue: currentValue, state: state, notes: notes)
            map.scenarios[idx].updatedAt = Date()
        }
    }

    public func setFlowOverride(flowID: UUID, rate: Double?, isEnabled: Bool?, state: SystemElementState?, inScenario scenarioID: UUID) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
            map.scenarios[idx].flowOverrides[flowID] = SystemFlowOverride(rate: rate, isEnabled: isEnabled, state: state)
            map.scenarios[idx].updatedAt = Date()
        }
    }

    public func setKnownInformation(_ text: String, inScenario scenarioID: UUID) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
            map.scenarios[idx].knownInformation = text
            map.scenarios[idx].updatedAt = Date()
        }
    }

    public func setUnknownInformation(_ text: String, inScenario scenarioID: UUID) {
        updateCurrentSystemMap { map in
            guard let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
            map.scenarios[idx].unknownInformation = text
            map.scenarios[idx].updatedAt = Date()
        }
    }

    // MARK: - Card status overrides
    //
    // The mechanism behind both "Change Status" (descriptive) and "Apply
    // Intervention" (interventional) — both end up recording the same kind
    // of override; only the reason text and default status differ.

    /// Sets (replacing any existing override with the same card/scope/target)
    /// a manual status override. Pass `scope: .workflowDefault` to apply it
    /// across every scenario for this map.
    public func setCardStatusOverride(
        cardID: UUID,
        targetElementID: UUID?,
        scope: SystemOverrideScope,
        status: SystemCardStatus,
        customStatusID: String? = nil,
        reason: String,
        scenarioID: UUID
    ) {
        let resolvedTargetID = scope == .thisElementOnly ? targetElementID : nil
        let newOverride = SystemCardStatusOverride(
            cardID: cardID,
            targetElementID: resolvedTargetID,
            scope: scope,
            overriddenStatus: status,
            customStatusID: customStatusID,
            reason: reason
        )
        updateCurrentSystemMap { map in
            if scope == .workflowDefault {
                map.workflowDefaultOverrides.removeAll { $0.cardID == cardID && $0.scope == .workflowDefault }
                map.workflowDefaultOverrides.append(newOverride)
            } else {
                guard let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
                map.scenarios[idx].cardStatusOverrides.removeAll {
                    $0.cardID == cardID && $0.scope == scope && $0.targetElementID == resolvedTargetID
                }
                map.scenarios[idx].cardStatusOverrides.append(newOverride)
                map.scenarios[idx].updatedAt = Date()
            }
        }
    }

    public func clearCardStatusOverride(cardID: UUID, scope: SystemOverrideScope, targetElementID: UUID?, scenarioID: UUID) {
        updateCurrentSystemMap { map in
            if scope == .workflowDefault {
                map.workflowDefaultOverrides.removeAll { $0.cardID == cardID && $0.scope == .workflowDefault }
            } else if let idx = map.scenarios.firstIndex(where: { $0.id == scenarioID }) {
                map.scenarios[idx].cardStatusOverrides.removeAll {
                    $0.cardID == cardID && $0.scope == scope && $0.targetElementID == targetElementID
                }
                map.scenarios[idx].updatedAt = Date()
            }
        }
    }

    // MARK: - Status customization
    //
    // A custom status doesn't invent new behavior — it wears a custom
    // name/icon/color over one of the existing built-in behaviors
    // (`behavesLike`), so playability/drag-and-drop/status-menu logic never
    // needs to know a status is custom.

    @discardableResult
    public func createCustomStatus(
        name: String,
        iconName: String = "tag.fill",
        colorToken: StatusColorToken = .cyan,
        behavesLike: SystemCardStatus = .available
    ) -> CustomCardStatus {
        var created = CustomCardStatus(name: name, iconName: iconName, colorToken: colorToken, behavesLike: behavesLike)
        updateCurrentSystemMap { map in
            let order = (map.customStatuses.map(\.displayOrder).max() ?? -1) + 1
            created.displayOrder = order
            map.customStatuses.append(created)
        }
        return created
    }

    public func updateCustomStatus(_ status: CustomCardStatus) {
        updateCurrentSystemMap { map in
            guard let idx = map.customStatuses.firstIndex(where: { $0.id == status.id }) else { return }
            map.customStatuses[idx] = status
        }
    }

    /// Deletes a custom status. Any override referencing it keeps behaving
    /// exactly as it did (its `overriddenStatus` is untouched) — it just
    /// loses its custom label/color and displays as the built-in status it
    /// was already behaving like.
    public func deleteCustomStatus(id: String) {
        updateCurrentSystemMap { map in
            map.customStatuses.removeAll { $0.id == id }
            for i in map.scenarios.indices {
                for j in map.scenarios[i].cardStatusOverrides.indices where map.scenarios[i].cardStatusOverrides[j].customStatusID == id {
                    map.scenarios[i].cardStatusOverrides[j].customStatusID = nil
                }
            }
            for i in map.workflowDefaultOverrides.indices where map.workflowDefaultOverrides[i].customStatusID == id {
                map.workflowDefaultOverrides[i].customStatusID = nil
            }
        }
    }

    /// Renames a built-in status's display label. `nil` or blank clears
    /// the override, restoring the default label.
    public func setStatusLabel(for status: SystemCardStatus, label: String?) {
        updateCurrentSystemMap { map in
            let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                map.statusLabelOverrides.removeValue(forKey: status.rawValue)
            } else {
                map.statusLabelOverrides[status.rawValue] = trimmed
            }
        }
    }

    /// "Apply Intervention" — the interventional counterpart to manually
    /// describing a card's status: records that the card has been applied
    /// (Active, or Exhausted for single-use cards), scoped to the selected
    /// element by default.
    public func applyIntervention(card: KnowledgeCard, targetElementID: UUID?, scenarioID: UUID, notes: String = "") {
        let status: SystemCardStatus = card.playabilityRules.exhaustsAfterUse ? .exhausted : .active
        setCardStatusOverride(
            cardID: card.id,
            targetElementID: targetElementID,
            scope: .thisElementOnly,
            status: status,
            reason: notes,
            scenarioID: scenarioID
        )
    }

    // MARK: - Private

    private func persist() {
        do {
            try persistence.save(systemMaps, to: Self.filename)
        } catch {
            lastError = error
        }
    }
}
