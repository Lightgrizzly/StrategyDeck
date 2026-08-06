import Foundation

/// Deterministic, UI-free rule evaluation for the Systems Map. Deliberately
/// thin: it builds a ``PlayabilityContext`` from the selected scenario's
/// state and delegates the actual rule logic to ``PlayabilityEvaluator``,
/// the same evaluator the Duel Board uses — so a card's prerequisites,
/// blockers, and unlock relationships behave identically everywhere in the
/// app.
///
/// Card status depends on the **selected element** and the **selected
/// scenario** — never on a chronological step. Selecting a different
/// element or switching scenarios immediately changes every card's status;
/// nothing here depends on "having advanced far enough."
public struct SystemMapEvaluator: Sendable {

    /// Maps a diagram element's kind to the broader target-kind vocabulary
    /// cards can declare (which also includes flow/relationship/system).
    public static func targetKind(for elementKind: SystemElementKind) -> SystemTargetKind {
        switch elementKind {
        case .stock: return .stock
        case .delay: return .delay
        case .constraint: return .constraint
        case .goal: return .goal
        case .note: return .note
        }
    }

    /// Builds the shared evaluation context from a scenario's state — the
    /// bridge between Systems Map state and the app-wide card rule engine.
    /// Scans every override in the scenario (regardless of scope) plus the
    /// map's workflow-default overrides: whether a card counts as
    /// active/resolved/played for *other* cards' prerequisite checks is a
    /// scenario-wide fact, independent of which element is selected right now.
    public static func context(for scenario: SystemScenario, map: SystemMap, allCards: [KnowledgeCard]) -> PlayabilityContext {
        let cardsByID = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
        let allOverrides = scenario.cardStatusOverrides + map.workflowDefaultOverrides

        let activeTitles = Set(allOverrides.filter { $0.overriddenStatus == .active }.compactMap { cardsByID[$0.cardID]?.title })
        let resolvedTitles = Set(allOverrides.filter { $0.overriddenStatus == .resolved }.compactMap { cardsByID[$0.cardID]?.title })
        let playedTitles = Set(allOverrides.compactMap { cardsByID[$0.cardID]?.title })
        let inPlayTitles = activeTitles.union(resolvedTitles).union(playedTitles)

        var reciprocalUnlocks: [String: Set<String>] = [:]
        for card in allCards where inPlayTitles.contains(card.title) {
            for unlocked in card.playabilityRules.unlocksCardTitles {
                reciprocalUnlocks[unlocked, default: []].insert(card.title)
            }
        }

        let constraintDescriptions = map.effectiveElements(for: scenario)
            .filter { $0.kind == .constraint }
            .map { $0.description.isEmpty ? $0.name : $0.description }
            .joined(separator: ". ")

        return PlayabilityContext(
            activeCardTitles: activeTitles,
            resolvedCardTitles: resolvedTitles,
            playedCardTitles: playedTitles,
            knownInformation: scenario.knownInformation,
            constraints: constraintDescriptions,
            reciprocalUnlocks: reciprocalUnlocks
        )
    }

    /// Evaluates a single card against the selected scenario, optionally
    /// scoped to a selected diagram element, flow, or relationship. Pass
    /// `nil` for "nothing selected" / "entire system."
    public static func evaluate(
        card: KnowledgeCard,
        map: SystemMap,
        scenario: SystemScenario,
        selectedTargetKind: SystemTargetKind?,
        selectedElementID: UUID?,
        allCards: [KnowledgeCard]
    ) -> SystemCardEvaluation {
        let context = context(for: scenario, map: map, allCards: allCards)
        let result = PlayabilityEvaluator.evaluate(card: card, context: context)
        let rules = card.playabilityRules
        let declaresTargets = !rules.systemTargetTypes.isEmpty
        let isRelevant = selectedTargetKind == nil || !declaresTargets || rules.systemTargetTypes.contains(selectedTargetKind!)

        let automaticStatus: SystemCardStatus
        if !isRelevant {
            automaticStatus = .irrelevant
        } else if result.isPlayable {
            let isRecommended = selectedTargetKind != nil && declaresTargets && rules.systemTargetTypes.contains(selectedTargetKind!)
            // A card that explicitly declares this target type is a strong
            // enough signal to surface as Recommended automatically. A
            // plain playable card with no such signal defaults to Pending
            // instead of Available — availability is something the user
            // chooses (via override), not something every rule-less card
            // gets by default, so the Available group doesn't fill up with
            // every card in the deck.
            automaticStatus = isRecommended ? .recommended : .pending
        } else {
            automaticStatus = result.blockingCards.isEmpty ? .locked : .disabled
        }

        let override = matchingOverride(
            cardID: card.id,
            scenario: scenario,
            map: map,
            selectedElementID: selectedElementID,
            selectedTargetKind: selectedTargetKind,
            validTargetKinds: rules.systemTargetTypes
        )
        let effectiveStatus = override?.overriddenStatus ?? automaticStatus

        let automaticExplanation = explanationText(
            status: automaticStatus,
            card: card,
            result: result,
            selectedTargetKind: selectedTargetKind
        )

        return SystemCardEvaluation(
            cardID: card.id,
            automaticStatus: automaticStatus,
            effectiveStatus: effectiveStatus,
            isOverridden: override != nil,
            overrideReason: override?.reason,
            overrideScope: override?.scope,
            relevance: isRelevant,
            validTargetKinds: rules.systemTargetTypes,
            satisfiedRequirements: result.availableReasons,
            missingRequirements: result.blockedReasons,
            blockingConditions: result.blockingCards,
            unlockSuggestions: result.unlockingCards,
            automaticExplanation: automaticExplanation
        )
    }

