import Foundation

/// A grouping of cards within a deck. `parentSuitID == nil` means this is a
/// root suit; any suit may have children, at arbitrary nesting depth. The
/// Deck → Suit → Sub-suit tree is purely a browsing structure derived from
/// this — it is not the source of truth for how cards relate to each other
/// (see ``CardRelationship``), and a card may appear in multiple suits via
/// `KnowledgeCard.suitIDs`.
public struct CardSuit: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var deckID: String
    public var parentSuitID: String?
    public var name: String
    public var description: String
    public var iconName: String
    public var displayOrder: Int

    public init(
        id: String,
        deckID: String,
        parentSuitID: String? = nil,
        name: String,
        description: String = "",
        iconName: String = "square.stack.3d.up",
        displayOrder: Int = 0
    ) {
        self.id = id
        self.deckID = deckID
        self.parentSuitID = parentSuitID
        self.name = name
        self.description = description
        self.iconName = iconName
        self.displayOrder = displayOrder
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        deckID = try c.decode(String.self, forKey: .deckID)
        parentSuitID = try c.decodeIfPresent(String.self, forKey: .parentSuitID)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id.capitalized
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "square.stack.3d.up"
        displayOrder = try c.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    }
}

public extension Array where Element == CardSuit {
    /// Root suits (`parentSuitID == nil`) belonging to one deck, sorted for display.
    func rootSuits(deckID: String) -> [CardSuit] {
        filter { $0.deckID == deckID && $0.parentSuitID == nil }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Direct children of a suit, sorted for display.
    func children(of suitID: String) -> [CardSuit] {
        filter { $0.parentSuitID == suitID }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    /// `suitID` plus every suit nested underneath it, at any depth. Used to
    /// expand "selected this suit" into "matches this suit or any sub-suit".
    ///
    /// Guards against a malformed/cyclic `parentSuitID` chain (e.g. from a
    /// hand-edited or imported file): each ID is only ever visited once, so
    /// a cycle simply stops expanding instead of recursing forever.
    func descendantIDs(of suitID: String) -> Set<String> {
        var visited: Set<String> = []
        collectDescendantIDs(of: suitID, into: &visited)
        return visited
    }

    private func collectDescendantIDs(of suitID: String, into visited: inout Set<String>) {
        guard !visited.contains(suitID) else { return }
        visited.insert(suitID)
        for child in children(of: suitID) {
            collectDescendantIDs(of: child.id, into: &visited)
        }
    }
}
