import Foundation

/// How broadly a card pin applies. The safest/narrowest scope is the
/// default everywhere a pin is created.
public enum PinScope: String, Codable, Hashable, Sendable, CaseIterable {
    case thisElementThisScenario
    case thisElementAllScenarios
    case allElementsOfTypeInMap
    case entireMap

    public var displayName: String {
        switch self {
        case .thisElementThisScenario: return "This Element, This Scenario"
        case .thisElementAllScenarios: return "This Element, All Scenarios"
        case .allElementsOfTypeInMap: return "All Elements of This Type"
        case .entireMap: return "Entire Systems Map"
        }
    }
}

/// A user-pinned card in a Contextual Hand. Pinning never changes a
/// card's status — it only affects Contextual Hand ranking.
public struct ContextualCardPin: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var scope: PinScope
    /// Set when `scope` is element-specific (`thisElement...`).
    public var elementID: UUID?
    /// Set when `scope == .allElementsOfTypeInMap`.
    public var targetKind: SystemTargetKind?
    /// Set when `scope == .thisElementThisScenario`.
    public var scenarioID: UUID?
    public var note: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        scope: PinScope = .thisElementThisScenario,
        elementID: UUID? = nil,
        targetKind: SystemTargetKind? = nil,
        scenarioID: UUID? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.cardID = cardID
        self.scope = scope
        self.elementID = elementID
        self.targetKind = targetKind
        self.scenarioID = scenarioID
        self.note = note
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        scope = try c.decodeIfPresent(PinScope.self, forKey: .scope) ?? .thisElementThisScenario
        elementID = try c.decodeIfPresent(UUID.self, forKey: .elementID)
        targetKind = try c.decodeIfPresent(SystemTargetKind.self, forKey: .targetKind)
        scenarioID = try c.decodeIfPresent(UUID.self, forKey: .scenarioID)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// Whether this pin applies to a card being evaluated for a specific
    /// element/target-kind/scenario combination.
    public func matches(elementID: UUID?, targetKind: SystemTargetKind?, scenarioID: UUID) -> Bool {
        switch scope {
        case .thisElementThisScenario:
            return self.elementID == elementID && self.scenarioID == scenarioID
        case .thisElementAllScenarios:
            return self.elementID == elementID
        case .allElementsOfTypeInMap:
            return self.targetKind == targetKind
        case .entireMap:
            return true
        }
    }
}

/// One ranked entry in a Contextual Hand — a card evaluation plus why it's
/// showing and where. Purely derived; not persisted.
public struct ContextualHandEntry: Identifiable, Sendable {
    public let card: KnowledgeCard
    public let evaluation: SystemCardEvaluation
    public let reasons: [String]
    public let isPinned: Bool

    public var id: UUID { evaluation.cardID }

    public init(card: KnowledgeCard, evaluation: SystemCardEvaluation, reasons: [String], isPinned: Bool) {
        self.card = card
        self.evaluation = evaluation
        self.reasons = reasons
        self.isPinned = isPinned
    }
}

/// Deterministic Contextual Hand ranking. No hidden heuristics — every
/// tier here is a named, visible reason (see `ContextualHandEntry.reasons`).
/// Issue-related tiers (3 and 4 in the product spec) are threaded in by the
/// caller via `respondsToCriticalBlocker`/`respondsToIssue` once the issue
/// model exists; they default to "never matches" until then.
public struct ContextualHandRanker: Sendable {

    public static func rank(
        cards: [KnowledgeCard],
        evaluationsByCardID: [UUID: SystemCardEvaluation],
        pins: [ContextualCardPin],
        elementID: UUID?,
        targetKind: SystemTargetKind?,
        scenarioID: UUID,
        selectedSuitIDs: Set<String>,
        recentlyChangedCardIDs: Set<UUID>,
        respondsToCriticalBlocker: (KnowledgeCard) -> Bool = { _ in false },
        respondsToIssue: (KnowledgeCard) -> (Bool, String?) = { _ in (false, nil) }
    ) -> [ContextualHandEntry] {
        let matchingPins = pins.filter { $0.matches(elementID: elementID, targetKind: targetKind, scenarioID: scenarioID) }
        let pinnedCardIDs = Set(matchingPins.map(\.cardID))

        struct Ranked {
            let card: KnowledgeCard
            let evaluation: SystemCardEvaluation
            let reasons: [String]
            let isPinned: Bool
            let isActive: Bool
            let respondsToCriticalBlocker: Bool
            let issueReason: String?
            let isExactTarget: Bool
            let isAvailable: Bool
            let isSelectedSuite: Bool
            let satisfiedCount: Int
            let isRecentlyUsed: Bool
        }

        let ranked: [Ranked] = cards.compactMap { card in
            guard let evaluation = evaluationsByCardID[card.id] else { return nil }
            let isPinned = pinnedCardIDs.contains(card.id)
            let isActive = evaluation.effectiveStatus == .active
            let criticalBlocker = respondsToCriticalBlocker(card)
            let (_, issueReason) = respondsToIssue(card)
            let isExactTarget = targetKind != nil && card.playabilityRules.systemTargetTypes.contains(targetKind!)
            let isAvailable = evaluation.isPlayable
            let isSelectedSuite = !selectedSuitIDs.isEmpty && !Set(card.suitIDs).isDisjoint(with: selectedSuitIDs)
            let isRecentlyUsed = recentlyChangedCardIDs.contains(card.id)

            var reasons: [String] = []
            if isPinned { reasons.append("Pinned to this node") }
            if isActive { reasons.append("Active in this scenario") }
            if criticalBlocker { reasons.append("Responds to a critical blocker") }
            if let issueReason { reasons.append(issueReason) }
            if isExactTarget { reasons.append("Exact match for this target type") }
            if isAvailable && reasons.isEmpty { reasons.append("Available — no prerequisites are required") }
            if isSelectedSuite { reasons.append("In the selected suite") }
            if isRecentlyUsed { reasons.append("Recently changed") }
            if reasons.isEmpty { reasons.append("Alphabetical fallback") }

            return Ranked(
                card: card, evaluation: evaluation, reasons: reasons, isPinned: isPinned,
                isActive: isActive, respondsToCriticalBlocker: criticalBlocker, issueReason: issueReason,
                isExactTarget: isExactTarget, isAvailable: isAvailable, isSelectedSuite: isSelectedSuite,
                satisfiedCount: evaluation.satisfiedRequirements.count, isRecentlyUsed: isRecentlyUsed
            )
        }

        let sorted = ranked.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            if a.isActive != b.isActive { return a.isActive }
            if a.respondsToCriticalBlocker != b.respondsToCriticalBlocker { return a.respondsToCriticalBlocker }
            if (a.issueReason != nil) != (b.issueReason != nil) { return a.issueReason != nil }
            if a.isExactTarget != b.isExactTarget { return a.isExactTarget }
            if a.isAvailable != b.isAvailable { return a.isAvailable }
            if a.isSelectedSuite != b.isSelectedSuite { return a.isSelectedSuite }
            if a.satisfiedCount != b.satisfiedCount { return a.satisfiedCount > b.satisfiedCount }
            if a.isRecentlyUsed != b.isRecentlyUsed { return a.isRecentlyUsed }
            if a.card.createdAt != b.card.createdAt { return a.card.createdAt > b.card.createdAt }
            return a.card.title.localizedCaseInsensitiveCompare(b.card.title) == .orderedAscending
        }

        return sorted.map { ContextualHandEntry(card: $0.card, evaluation: $0.evaluation, reasons: $0.reasons, isPinned: $0.isPinned) }
    }
}