    public static func evaluateAll(
        cards: [KnowledgeCard],
        map: SystemMap,
        scenario: SystemScenario,
        selectedTargetKind: SystemTargetKind?,
        selectedElementID: UUID?
    ) -> [SystemCardEvaluation] {
        cards.map {
            evaluate(
                card: $0,
                map: map,
                scenario: scenario,
                selectedTargetKind: selectedTargetKind,
                selectedElementID: selectedElementID,
                allCards: cards
            )
        }
    }

    // MARK: - Override resolution

    /// Narrowest-scope-wins lookup: an element-specific override beats a
    /// scenario-wide one, which beats a workflow-wide default.
    private static func matchingOverride(
        cardID: UUID,
        scenario: SystemScenario,
        map: SystemMap,
        selectedElementID: UUID?,
        selectedTargetKind: SystemTargetKind?,
        validTargetKinds: [SystemTargetKind]
    ) -> SystemCardStatusOverride? {
        let candidates = scenario.cardStatusOverrides.filter { $0.cardID == cardID }

        if let selectedElementID,
           let match = candidates.first(where: { $0.scope == .thisElementOnly && $0.targetElementID == selectedElementID }) {
            return match
        }
        if let selectedTargetKind,
           validTargetKinds.isEmpty || validTargetKinds.contains(selectedTargetKind),
           let match = candidates.first(where: { $0.scope == .allCompatibleElementsInScenario }) {
            return match
        }
        if let match = candidates.first(where: { $0.scope == .entireScenario }) {
            return match
        }
        if let match = map.workflowDefaultOverrides.first(where: { $0.cardID == cardID && $0.scope == .workflowDefault }) {
            return match
        }
        return nil
    }

    // MARK: - Explanations

    private static func explanationText(
        status: SystemCardStatus,
        card: KnowledgeCard,
        result: PlayabilityResult,
        selectedTargetKind: SystemTargetKind?
    ) -> String {
        switch status {
        case .irrelevant:
            let targetList = card.playabilityRules.systemTargetTypes.map(\.displayName).joined(separator: " or ")
            let selectionName = selectedTargetKind?.displayName ?? "the current selection"
            return "Irrelevant to this selection because this card targets \(targetList), and the selected element is a \(selectionName)."
        case .recommended:
            return "Recommended — this card explicitly targets \(selectedTargetKind?.displayName ?? "this selection")."
        case .available:
            // Only ever the *effective* status here, via an explicit
            // override — the automatic engine no longer produces
            // `.available` on its own (see `.pending`).
            if result.availableReasons.isEmpty {
                return "Available — no prerequisites are required."
            }
            return "Available because " + result.availableReasons.joined(separator: "; ") + "."
        case .pending:
            if result.availableReasons.isEmpty {
                return "Playable — no prerequisites are required — but not marked available automatically. Change its status to make it available here."
            }
            return "Playable because " + result.availableReasons.joined(separator: "; ") + ", but not marked available automatically. Change its status to make it available here."
        case .locked:
            if !result.unlockingCards.isEmpty {
                return "Locked because " + result.blockedReasons.joined(separator: "; ") + ". Playing " + result.unlockingCards.joined(separator: " or ") + " would unlock it."
            }
            return "Locked because " + result.blockedReasons.joined(separator: "; ") + "."
        case .disabled:
            return "Disabled because " + result.blockedReasons.joined(separator: "; ") + "."
        case .active, .exhausted, .resolved:
            // The automatic (pure rule-engine) status never resolves to
            // these on its own — they only ever appear as an override's
            // effective status. Kept exhaustive for compiler safety.
            return status.displayName
        }
    }
}
