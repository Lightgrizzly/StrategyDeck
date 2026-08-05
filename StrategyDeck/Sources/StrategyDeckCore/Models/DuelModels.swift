import Foundation

// MARK: - Display zones (where cards appear in the comic panel)

public enum DuelZone: String, Codable, CaseIterable, Sendable {
    case opponent
    case battlefield
    case player

    public var title: String {
        switch self {
        case .opponent: return "Opponent"
        case .battlefield: return "Battlefield"
        case .player: return "Player"
        }
    }

    public var subtitle: String {
        switch self {
        case .opponent: return "Threats, constraints, and opposing forces"
        case .battlefield: return "Shared state, goals, and persistent effects"
        case .player: return "Your response cards and actions"
        }
    }
}

// MARK: - Strategic zones (gameplay state)

public enum StrategicZone: String, Codable, CaseIterable, Sendable {
    case deck
    case hand
    case field
    case locked
    case exhausted
    case discarded
    case resolved

    public var title: String {
        switch self {
        case .deck: return "Deck"
        case .hand: return "Hand"
        case .field: return "Field"
        case .locked: return "Locked"
        case .exhausted: return "Exhausted"
        case .discarded: return "Discarded"
        case .resolved: return "Resolved"
        }
    }

    public var subtitle: String {
        switch self {
        case .deck: return "In the strategy set"
        case .hand: return "Available to play"
        case .field: return "Currently active"
        case .locked: return "Cannot be played yet"
        case .exhausted: return "Used, cannot be used again"
        case .discarded: return "Removed from play"
        case .resolved: return "Purpose complete"
        }
    }

    public var systemImage: String {
        switch self {
        case .deck: return "square.stack"
        case .hand: return "hand.raised"
        case .field: return "rectangle.on.rectangle"
        case .locked: return "lock"
        case .exhausted: return "bolt.slash"
        case .discarded: return "xmark.circle"
        case .resolved: return "checkmark.circle"
        }
    }

    public var isActiveState: Bool {
        self == .field || self == .hand
    }
}

// MARK: - Card status

public enum DuelCardStatus: String, Codable, CaseIterable, Sendable {
    case active
    case available
    case exhausted
    case blocked
    case resolved
    case defeated
    case discarded

    public var title: String {
        switch self {
        case .active: return "Active"
        case .available: return "Available"
        case .exhausted: return "Exhausted"
        case .blocked: return "Blocked"
        case .resolved: return "Resolved"
        case .defeated: return "Defeated"
        case .discarded: return "Discarded"
        }
    }
}

// MARK: - Playability result

public struct PlayabilityResult: Sendable {
    public let isPlayable: Bool
    public let availableReasons: [String]
    public let blockedReasons: [String]
    public let unlockingCards: [String]
    public let blockingCards: [String]

    public static let unconstrained = PlayabilityResult(
        isPlayable: true,
        availableReasons: [],
        blockedReasons: [],
        unlockingCards: [],
        blockingCards: []
    )

    public init(
        isPlayable: Bool,
        availableReasons: [String],
        blockedReasons: [String],
        unlockingCards: [String],
        blockingCards: [String]
    ) {
        self.isPlayable = isPlayable
        self.availableReasons = availableReasons
        self.blockedReasons = blockedReasons
        self.unlockingCards = unlockingCards
        self.blockingCards = blockingCards
    }

    public var hasDetails: Bool {
        !availableReasons.isEmpty || !blockedReasons.isEmpty || !unlockingCards.isEmpty || !blockingCards.isEmpty
    }
}

// MARK: - State change (for transition highlighting)

public struct SnapshotChange: Sendable {
    public enum Kind: Sendable {
        case added
        case removed
        case statusChanged(from: DuelCardStatus)
        case strategicZoneChanged(from: StrategicZone)
    }

    public let cardTitle: String
    public let kind: Kind

