import XCTest
@testable import StrategyDeckCore

final class SeedDecodingTests: XCTestCase {

    func testSeedLoads() {
        let library = SeedCardProvider.makeLibrary()
        XCTAssertFalse(library.cards.isEmpty, "Seed must contain at least one card")
    }

    func testSeedHasOneDeckWithSixSuites() {
        let library = SeedCardProvider.makeLibrary()
        XCTAssertEqual(library.decks.count, 1)
        XCTAssertEqual(library.decks.first?.id, "software-engineering")

        let suiteIDs = Set(library.suits.map(\.id))
        for expectedID in ["search", "transformation", "structure", "state", "reliability", "debugging"] {
            XCTAssertTrue(suiteIDs.contains(expectedID), "Missing suite: \(expectedID)")
        }
    }

    func testSeedCardCount() {
        let library = SeedCardProvider.makeLibrary()
        // At least 44 cards (8+7+8+6+9+8 = 46 in the current seed)
        XCTAssertGreaterThanOrEqual(library.cards.count, 44)
    }

    func testAllSeedCardsHaveTitles() {
        let library = SeedCardProvider.makeLibrary()
        for card in library.cards {
            XCTAssertFalse(card.title.isEmpty, "Card with id \(card.id) has no title")
        }
    }

    func testAllSeedCardsAreActionKindWithSoftwareStrategyMetadata() {
        let library = SeedCardProvider.makeLibrary()
        for card in library.cards {
            XCTAssertEqual(card.kind, .action)
            guard case .softwareStrategy(let fields) = card.metadata else {
                XCTFail("\(card.title) is missing softwareStrategy metadata")
                continue
            }
            XCTAssertFalse(fields.trigger.isEmpty, "\(card.title) has an empty trigger")
        }
    }

    func testSeedRoundTripsJSON() throws {
        let original = SeedCardProvider.makeLibrary()
        let encoded = try JSONCoding.encoder.encode(original)
        let decoded = try JSONCoding.decoder.decode(KnowledgeLibrary.self, from: encoded)
        XCTAssertEqual(original.cards.count, decoded.cards.count)
        XCTAssertEqual(original.cards.first?.title, decoded.cards.first?.title)
    }
}
