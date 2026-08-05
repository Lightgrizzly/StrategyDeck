import XCTest
@testable import StrategyDeckCore

final class KnowledgeLibraryTests: XCTestCase {
    func testDefaultsAreEmpty() {
        let library = KnowledgeLibrary()
        XCTAssertEqual(library.version, KnowledgeLibrary.currentVersion)
        XCTAssertTrue(library.decks.isEmpty)
        XCTAssertTrue(library.suits.isEmpty)
        XCTAssertTrue(library.cards.isEmpty)
        XCTAssertTrue(library.relationships.isEmpty)
        XCTAssertTrue(library.sequences.isEmpty)
    }

    func testRoundTripsJSON() throws {
        // See Date.wholeSecondForTesting()'s doc comment (TestSupport/DateTestSupport.swift).
        let wholeSecond = Date.wholeSecondForTesting()
        let library = KnowledgeLibrary(
            decks: [KnowledgeDeck(id: "d", name: "Deck")],
            suits: [CardSuit(id: "s", deckID: "d", name: "Suit")],
            cards: [KnowledgeCard(deckIDs: ["d"], suitIDs: ["s"], kind: .action, title: "Card", createdAt: wholeSecond, updatedAt: wholeSecond)],
            relationships: [CardRelationship(sourceCardID: UUID(), targetCardID: UUID(), type: .enables)],
            sequences: [StrategySequence(name: "Seq")]
        )
        let encoded = try JSONCoding.encoder.encode(library)
        let decoded = try JSONCoding.decoder.decode(KnowledgeLibrary.self, from: encoded)
        XCTAssertEqual(decoded.decks, library.decks)
        XCTAssertEqual(decoded.suits, library.suits)
        XCTAssertEqual(decoded.cards, library.cards)
        XCTAssertEqual(decoded.relationships, library.relationships)
        XCTAssertEqual(decoded.sequences.map(\.name), library.sequences.map(\.name))
    }

    func testLenientDecodeOfEmptyObjectUsesDefaults() throws {
        let decoded = try JSONCoding.decoder.decode(KnowledgeLibrary.self, from: "{}".data(using: .utf8)!)
        XCTAssertEqual(decoded.version, KnowledgeLibrary.currentVersion)
        XCTAssertTrue(decoded.cards.isEmpty)
    }
}