    public init(cardTitle: String, kind: Kind) {
        self.cardTitle = cardTitle
        self.kind = kind
    }

    public var label: String {
        switch kind {
        case .added: return "\(cardTitle) added"
        case .removed: return "\(cardTitle) removed"
        case .statusChanged(let from): return "\(cardTitle): \(from.title) → new status"
        case .strategicZoneChanged(let from): return "\(cardTitle): \(from.title) → new zone"
        }
    }

    public var systemImage: String {
        switch kind {
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle"
        case .statusChanged: return "arrow.triangle.2.circlepath"
        case .strategicZoneChanged: return "arrow.right.circle"
        }
    }
}

// MARK: - Panel reasoning

public struct PanelReasoning: Codable, Hashable, Sendable {
    public var whatChanged: String
    public var whyThisCard: String
    public var whatUnlocked: String
    public var whatBlocked: String
    public var riskIntroduced: String
    public var whatLearned: String

    public init(
        whatChanged: String = "",
        whyThisCard: String = "",
        whatUnlocked: String = "",
        whatBlocked: String = "",
        riskIntroduced: String = "",
        whatLearned: String = ""
    ) {
        self.whatChanged = whatChanged
        self.whyThisCard = whyThisCard
        self.whatUnlocked = whatUnlocked
        self.whatBlocked = whatBlocked
        self.riskIntroduced = riskIntroduced
        self.whatLearned = whatLearned
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        whatChanged = try c.decodeIfPresent(String.self, forKey: .whatChanged) ?? ""
        whyThisCard = try c.decodeIfPresent(String.self, forKey: .whyThisCard) ?? ""
        whatUnlocked = try c.decodeIfPresent(String.self, forKey: .whatUnlocked) ?? ""
        whatBlocked = try c.decodeIfPresent(String.self, forKey: .whatBlocked) ?? ""
        riskIntroduced = try c.decodeIfPresent(String.self, forKey: .riskIntroduced) ?? ""
        whatLearned = try c.decodeIfPresent(String.self, forKey: .whatLearned) ?? ""
    }

    public var isEmpty: Bool {
        whatChanged.isEmpty && whyThisCard.isEmpty && whatUnlocked.isEmpty &&
        whatBlocked.isEmpty && riskIntroduced.isEmpty && whatLearned.isEmpty
    }
}

// MARK: - Duel outcome

public enum DuelOutcome: String, Codable, CaseIterable, Sendable {
    case victory
    case partialVictory
    case stalemate
    case failure
    case abandoned

    public var title: String {
        switch self {
        case .victory: return "Victory"
        case .partialVictory: return "Partial Victory"
        case .stalemate: return "Stalemate"
        case .failure: return "Failure"
        case .abandoned: return "Abandoned"
        }
    }

    public var systemImage: String {
        switch self {
        case .victory: return "star.fill"
        case .partialVictory: return "star.leadinghalf.filled"
        case .stalemate: return "equal.circle"
        case .failure: return "xmark.circle"
        case .abandoned: return "slash.circle"
        }
    }
}

// MARK: - Duel reflection

public struct DuelReflection: Codable, Hashable, Sendable {
    public var cardThatMatteredMost: String
    public var cardToPlayEarlier: String
    public var unnecessaryCard: String
    public var incorrectAssumption: String
    public var discoveredStrategy: String
    public var ruleToChange: String
    public var doNextTime: String
    public var lessonLearned: String

