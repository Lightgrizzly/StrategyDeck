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
        let firstStep = SystemStep(index: 0, title: "Step 1")
        var map = SystemMap(title: title, description: description, primaryGoal: primaryGoal)
        map.steps = [firstStep]
        map.currentStepID = firstStep.id
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

    // MARK: - Step navigation

    /// Selects a step for viewing. Diagram edits and card plays always apply
    /// to the latest step regardless of which step is being viewed — an
    /// older step is a read-only history view in this first implementation.
    public func setCurrentStep(id: UUID) {
        updateCurrentSystemMap { map in
            map.currentStepID = id
        }
    }

    public func returnToLatestStep() {
        updateCurrentSystemMap { map in
            map.currentStepID = map.latestStep?.id
        }
    }

    public func selectElement(id: UUID?, inStep stepID: UUID) {
        updateCurrentSystemMap { map in
            guard let idx = map.steps.firstIndex(where: { $0.id == stepID }) else { return }
            map.steps[idx].selectedElementID = id
        }
    }

    /// "Next Step" — duplicates the latest step forward and selects it,
    /// mirroring `DuelStore.addStep`.
    public func addStep(title: String = "") {
        updateCurrentSystemMap { map in
            let sorted = map.sortedSteps
            guard let last = sorted.last else { return }
            var next = last.duplicated(index: last.index + 1)
            next.title = title
            map.steps.append(next)
            map.currentStepID = next.id
        }
    }

    // MARK: - Diagram editing (always targets the latest step)

    public func addElement(_ element: SystemElement) {
        mutateLatestStep { $0.elements.append(element) }
    }

    public func updateElement(_ element: SystemElement) {
        mutateLatestStep { step in
            if let idx = step.elements.firstIndex(where: { $0.id == element.id }) {
                step.elements[idx] = element
            }
        }
    }

    public func deleteElement(id: UUID) {
        mutateLatestStep { step in
            step.elements.removeAll { $0.id == id }
            step.flows.removeAll { $0.sourceElementID == id || $0.targetElementID == id }
            step.relationships.removeAll { $0.sourceElementID == id || $0.targetElementID == id }
            if step.selectedElementID == id { step.selectedElementID = nil }
        }
    }

    public func addFlow(_ flow: SystemFlow) {
        mutateLatestStep { $0.flows.append(flow) }
    }

    public func updateFlow(_ flow: SystemFlow) {
        mutateLatestStep { step in
            if let idx = step.flows.firstIndex(where: { $0.id == flow.id }) {
                step.flows[idx] = flow
            }
        }
    }

    public func deleteFlow(id: UUID) {
        mutateLatestStep { $0.flows.removeAll { $0.id == id } }
    }

    public func addRelationship(_ relationship: SystemRelationship) {
        mutateLatestStep { $0.relationships.append(relationship) }
    }

    public func deleteRelationship(id: UUID) {
        mutateLatestStep { $0.relationships.removeAll { $0.id == id } }
    }

    /// Wholesale replace of the latest step's diagram — used by the canvas's
    /// session-scoped undo/redo stack to restore a prior snapshot.
    public func replaceLatestStepDiagram(elements: [SystemElement], flows: [SystemFlow], relationships: [SystemRelationship]) {
        mutateLatestStep { step in
            step.elements = elements
            step.flows = flows
            step.relationships = relationships
        }
    }

    public func setKnownInformation(_ text: String) {
        mutateLatestStep { $0.knownInformation = text }
    }

    public func setUnknownInformation(_ text: String) {
        mutateLatestStep { $0.unknownInformation = text }
    }

    // MARK: - Card plays

    /// Applies a card to a target, records the play in the latest step's
    /// ledger, recalculates every other card's status before/after, and
    /// records a "Changes This Step" summary. Reuses `SystemMapEvaluator`
    /// (which itself reuses `PlayabilityEvaluator`) so this is the same rule
    /// engine the Duel Board uses.
    public func playCard(card: KnowledgeCard, targetElementID: UUID?, targetKind: SystemTargetKind, allCards: [KnowledgeCard], notes: String = "") {
        guard let map = currentSystemMap, let latest = map.latestStep else { return }

        let before = SystemMapEvaluator.evaluateAll(cards: allCards, step: latest, selectedTargetKind: nil)
        let beforeByID = Dictionary(uniqueKeysWithValues: before.map { ($0.cardID, $0.status) })

        mutateLatestStep { step in
            let status: SystemCardPlayStatus = card.playabilityRules.exhaustsAfterUse ? .exhausted : .active
            let play = SystemCardPlay(
                cardID: card.id,
                targetElementID: targetElementID,
                targetKind: targetKind,
                status: status,
                playedAtStepIndex: step.index,
                notes: notes
            )
            step.cardPlays.append(play)
            step.changes.append(SystemChangeEntry(
                kind: .cardPlayed,
                label: "\(card.title) played",
                relatedElementID: targetElementID,
                relatedCardID: card.id
            ))
            step.changes.append(SystemChangeEntry(
                kind: status == .exhausted ? .cardBecameExhausted : .cardBecameActive,
                label: "\(card.title) is now \(status == .exhausted ? "exhausted" : "active")",
                relatedCardID: card.id
            ))
        }

        guard let updatedMap = currentSystemMap, let updatedLatest = updatedMap.latestStep else { return }
        let after = SystemMapEvaluator.evaluateAll(cards: allCards, step: updatedLatest, selectedTargetKind: nil)

        var unlocked = 0
        var newlyDisabled = 0
        var extraChanges: [SystemChangeEntry] = []
        for evaluation in after {
            guard let previous = beforeByID[evaluation.cardID], previous != evaluation.status else { continue }
            let becameAvailable = (evaluation.status == .available || evaluation.status == .recommended)
                && (previous == .locked || previous == .disabled)
            let becameLockedOrDisabled = (evaluation.status == .locked || evaluation.status == .disabled)
                && (previous == .available || previous == .recommended)
            if becameAvailable {
                unlocked += 1
                if let unlockedCard = allCards.first(where: { $0.id == evaluation.cardID }) {
                    extraChanges.append(SystemChangeEntry(
                        kind: .cardBecameAvailable,
                        label: "\(unlockedCard.title) unlocked",
                        relatedCardID: unlockedCard.id
                    ))
                }
            } else if becameLockedOrDisabled {
                newlyDisabled += 1
                if let blockedCard = allCards.first(where: { $0.id == evaluation.cardID }) {
                    extraChanges.append(SystemChangeEntry(
                        kind: evaluation.status == .disabled ? .cardBecameDisabled : .cardBecameLocked,
                        label: "\(blockedCard.title) now \(evaluation.status.displayName.lowercased())",
                        relatedCardID: blockedCard.id
                    ))
                }
            }
        }

        if !extraChanges.isEmpty {
            mutateLatestStep { step in
                step.changes.append(contentsOf: extraChanges)
            }
        }
        _ = (unlocked, newlyDisabled) // surfaced to the UI via step.changes
    }

    public func resolveCardPlay(playID: UUID, cardTitle: String) {
        mutateLatestStep { step in
            guard let idx = step.cardPlays.firstIndex(where: { $0.id == playID }) else { return }
            step.cardPlays[idx].status = .resolved
            step.changes.append(SystemChangeEntry(
                kind: .cardResolved,
                label: "\(cardTitle) resolved",
                relatedCardID: step.cardPlays[idx].cardID
            ))
        }
    }

    public func setManualOverride(cardID: UUID, status: SystemCardStatus?) {
        mutateLatestStep { step in
            if let status {
                step.manualStatusOverrides[cardID] = status
            } else {
                step.manualStatusOverrides.removeValue(forKey: cardID)
            }
        }
    }

    // MARK: - Private

    private func mutateLatestStep(_ mutate: (inout SystemStep) -> Void) {
        updateCurrentSystemMap { map in
            guard let idx = map.steps.indices.max(by: { map.steps[$0].index < map.steps[$1].index }) else { return }
            mutate(&map.steps[idx])
        }
    }

    private func persist() {
        do {
            try persistence.save(systemMaps, to: Self.filename)
        } catch {
            lastError = error
        }
    }
}
