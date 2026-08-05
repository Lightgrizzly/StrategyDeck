import Foundation

/// The kind of graph edge between two ``KnowledgeCard``s. Directional:
/// stored as `source → target`; ``inverseLabel`` is what to show when
/// looking at the edge from the target's side.
public enum CardRelationshipType: String, Codable, Hashable, Sendable, CaseIterable {
    case requires
    case enables
    case modifies
    case contrasts
    case combinesWith
    case belongsTo
    case canFollow
    case canPrecede
    case equivalentExpression
    case relatedStrategy
    case translation

    public var label: String {
        switch self {
        case .requires: return "Requires"
        case .enables: return "Enables"
        case .modifies: return "Modifies"
        case .contrasts: return "Contrasts with"
        case .combinesWith: return "Combines with"
        case .belongsTo: return "Belongs to"
        case .canFollow: return "Can follow"
        case .canPrecede: return "Can precede"
        case .equivalentExpression: return "Equivalent expression"
        case .relatedStrategy: return "Related strategy"
        case .translation: return "Translation"
        }
    }

    public var inverseLabel: String {
        switch self {
        case .requires: return "Required by"
        case .enables: return "Enabled by"
        case .modifies: return "Modified by"
        case .contrasts: return "Contrasts with"
        case .combinesWith: return "Combines with"
        case .belongsTo: return "Contains"
        case .canFollow: return "Can precede"
        case .canPrecede: return "Can follow"
        case .equivalentExpression: return "Equivalent expression"
        case .relatedStrategy: return "Related strategy"
        case .translation: return "Translation"
        }
    }
}

/// A directed graph edge between two cards, replacing the old embedded
/// `relatedStrategyIDs` / `combinesWellWithIDs` arrays. A card's
/// relationships are looked up by scanning for its id as either
/// `sourceCardID` or `targetCardID` — see ``CardRelationshipType/inverseLabel``.
public struct CardRelationship: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var sourceCardID: UUID
    public var targetCardID: UUID
    public var type: CardRelationshipType
    public var note: String

    public init(
        id: UUID = UUID(),
        sourceCardID: UUID,
        targetCardID: UUID,
        type: CardRelationshipType,
        note: String = ""
    ) {
        self.id = id
        self.sourceCardID = sourceCardID
        self.targetCardID = targetCardID
        self.type = type
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceCardID = try c.decode(UUID.self, forKey: .sourceCardID)
        targetCardID = try c.decode(UUID.self, forKey: .targetCardID)
        type = try c.decode(CardRelationshipType.self, forKey: .type)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