    public init(
        cardThatMatteredMost: String = "",
        cardToPlayEarlier: String = "",
        unnecessaryCard: String = "",
        incorrectAssumption: String = "",
        discoveredStrategy: String = "",
        ruleToChange: String = "",
        doNextTime: String = "",
        lessonLearned: String = ""
    ) {
        self.cardThatMatteredMost = cardThatMatteredMost
        self.cardToPlayEarlier = cardToPlayEarlier
        self.unnecessaryCard = unnecessaryCard
        self.incorrectAssumption = incorrectAssumption
        self.discoveredStrategy = discoveredStrategy
        self.ruleToChange = ruleToChange
        self.doNextTime = doNextTime
        self.lessonLearned = lessonLearned
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cardThatMatteredMost = try c.decodeIfPresent(String.self, forKey: .cardThatMatteredMost) ?? ""
        cardToPlayEarlier = try c.decodeIfPresent(String.self, forKey: .cardToPlayEarlier) ?? ""
        unnecessaryCard = try c.decodeIfPresent(String.self, forKey: .unnecessaryCard) ?? ""
        incorrectAssumption = try c.decodeIfPresent(String.self, forKey: .incorrectAssumption) ?? ""
        discoveredStrategy = try c.decodeIfPresent(String.self, forKey: .discoveredStrategy) ?? ""
        ruleToChange = try c.decodeIfPresent(String.self, forKey: .ruleToChange) ?? ""
        doNextTime = try c.decodeIfPresent(String.self, forKey: .doNextTime) ?? ""
        lessonLearned = try c.decodeIfPresent(String.self, forKey: .lessonLearned) ?? ""
    }

    public var isEmpty: Bool {
        cardThatMatteredMost.isEmpty && cardToPlayEarlier.isEmpty && unnecessaryCard.isEmpty &&
        incorrectAssumption.isEmpty && discoveredStrategy.isEmpty && ruleToChange.isEmpty &&
        doNextTime.isEmpty && lessonLearned.isEmpty
    }
}

// MARK: - Card snapshot

public struct DuelCardSnapshot: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var zone: DuelZone
    public var strategicZone: StrategicZone
    public var status: DuelCardStatus
    public var isNew: Bool
    public var order: Int
    public var annotation: String
    public var isManuallyOverridden: Bool

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        zone: DuelZone,
        strategicZone: StrategicZone = .hand,
        status: DuelCardStatus = .available,
        isNew: Bool = true,
        order: Int = 0,
        annotation: String = "",
        isManuallyOverridden: Bool = false
    ) {
        self.id = id
        self.cardID = cardID
        self.zone = zone
        self.strategicZone = strategicZone
        self.status = status
        self.isNew = isNew
        self.order = order
        self.annotation = annotation
        self.isManuallyOverridden = isManuallyOverridden
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        zone = try c.decodeIfPresent(DuelZone.self, forKey: .zone) ?? .player
        strategicZone = try c.decodeIfPresent(StrategicZone.self, forKey: .strategicZone) ?? .hand
        status = try c.decodeIfPresent(DuelCardStatus.self, forKey: .status) ?? .available
        isNew = try c.decodeIfPresent(Bool.self, forKey: .isNew) ?? false
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        annotation = try c.decodeIfPresent(String.self, forKey: .annotation) ?? ""
        isManuallyOverridden = try c.decodeIfPresent(Bool.self, forKey: .isManuallyOverridden) ?? false
    }

    public func duplicated(newOrder: Int? = nil) -> DuelCardSnapshot {
        DuelCardSnapshot(
            id: UUID(),
            cardID: cardID,
            zone: zone,
            strategicZone: strategicZone,
            status: status,
            isNew: false,
            order: newOrder ?? order,
            annotation: annotation,
            isManuallyOverridden: isManuallyOverridden
        )
    }
}

// MARK: - Panel

