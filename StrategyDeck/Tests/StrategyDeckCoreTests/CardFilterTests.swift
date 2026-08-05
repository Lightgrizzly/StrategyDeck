import XCTest
@testable import StrategyDeckCore

final class CardFilterTests: XCTestCase {
    private func suits() -> [CardSuit] {
        [
            CardSuit(id: "search", deckID: "d", name: "Search"),
            CardSuit(id: "transformation", deckID: "d", name: "Transformation"),
            CardSuit(id: "search-sub", deckID: "d", parentSuitID: "search", name: "Search Sub")
        ]
    }

    private func cards() -> [KnowledgeCard] {
        [
            KnowledgeCard(deckIDs: ["d"], suitIDs: ["search"], kind: .action,
                          metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "Find target in sorted collection", mechanism: "Halve the search space")),
                          title: "Binary Search", tags: ["sorted", "logarithmic"]),
            KnowledgeCard(deckIDs: ["d"], suitIDs: ["search-sub"], kind: .action,
                          metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "Repeatedly checking whether values exist", mechanism: "Insert into hash map")),
                          title: "Hash-Based Lookup", tags: ["hash", "dictionary"]),
            KnowledgeCard(deckIDs: ["d"], suitIDs: ["transformation"], kind: .action,
                          metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "Transform every element", mechanism: "Apply function to each")),
                          title: "Map", tags: ["transform"]),
            KnowledgeCard(deckIDs: ["other-deck"], suitIDs: ["search"], kind: .action, title: "Different Deck Card")
        ]
    }

    func testEmptyFilterReturnsAll() {
        XCTAssertEqual(CardFilter().apply(to: cards()).count, 4)
    }

    func testQueryMatchesTitle() {
        let result = CardFilter(query: "binary").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testQueryMatchesMetadataMechanism() {
        let result = CardFilter(query: "halve").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testQueryMatchesTag() {
        let result = CardFilter(query: "logarithmic").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testDeckIDScopesToOneDeck() {
        let result = CardFilter(deckID: "other-deck").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Different Deck Card"])
    }

    func testSuiteFilterMatchesExactSuite() {
        let result = CardFilter(suitID: "transformation").apply(to: cards(), suits: suits())
        XCTAssertEqual(result.map(\.title), ["Map"])
    }

    func testSuiteFilterExpandsToDescendantSuits() {
        let result = CardFilter(suitID: "search").apply(to: cards(), suits: suits())
        XCTAssertEqual(Set(result.map(\.title)), Set(["Binary Search", "Hash-Based Lookup", "Different Deck Card"]))
    }

    func testFavoritesFilter() {
        var c = cards()
        c[0].isFavorite = true
        let result = CardFilter(favoritesOnly: true).apply(to: c)
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testFavoritesFirstInSort() {
        var c = cards()
        c[2].isFavorite = true
        let result = CardFilter().apply(to: c)
        XCTAssertEqual(result.first?.title, "Map")
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(CardFilter(query: "xyzzy_no_match").apply(to: cards()).isEmpty)
    }

    func testMultiWordQueryRequiresAllTermsSomewhere() {
        let result = CardFilter(query: "binary sorted").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testSuitFilterWithoutSuitsArrayFallsBackToExactMatchOnly() {
        // Caller forgot to pass `suits:` — descendantIDs(of:) over an empty
        // array degrades to {suitID} itself, so this must NOT expand to
        // "search-sub" the way testSuiteFilterExpandsToDescendantSuits does.
        let result = CardFilter(suitID: "search").apply(to: cards())
        XCTAssertEqual(Set(result.map(\.title)), Set(["Binary Search", "Different Deck Card"]))
    }

    func testIsActive() {
        XCTAssertFalse(CardFilter().isActive)
        XCTAssertFalse(CardFilter(query: "   ").isActive, "Whitespace-only query should not count as active")
        XCTAssertTrue(CardFilter(query: "x").isActive)
        XCTAssertTrue(CardFilter(deckID: "d").isActive)
        XCTAssertTrue(CardFilter(suitID: "s").isActive)
        XCTAssertTrue(CardFilter(favoritesOnly: true).isActive)
    }
}
