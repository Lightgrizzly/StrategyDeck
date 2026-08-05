import Foundation

/// Pure, testable search + filtering over a set of cards. Free of any UI
/// type so it's directly unit-testable and reusable from any surface.
public struct CardFilter: Equatable, Sendable {
    /// Free-text query matched against every card's `searchableText`.
    public var query: String
    /// When set, only cards belonging to this deck are returned.
    public var deckID: String?
    /// When set, only cards in this suit (or one of its descendant
    /// sub-suits) are returned.
    public var suitID: String?
    /// When true, only favorited cards are returned.
    public var favoritesOnly: Bool

    public init(query: String = "", deckID: String? = nil, suitID: String? = nil, favoritesOnly: Bool = false) {
        self.query = query
        self.deckID = deckID
        self.suitID = suitID
        self.favoritesOnly = favoritesOnly
    }

    public var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || deckID != nil
            || suitID != nil
            || favoritesOnly
    }

    /// Applies the filter and returns cards sorted favorites-first, then by
    /// title. `suits` is only needed when `suitID` is set — it's used to
    /// expand the selected suit to include its descendant sub-suits.
    public func apply(to cards: [KnowledgeCard], suits: [CardSuit] = []) -> [KnowledgeCard] {
        let terms = query
            .lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map(String.init)

        let allowedSuitIDs: Set<String>? = suitID.map { suits.descendantIDs(of: $0) }

        let filtered = cards.filter { card in
            if let deckID, !card.deckIDs.contains(deckID) { return false }
            if let allowedSuitIDs, !card.suitIDs.contains(where: allowedSuitIDs.contains) { return false }
            if favoritesOnly, !card.isFavorite { return false }
            guard !terms.isEmpty else { return true }
            let haystack = card.searchableText.map { $0.lowercased() }
            return terms.allSatisfy { term in haystack.contains { $0.contains(term) } }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
