import Foundation

/// The complete portable payload for import/export and the bundled seed —
/// replaces `AppData`. A single value round-trips the whole library.
public struct KnowledgeLibrary: Codable, Sendable {
    /// Schema version, so future migrations can detect old files.
    public var version: Int
    public var decks: [KnowledgeDeck]
    public var suits: [CardSuit]
    public var cards: [KnowledgeCard]
    public var relationships: [CardRelationship]
    public var sequences: [StrategySequence]

    public static let currentVersion = 1

    public init(
        version: Int = KnowledgeLibrary.currentVersion,
        decks: [KnowledgeDeck] = [],
        suits: [CardSuit] = [],
        cards: [KnowledgeCard] = [],
        relationships: [CardRelationship] = [],
        sequences: [StrategySequence] = []
    ) {
        self.version = version
        self.decks = decks
        self.suits = suits
        self.cards = cards
        self.relationships = relationships
        self.sequences = sequences
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? KnowledgeLibrary.currentVersion
        decks = try c.decodeIfPresent([KnowledgeDeck].self, forKey: .decks) ?? []
        suits = try c.decodeIfPresent([CardSuit].self, forKey: .suits) ?? []
        cards = try c.decodeIfPresent([KnowledgeCard].self, forKey: .cards) ?? []
        relationships = try c.decodeIfPresent([CardRelationship].self, forKey: .relationships) ?? []
        sequences = try c.decodeIfPresent([StrategySequence].self, forKey: .sequences) ?? []
    }
}
