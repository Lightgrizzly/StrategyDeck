import Foundation

/// Deterministic, UI-free rule evaluation for the Systems Map. Deliberately
/// thin: it builds a ``PlayabilityContext`` from the map's own state and
/// delegates the actual rule logic to ``PlayabilityEvaluator``, the same
/// evaluator the Duel Board uses — so a card's prerequisites, blockers, and
/// unlock relationships behave identically everywhere in the app. This file
/// only adds the state → status mapping (active/pending/exhausted/resolved
/// bookkeeping, target-kind relevance, and human-readable explanations) that
/// is specific to the Systems Map's richer status vocabulary.
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

    /// Builds the shared evaluation context from a step's state — the
    /// bridge between Systems Map state and the app-wide card rule engine.
    public static func context(for step: SystemStep, allCards: [KnowledgeCard]) -> PlayabilityContext {
        let cardsByID = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })

        let activeTitles = Set(step.cardPlays.filter { $0.status == .active }.compactMap { cardsByID[$0.cardID]?.title })
        let resolvedTitles = Set(step.cardPlays.filter { $0.status == .resolved }.compactMap { cardsByID[$0.cardID]?.title })
        let playedTitles = Set(step.cardPlays.compactMap { cardsByID[$0.cardID]?.title })
        let inPlayTitles = activeTitles.union(resolvedTitles).union(playedTitles)

        var reciprocalUnlocks: [String: Set<String>] = [:]
        for card in allCards where inPlayTitles.contains(card.title) {
            for unlocked in card.playabilityRules.unlocksCardTitles {
                reciprocalUnlocks[unlocked, default: []].insert(card.title)
            }
        }

        let constraintDescriptions = step.elements
            .filter { $0.kind == .constraint }
            .map { $0.description.isEmpty ? $0.name : $0.description }
            .joined(separator: ". ")

        return PlayabilityContext(
            activeCardTitles: activeTitles,
            resolvedCardTitles: resolvedTitles,
            playedCardTitles: playedTitles,
            knownInformation: step.knownInformation,
            constraints: constraintDescriptions,
            reciprocalUnlocks: reciprocalUnlocks
        )
    }

    /// Evaluates a single card against a step, optionally scoped to a
    /// selected diagram element, flow, or relationship. Pass `nil` for
    /// "nothing selected" / "entire system".
    public static func evaluate(
        card: KnowledgeCard,
        step: SystemStep,
        selectedTargetKind: SystemTargetKind?,
        allCards: [KnowledgeCard]
    ) -> SystemCardEvaluation {
        let context = context(for: step, allCards: allCards)
        let result = PlayabilityEvaluator.evaluate(card: card, context: context)
        let rules = card.playabilityRules
        let declaresTargets = !rules.systemTargetTypes.isEmpty
        let isRelevant = selectedTargetKind == nil || !declaresTargets || rules.systemTargetTypes.contains(selectedTargetKind!)

        // Existing play record for this card takes priority — once played,
        // a card's status is a fact about what happened, not a re-evaluated
        // guess (matches how Duel snapshots hold their own strategicZone).
        let existingPlay = step.cardPlays.last { $0.cardID == card.id }

        let baseStatus: SystemCardStatus
        if let existingPlay {
            switch existingPlay.status {
            case .active:    baseStatus = .active
            case .pending:   baseStatus = .pending
            case .exhausted: baseStatus = .exhausted
            case .resolved:  baseStatus = .resolved
            }
        } else if !isRelevant {
            baseStatus = .irrelevant
        } else if result.isPlayable {
            let isRecommended = selectedTargetKind != nil && declaresTargets && rules.systemTargetTypes.contains(selectedTargetKind!)
            baseStatus = isRecommended ? .recommended : .available
        } else {
            baseStatus = result.blockingCards.isEmpty ? .locked : .disabled
        }

        let overridden = step.manualStatusOverrides[card.id]
        let finalStatus = overridden ?? baseStatus

        let explanation = explanationText(
            status: baseStatus,
            card: card,
            result: result,
            isRelevant: isRelevant,
            selectedTargetKind: selectedTargetKind,
            existingPlay: existingPlay,
            step: step
        )

        return SystemCardEvaluation(
            cardID: card.id,
            status: finalStatus,
            isPlayable: existingPlay == nil && isRelevant && result.isPlayable,
            relevance: isRelevant,
            validTargetKinds: rules.systemTargetTypes,
            satisfiedRequirements: result.availableReasons,
            missingRequirements: result.blockedReasons,
            blockingConditions: result.blockingCards,
            unlockSuggestions: result.unlockingCards,
            isManuallyOverridden: overridden != nil,
            explanation: explanation
        )
    }

    public static func evaluateAll(
        cards: [KnowledgeCard],
        step: SystemStep,
        selectedTargetKind: SystemTargetKind?
    ) -> [SystemCardEvaluation] {
        cards.map { evaluate(card: $0, step: step, selectedTargetKind: selectedTargetKind, allCards: cards) }
    }

    // MARK: - Explanations

    private static func explanationText(
        status: SystemCardStatus,
        card: KnowledgeCard,
        result: PlayabilityResult,
        isRelevant: Bool,
        selectedTargetKind: SystemTargetKind?,
        existingPlay: SystemCardPlay?,
        step: SystemStep
    ) -> String {
        switch status {
        case .active:
            return "Active because this card was played at Step \((existingPlay?.playedAtStepIndex ?? step.index) + 1) and its effect is still in force."
        case .resolved:
            return "Resolved — this card was played and its intended effect has completed."
        case .exhausted:
            return "Exhausted — this card has already been used and cannot be reused."
        case .pending:
            return "Pending — this card was played but its delayed result has not yet completed."
        case .irrelevant:
            let targetList = card.playabilityRules.systemTargetTypes.map(\.displayName).joined(separator: " or ")
            let selectionName = selectedTargetKind?.displayName ?? "the current selection"
            return "Irrelevant to this selection because this card targets \(targetList), and the selected element is a \(selectionName)."
        case .recommended, .available:
            if result.availableReasons.isEmpty {
                return "Available — no prerequisites are required."
            }
            return "Available because " + result.availableReasons.joined(separator: "; ") + "."
        case .locked:
            if !result.unlockingCards.isEmpty {
                return "Locked because " + result.blockedReasons.joined(separator: "; ") + ". Playing " + result.unlockingCards.joined(separator: " or ") + " would unlock it."
            }
            return "Locked because " + result.blockedReasons.joined(separator: "; ") + "."
        case .disabled:
            return "Disabled because " + result.blockedReasons.joined(separator: "; ") + "."
        }
    }
}
