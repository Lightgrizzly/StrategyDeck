import XCTest
@testable import StrategyDeckCore

final class CardSuitTreeTests: XCTestCase {
    // Deck "d" has root suits A and B. A has children A1, A2. A1 has child A1a.
    private func fixture() -> [CardSuit] {
        [
            CardSuit(id: "A", deckID: "d", parentSuitID: nil, name: "A", iconName: "a", displayOrder: 0),
            CardSuit(id: "B", deckID: "d", parentSuitID: nil, name: "B", iconName: "b", displayOrder: 1),
            CardSuit(id: "A1", deckID: "d", parentSuitID: "A", name: "A1", iconName: "a1", displayOrder: 0),
            CardSuit(id: "A2", deckID: "d", parentSuitID: "A", name: "A2", iconName: "a2", displayOrder: 1),
            CardSuit(id: "A1a", deckID: "d", parentSuitID: "A1", name: "A1a", iconName: "a1a", displayOrder: 0),
            CardSuit(id: "OTHER-DECK-ROOT", deckID: "other", parentSuitID: nil, name: "X", iconName: "x", displayOrder: 0)
        ]
    }

    func testRootSuitsAreScopedToDeckAndSortedByDisplayOrder() {
        let roots = fixture().rootSuits(deckID: "d")
        XCTAssertEqual(roots.map(\.id), ["A", "B"])
    }

    func testChildrenAreSortedByDisplayOrder() {
        let children = fixture().children(of: "A")
        XCTAssertEqual(children.map(\.id), ["A1", "A2"])
    }

    func testChildrenOfLeafSuitIsEmpty() {
        XCTAssertTrue(fixture().children(of: "B").isEmpty)
    }

    func testDescendantIDsIncludesSelfAndAllNestedLevels() {
        let ids = fixture().descendantIDs(of: "A")
        XCTAssertEqual(ids, Set(["A", "A1", "A2", "A1a"]))
    }

    func testDescendantIDsOfLeafIsJustItself() {
        XCTAssertEqual(fixture().descendantIDs(of: "B"), Set(["B"]))
    }

    func testDescendantIDsTerminatesOnACyclicParentChain() {
        // C1 -> C2 -> C1: a malformed/imported file could produce this.
        // descendantIDs must not infinite-recurse; each ID is visited once.
        let cyclic: [CardSuit] = [
            CardSuit(id: "C1", deckID: "d", parentSuitID: "C2", name: "C1", displayOrder: 0),
            CardSuit(id: "C2", deckID: "d", parentSuitID: "C1", name: "C2", displayOrder: 0)
        ]
        XCTAssertEqual(cyclic.descendantIDs(of: "C1"), Set(["C1", "C2"]))
    }

    func testKnowledgeDeckDecodesLeniently() throws {
        let json = """
        {"id":"d","name":"Deck"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(KnowledgeDeck.self, from: json)
        XCTAssertEqual(decoded.id, "d")
        XCTAssertEqual(decoded.description, "")
        XCTAssertEqual(decoded.displayOrder, 0)
    }
}
