import Foundation

public enum IssueType: String, Codable, Hashable, Sendable, CaseIterable {
    case bug, blocker, issue, risk, constraint, assumption, incident, unknown, warning

    public var displayName: String {
        switch self {
        case .bug: return "Bug"
        case .blocker: return "Blocker"
        case .issue: return "Issue"
        case .risk: return "Risk"
        case .constraint: return "Constraint"
        case .assumption: return "Assumption"
        case .incident: return "Incident"
        case .unknown: return "Unknown"
        case .warning: return "Warning"
        }
    }

    public var systemImage: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .blocker: return "hand.raised.fill"
        case .issue: return "exclamationmark.circle.fill"
        case .risk: return "exclamationmark.triangle.fill"
        case .constraint: return "lock.fill"
        case .assumption: return "questionmark.circle.fill"
        case .incident: return "flame.fill"
        case .unknown: return "questionmark.diamond.fill"
        case .warning: return "exclamationmark.triangle"
        }
    }
}

public enum IssueStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case open, investigating, confirmed, blocked, mitigated, resolved, dismissed

    public var displayName: String {
        switch self {
        case .open: return "Open"
        case .investigating: return "Investigating"
        case .confirmed: return "Confirmed"
        case .blocked: return "Blocked"
        case .mitigated: return "Mitigated"
        case .resolved: return "Resolved"
        case .dismissed: return "Dismissed"
        }
    }

    /// Whether this issue still counts as actively affecting card
    /// evaluation. Resolved/dismissed issues stop contributing blocking
    /// conditions but are kept for history.
    public var isActive: Bool {
        self != .resolved && self != .dismissed
    }
}

public enum IssueSeverity: String, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case informational, low, medium, high, critical

    private var rank: Int {
        switch self {
        case .informational: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

    public var displayName: String {
        switch self {
        case .informational: return "Informational"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

/// How a card relates to an issue — a card is what can be *done*; the
/// issue is what's *wrong*. Related cards get contextual-ranking priority
/// when their issue is attached to the selected element.
public enum IssueCardRelationshipType: String, Codable, Hashable, Sendable, CaseIterable {
    case investigates, diagnoses, mitigates, resolves, worksAround, monitors, prevents, escalates

    public var displayName: String {
        switch self {
        case .investigates: return "Investigates"
        case .diagnoses: return "Diagnoses"
        case .mitigates: return "Mitigates"
        case .resolves: return "Resolves"
        case .worksAround: return "Works Around"
        case .monitors: return "Monitors"
        case .prevents: return "Prevents"
        case .escalates: return "Escalates"
        }
    }
}

public struct IssueCardRelationship: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var relationshipType: IssueCardRelationshipType
    public var note: String

    public init(id: UUID = UUID(), cardID: UUID, relationshipType: IssueCardRelationshipType, note: String = "") {
        self.id = id
        self.cardID = cardID
        self.relationshipType = relationshipType
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        relationshipType = try c.decodeIfPresent(IssueCardRelationshipType.self, forKey: .relationshipType) ?? .investigates
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

/// A bug, blocker, issue, risk, constraint, assumption, incident, unknown,
/// or warning attached to one or more diagram elements — what's affecting
/// the element, distinct from cards (what can be done about it).
public struct SystemIssue: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var type: IssueType
    public var description: String
    public var severity: IssueSeverity
    public var status: IssueStatus
    /// Empty means "all scenarios." The default when created is the
    /// current scenario only.
    public var scenarioIDs: [UUID]
    public var affectedElementIDs: [UUID]
    public var owner: String
    public var source: String
    public var notes: String
    public var tags: [String]
    public var relatedCards: [IssueCardRelationship]
    /// Free-text conditions this issue currently blocks on, matched against
    /// a card's `CardPlayabilityRules.blockedByConditions` while this issue
    /// is active (see `SystemMapEvaluator`).
    public var blockingConditionsProduced: [String]
    /// Free-text conditions this issue makes true once active/resolved,
    /// matched against a card's `requiredStateConditions`.
    public var knownInformationProduced: [String]
    public var unknownInformationProduced: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        type: IssueType = .issue,
        description: String = "",
        severity: IssueSeverity = .medium,
        status: IssueStatus = .open,
        scenarioIDs: [UUID] = [],
        affectedElementIDs: [UUID] = [],
        owner: String = "",
        source: String = "",
        notes: String = "",
        tags: [String] = [],
        relatedCards: [IssueCardRelationship] = [],
        blockingConditionsProduced: [String] = [],
        knownInformationProduced: [String] = [],
        unknownInformationProduced: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.description = description
        self.severity = severity
        self.status = status
        self.scenarioIDs = scenarioIDs
        self.affectedElementIDs = affectedElementIDs
        self.owner = owner
        self.source = source
        self.notes = notes
        self.tags = tags
        self.relatedCards = relatedCards
        self.blockingConditionsProduced = blockingConditionsProduced
        self.knownInformationProduced = knownInformationProduced
        self.unknownInformationProduced = unknownInformationProduced
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.resolvedAt = resolvedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Issue"
        type = try c.decodeIfPresent(IssueType.self, forKey: .type) ?? .issue
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        severity = try c.decodeIfPresent(IssueSeverity.self, forKey: .severity) ?? .medium
        status = try c.decodeIfPresent(IssueStatus.self, forKey: .status) ?? .open
        scenarioIDs = try c.decodeIfPresent([UUID].self, forKey: .scenarioIDs) ?? []
        affectedElementIDs = try c.decodeIfPresent([UUID].self, forKey: .affectedElementIDs) ?? []
        owner = try c.decodeIfPresent(String.self, forKey: .owner) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        relatedCards = try c.decodeIfPresent([IssueCardRelationship].self, forKey: .relatedCards) ?? []
        blockingConditionsProduced = try c.decodeIfPresent([String].self, forKey: .blockingConditionsProduced) ?? []
        knownInformationProduced = try c.decodeIfPresent([String].self, forKey: .knownInformationProduced) ?? []
        unknownInformationProduced = try c.decodeIfPresent([String].self, forKey: .unknownInformationProduced) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        resolvedAt = try c.decodeIfPresent(Date.self, forKey: .resolvedAt)
    }

    /// Whether this issue applies in a given scenario — empty `scenarioIDs`
    /// means "all scenarios."
    public func appliesTo(scenarioID: UUID) -> Bool {
        scenarioIDs.isEmpty || scenarioIDs.contains(scenarioID)
    }

    public func affects(elementID: UUID) -> Bool {
        affectedElementIDs.contains(elementID)
    }
}
