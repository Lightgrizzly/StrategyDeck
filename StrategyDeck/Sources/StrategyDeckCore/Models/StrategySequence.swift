import Foundation

/// A named, ordered sequence of cards — the user's proposed flow (e.g.
/// "Estimate-to-Invoice Matching", or a Japanese communication strategy).
/// `deckIDs` and `scenario` exist for a later slice (cross-deck sequences);
/// nothing in this slice's UI populates `deckIDs` with more than one deck.
public struct StrategySequence: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var deckIDs: [String]
    public var scenario: String
    public var orderedItems: [StrategySequenceItem]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        deckIDs: [String] = [],
        scenario: String = "",
        orderedItems: [StrategySequenceItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.deckIDs = deckIDs
        self.scenario = scenario
        self.orderedItems = orderedItems
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        deckIDs = try c.decodeIfPresent([String].self, forKey: .deckIDs) ?? []
        scenario = try c.decodeIfPresent(String.self, forKey: .scenario) ?? ""
        orderedItems = try c.decodeIfPresent([StrategySequenceItem].self, forKey: .orderedItems) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Items sorted by `order`, with `order` re-normalized to 0..<n.
    public var normalizedItems: [StrategySequenceItem] {
        orderedItems
            .sorted { $0.order < $1.order }
            .enumerated()
            .map { index, item in
                var copy = item
                copy.order = index
                return copy
            }
    }
}
