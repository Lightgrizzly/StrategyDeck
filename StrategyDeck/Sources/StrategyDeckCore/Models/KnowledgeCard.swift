import Foundation

/// A single card in the library. `kind` is the domain-independent role
/// (drives symbol + generic behavior); `metadata` is the deck-specific
/// structured payload (drives specialized fields and detail/editor views).
/// `deckIDs`/`suitIDs` are arrays so a card can belong to more than one
/// deck or suit without duplication.
public struct KnowledgeCard: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var deckIDs: [String]
    public var suitIDs: [String]
    public var kind: CardKind
    public var metadata: CardMetadata
    public var title: String
    public var subtitle: String
    public var frontText: String
    public var backText: String
    public var tags: [String]
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        deckIDs: [String],
        suitIDs: [String],
        kind: CardKind,
        metadata: CardMetadata = .generic,
        title: String,
        subtitle: String = "",
        frontText: String = "",
        backText: String = "",
        tags: [String] = [],
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.deckIDs = deckIDs
        self.suitIDs = suitIDs
        self.kind = kind
        self.metadata = metadata
        self.title = title
        self.subtitle = subtitle
        self.frontText = frontText
        self.backText = backText
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        deckIDs = try c.decodeIfPresent([String].self, forKey: .deckIDs) ?? []
        suitIDs = try c.decodeIfPresent([String].self, forKey: .suitIDs) ?? []
        kind = try c.decodeIfPresent(CardKind.self, forKey: .kind) ?? .action
        metadata = try c.decodeIfPresent(CardMetadata.self, forKey: .metadata) ?? .generic
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        frontText = try c.decodeIfPresent(String.self, forKey: .frontText) ?? ""
        backText = try c.decodeIfPresent(String.self, forKey: .backText) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Every string a free-text search should be able to match against.
    public var searchableText: [String] {
        [title, subtitle, frontText, backText] + tags + metadata.searchableText
    }
}
