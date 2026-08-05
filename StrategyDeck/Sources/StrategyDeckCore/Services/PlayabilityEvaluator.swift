import Foundation

public struct PlayabilityContext: Sendable {
    public let activeCardTitles: Set<String>
    public let resolvedCardTitles: Set<String>
    public let playedCardTitles: Set<String>
    public let knownInformation: String
    public let constraints: String

    public init(
        activeCardTitles: Set<String> = [],
        resolvedCardTitles: Set<String> = [],
        playedCardTitles: Set<String> = [],
        knownInformation: String = "",
        constraints: String = ""
    ) {
        self.activeCardTitles = activeCardTitles
        self.resolvedCardTitles = resolvedCardTitles
        self.playedCardTitles = playedCardTitles
        self.knownInformation = knownInformation
        self.constraints = constraints
    }
}

public struct PlayabilityEvaluator: Sendable {

    public static func evaluate(card: KnowledgeCard, context: PlayabilityContext) -> PlayabilityResult {
        let rules = card.playabilityRules

        if rules.isEmpty {
            return .unconstrained
        }

        var availableReasons: [String] = []
        var blockedReasons: [String] = []
        var unlockingCards: [String] = []
        var blockingCards: [String] = []

        // Check blockers first
        for blocker in rules.blockedByCardTitles {
            if context.activeCardTitles.contains(blocker) || context.resolvedCardTitles.contains(blocker) {
                blockedReasons.append("\(blocker) is active")
                blockingCards.append(blocker)
            }
        }

        // Check prerequisites (text conditions)
        for prereq in rules.prerequisites {
            let satisfiedByKnown = !context.knownInformation.isEmpty &&
                context.knownInformation.localizedCaseInsensitiveContains(prereq)
            let satisfiedByActive = context.activeCardTitles.contains(prereq)
            if satisfiedByKnown || satisfiedByActive {
                availableReasons.append(prereq)
            } else {
                blockedReasons.append("Prerequisite not met: \(prereq)")
            }
        }

        // Check required active cards
        for required in rules.requiredActiveCardTitles {
            if context.activeCardTitles.contains(required) {
                availableReasons.append("\(required) is active")
            } else {
                blockedReasons.append("\(required) must be active")
                unlockingCards.append(required)
            }
        }

        // Check required known information
        for info in rules.requiredKnownInfo {
            if context.knownInformation.localizedCaseInsensitiveContains(info) {
                availableReasons.append("Known: \(info)")
            } else {
                blockedReasons.append("Unknown: \(info)")
            }
        }

        // Check unlock-by relationships (at least one must be played/active)
        if !rules.unlockedByCardTitles.isEmpty {
            let satisfied = rules.unlockedByCardTitles.filter {
                context.resolvedCardTitles.contains($0) ||
                context.activeCardTitles.contains($0) ||
                context.playedCardTitles.contains($0)
            }
            let missing = rules.unlockedByCardTitles.filter {
                !context.resolvedCardTitles.contains($0) &&
                !context.activeCardTitles.contains($0) &&
                !context.playedCardTitles.contains($0)
            }
            if !satisfied.isEmpty {
                availableReasons.append(contentsOf: satisfied.map { "Unlocked by \($0)" })
            } else if !missing.isEmpty {
                blockedReasons.append("Requires one of: \(missing.joined(separator: ", "))")
                unlockingCards.append(contentsOf: missing)
            }
        }

        // Check reuse constraint
        if !rules.canBeReused && context.playedCardTitles.contains(card.title) {
            blockedReasons.append("Already played and cannot be reused")
        }

        let isPlayable = blockedReasons.isEmpty

        return PlayabilityResult(
            isPlayable: isPlayable,
            availableReasons: availableReasons,
            blockedReasons: blockedReasons,
            unlockingCards: Array(Set(unlockingCards)),
            blockingCards: Array(Set(blockingCards))
        )
    }

