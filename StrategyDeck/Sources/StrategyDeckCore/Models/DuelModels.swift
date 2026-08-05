import Foundation

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

public struct DuelCardSnapshot: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var zone: DuelZone
    public var status: DuelCardStatus
    public var isNew: Bool
    public var order: Int
    public var annotation: String

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        zone: DuelZone,
        status: DuelCardStatus = .available,
        isNew: Bool = true,
        order: Int = 0,
        annotation: String = ""
    ) {
        self.id = id
        self.cardID = cardID
        self.zone = zone
        self.status = status
        self.isNew = isNew
        self.order = order
        self.annotation = annotation
    }

    public func duplicated(newOrder: Int? = nil) -> DuelCardSnapshot {
        DuelCardSnapshot(
            id: UUID(),
            cardID: cardID,
            zone: zone,
            status: status,
            isNew: false,
            order: newOrder ?? order,
            annotation: annotation
        )
    }
}

public struct DuelPanel: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var order: Int
    public var title: String
    public var narration: String
    public var opponentCaption: String
    public var playerCaption: String
    public var outcome: String
    public var snapshots: [DuelCardSnapshot]
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

public struct Duel: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var createdAt: Date
    public var updatedAt: Date
    public var currentPanelID: UUID?
    public var panels: [DuelPanel]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        currentPanelID: UUID? = nil,
        panels: [DuelPanel] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.currentPanelID = currentPanelID
        self.panels = panels
    }

    public var currentPanel: DuelPanel? {
        guard let currentID = currentPanelID else { return panels.sorted(by: { $0.order < $1.order }).first }
        return panels.first(where: { $0.id == currentID }) ?? panels.sorted(by: { $0.order < $1.order }).first
    }

    public var sortedPanels: [DuelPanel] {
        panels.sorted { $0.order < $1.order }
    }
}
