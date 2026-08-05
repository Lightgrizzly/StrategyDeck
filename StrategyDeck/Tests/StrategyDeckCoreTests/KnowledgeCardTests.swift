import XCTest
@testable import StrategyDeckCore

final class KnowledgeCardTests: XCTestCase {
    func testDefaultsAreSensible() {
        let card = KnowledgeCard(deckIDs: ["d"], suitIDs: ["s"], kind: .action, title: "Test")
        XCTAssertFalse(card.isFavorite)
        XCTAssertTrue(card.tags.isEmpty)
        XCTAssertEqual(card.subtitle, "")
        XCTAssertEqual(card.metadata, .generic)
    }

    func testSearchableTextCombinesCommonFieldsAndMetadata() {
        let card = KnowledgeCard(
            deckIDs: ["d"], suitIDs: ["s"], kind: .action,
            metadata: .softwareStrategy(SoftwareStrategyFields(mechanism: "Halve the space")),
            title: "Binary Search",
            tags: ["logarithmic"]
        )
        XCTAssertTrue(card.searchableText.contains("Binary Search"))
        XCTAssertTrue(card.searchableText.contains("logarithmic"))
        XCTAssertTrue(card.searchableText.contains("Halve the space"))
    }

    func testLenientDecodeRequiresOnlyTitle() throws {
        let json = """
        {"title":"Minimal Card"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(KnowledgeCard.self, from: json)
        XCTAssertEqual(decoded.title, "Minimal Card")
        XCTAssertEqual(decoded.kind, .action)
        XCTAssertTrue(decoded.deckIDs.isEmpty)
        XCTAssertTrue(decoded.suitIDs.isEmpty)
    }

    func testRoundTripsJSON() throws {
        let wholeSecond = Date.wholeSecondForTesting()
        let card = KnowledgeCard(
            deckIDs: ["d"], suitIDs: ["s"], kind: .entity,
            metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "t")),
            title: "Card", subtitle: "Sub", tags: ["a", "b"], isFavorite: true,
            createdAt: wholeSecond, updatedAt: wholeSecond
        )
        let encoded = try JSONCoding.encoder.encode(card)
        let decoded = try JSONCoding.decoder.decode(KnowledgeCard.self, from: encoded)
        XCTAssertEqual(decoded, card)
    }
}