    // Build evaluation context from a panel + duel
    public static func context(from panel: DuelPanel, duel: Duel, cardsByID: [UUID: KnowledgeCard]) -> PlayabilityContext {
        let activeSnapshots = panel.snapshots.filter {
            $0.strategicZone == .field || $0.status == .active
        }
        let resolvedSnapshots = panel.snapshots.filter {
            $0.strategicZone == .resolved || $0.status == .resolved
        }
        let allPlayedSnapshots = panel.snapshots.filter {
            $0.strategicZone != .deck && $0.strategicZone != .hand && $0.strategicZone != .locked
        }

        let activeTitles = Set(activeSnapshots.compactMap { cardsByID[$0.cardID]?.title })
        let resolvedTitles = Set(resolvedSnapshots.compactMap { cardsByID[$0.cardID]?.title })
        let playedTitles = Set(allPlayedSnapshots.compactMap { cardsByID[$0.cardID]?.title })

        return PlayabilityContext(
            activeCardTitles: activeTitles,
            resolvedCardTitles: resolvedTitles,
            playedCardTitles: playedTitles,
            knownInformation: duel.knownInformation,
            constraints: duel.constraints
        )
    }

    // Recalculate strategic zones for non-manually-overridden snapshots
    public static func recalculateStrategicZones(
        panel: DuelPanel,
        duel: Duel,
        allCards: [KnowledgeCard]
    ) -> DuelPanel {
        let cardsByID = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
        let context = PlayabilityEvaluator.context(from: panel, duel: duel, cardsByID: cardsByID)

        var updated = panel
        updated.snapshots = panel.snapshots.map { snapshot in
            guard !snapshot.isManuallyOverridden else { return snapshot }
            guard let card = cardsByID[snapshot.cardID] else { return snapshot }
            guard snapshot.strategicZone == .hand || snapshot.strategicZone == .locked else { return snapshot }

            let result = PlayabilityEvaluator.evaluate(card: card, context: context)
            var updatedSnapshot = snapshot
            updatedSnapshot.strategicZone = result.isPlayable ? .hand : .locked
            return updatedSnapshot
        }
        return updated
    }

    // Compute state changes between two consecutive panels
    public static func stateTransitions(
        from previous: DuelPanel?,
        to current: DuelPanel,
        cardsByID: [UUID: KnowledgeCard]
    ) -> [SnapshotChange] {
        guard let previous else { return [] }

        let prevByCardID = Dictionary(previous.snapshots.map { ($0.cardID, $0) }, uniquingKeysWith: { first, _ in first })
        let currByCardID = Dictionary(current.snapshots.map { ($0.cardID, $0) }, uniquingKeysWith: { first, _ in first })

        var changes: [SnapshotChange] = []

        // Added cards
        for cardID in Set(currByCardID.keys).subtracting(prevByCardID.keys) {
            if let title = cardsByID[cardID]?.title {
                changes.append(SnapshotChange(cardTitle: title, kind: .added))
            }
        }

        // Removed cards
        for cardID in Set(prevByCardID.keys).subtracting(currByCardID.keys) {
            if let title = cardsByID[cardID]?.title {
                changes.append(SnapshotChange(cardTitle: title, kind: .removed))
            }
        }

        // Changed status or strategic zone
        for cardID in Set(currByCardID.keys).intersection(prevByCardID.keys) {
            guard let prevSnap = prevByCardID[cardID],
                  let currSnap = currByCardID[cardID],
                  let title = cardsByID[cardID]?.title else { continue }

            if prevSnap.strategicZone != currSnap.strategicZone {
                changes.append(SnapshotChange(cardTitle: title, kind: .strategicZoneChanged(from: prevSnap.strategicZone)))
            } else if prevSnap.status != currSnap.status {
                changes.append(SnapshotChange(cardTitle: title, kind: .statusChanged(from: prevSnap.status)))
            }
        }

        return changes
    }
}