public struct DuelPanel: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var order: Int
    public var title: String
    public var narration: String
    public var opponentCaption: String
    public var playerCaption: String
    public var outcome: String
    public var snapshots: [DuelCardSnapshot]
    public var reasoning: PanelReasoning
    public var parentPanelID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        order: Int,
        title: String,
        narration: String = "",
        opponentCaption: String = "",
        playerCaption: String = "",
        outcome: String = "",
        snapshots: [DuelCardSnapshot] = [],
        reasoning: PanelReasoning = PanelReasoning(),
        parentPanelID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.narration = narration
        self.opponentCaption = opponentCaption
        self.playerCaption = playerCaption
        self.outcome = outcome
        self.snapshots = snapshots
        self.reasoning = reasoning
        self.parentPanelID = parentPanelID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        narration = try c.decodeIfPresent(String.self, forKey: .narration) ?? ""
        opponentCaption = try c.decodeIfPresent(String.self, forKey: .opponentCaption) ?? ""
        playerCaption = try c.decodeIfPresent(String.self, forKey: .playerCaption) ?? ""
        outcome = try c.decodeIfPresent(String.self, forKey: .outcome) ?? ""
        snapshots = try c.decodeIfPresent([DuelCardSnapshot].self, forKey: .snapshots) ?? []
        reasoning = try c.decodeIfPresent(PanelReasoning.self, forKey: .reasoning) ?? PanelReasoning()
        parentPanelID = try c.decodeIfPresent(UUID.self, forKey: .parentPanelID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public func duplicated(order: Int) -> DuelPanel {
        DuelPanel(
            id: UUID(),
            order: order,
            title: title,
            narration: narration,
            opponentCaption: opponentCaption,
            playerCaption: playerCaption,
            outcome: outcome,
            snapshots: snapshots.map { $0.duplicated() },
            reasoning: PanelReasoning(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Duel

public struct Duel: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var victoryCondition: String
    public var failureCondition: String
    public var currentProblem: String
    public var knownInformation: String
    public var unknownInformation: String
    public var constraints: String
    public var duelOutcome: DuelOutcome?
    public var reflection: DuelReflection?
    public var completedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var currentPanelID: UUID?
    public var panels: [DuelPanel]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        victoryCondition: String = "",
        failureCondition: String = "",
        currentProblem: String = "",
        knownInformation: String = "",
        unknownInformation: String = "",
        constraints: String = "",
        duelOutcome: DuelOutcome? = nil,
        reflection: DuelReflection? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        currentPanelID: UUID? = nil,
        panels: [DuelPanel] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.victoryCondition = victoryCondition
        self.failureCondition = failureCondition
        self.currentProblem = currentProblem
        self.knownInformation = knownInformation
        self.unknownInformation = unknownInformation
        self.constraints = constraints
        self.duelOutcome = duelOutcome
        self.reflection = reflection
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.currentPanelID = currentPanelID
        self.panels = panels
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        victoryCondition = try c.decodeIfPresent(String.self, forKey: .victoryCondition) ?? ""
        failureCondition = try c.decodeIfPresent(String.self, forKey: .failureCondition) ?? ""
        currentProblem = try c.decodeIfPresent(String.self, forKey: .currentProblem) ?? ""
        knownInformation = try c.decodeIfPresent(String.self, forKey: .knownInformation) ?? ""
        unknownInformation = try c.decodeIfPresent(String.self, forKey: .unknownInformation) ?? ""
        constraints = try c.decodeIfPresent(String.self, forKey: .constraints) ?? ""
        duelOutcome = try c.decodeIfPresent(DuelOutcome.self, forKey: .duelOutcome)
        reflection = try c.decodeIfPresent(DuelReflection.self, forKey: .reflection)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        currentPanelID = try c.decodeIfPresent(UUID.self, forKey: .currentPanelID)
        panels = try c.decodeIfPresent([DuelPanel].self, forKey: .panels) ?? []
    }

    public var currentPanel: DuelPanel? {
        guard let currentID = currentPanelID else {
            return panels.sorted(by: { $0.order < $1.order }).first
        }
        return panels.first(where: { $0.id == currentID }) ?? panels.sorted(by: { $0.order < $1.order }).first
    }

    public var sortedPanels: [DuelPanel] {
        panels.sorted { $0.order < $1.order }
    }

    public var isCompleted: Bool {
        duelOutcome != nil
    }
}
