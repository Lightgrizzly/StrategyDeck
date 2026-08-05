import Foundation

/// One ordered entry inside a ``StrategySequence`` — a reference to a card
/// plus an optional inline note and an optional explicit relationship to
/// the item before it (e.g. "then", or a specific ``CardRelationshipType``).
public struct StrategySequenceItem: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var order: Int
    public var note: String
    public var relationshipToPrevious: CardRelationshipType?

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        order: Int,
        note: String = "",
        relationshipToPrevious: CardRelationshipType? = nil
    ) {
        self.id = id
        self.cardID = cardID
        self.order = order
        self.note = note
        self.relationshipToPrevious = relationshipToPrevious
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        relationshipToPrevious = try c.decodeIfPresent(CardRelationshipType.self, forKey: .relationshipToPrevious)
    }
}
