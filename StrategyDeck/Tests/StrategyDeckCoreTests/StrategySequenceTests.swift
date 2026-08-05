import XCTest
@testable import StrategyDeckCore

final class StrategySequenceTests: XCTestCase {
    func testNormalizedItemsAreSortedAndReindexedFromZero() {
        let fifth = UUID(), second = UUID(), ninth = UUID()
        let sequence = StrategySequence(
            name: "Test",
            orderedItems: [
                StrategySequenceItem(cardID: fifth, order: 5),
                StrategySequenceItem(cardID: second, order: 2),
                StrategySequenceItem(cardID: ninth, order: 9)
            ]
        )
        let normalized = sequence.normalizedItems
        // Identity check, not just position: this fails if sorting is ever
        // dropped, since reindex-by-position alone would still produce [0,1,2].
        XCTAssertEqual(normalized.map(\.cardID), [second, fifth, ninth])
        XCTAssertEqual(normalized.map(\.order), [0, 1, 2])
    }

    func testDefaultsAreSensible() {
        let sequence = StrategySequence(name: "Test")
        XCTAssertEqual(sequence.description, "")
        XCTAssertEqual(sequence.scenario, "")
        XCTAssertTrue(sequence.deckIDs.isEmpty)
        XCTAssertTrue(sequence.orderedItems.isEmpty)
    }

    func testItemLenientDecodeRequiresOnlyCardID() throws {
        let json = """
        {"cardID":"\(UUID().uuidString)"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(StrategySequenceItem.self, from: json)
        XCTAssertEqual(decoded.order, 0)
        XCTAssertEqual(decoded.note, "")
        XCTAssertNil(decoded.relationshipToPrevious)
    }

    func testRoundTripsJSON() throws {
        // Date.wholeSecondForTesting() (Tests/StrategyDeckCoreTests/TestSupport/
        // DateTestSupport.swift, added during Task 6) exists because
        // JSONCoding's .iso8601 date strategy has whole-second resolution — a
        // sub-second Date() never compares equal after round-tripping.
        let wholeSecond = Date.wholeSecondForTesting()
        let sequence = StrategySequence(
            name: "Reliable API Integration",
            description: "desc",
            scenario: "A production file is missing data.",
            orderedItems: [
                StrategySequenceItem(cardID: UUID(), order: 0, note: "start here", relationshipToPrevious: nil),
                StrategySequenceItem(cardID: UUID(), order: 1, relationshipToPrevious: .canFollow)
            ],
            createdAt: wholeSecond,
            updatedAt: wholeSecond
        )
        let encoded = try JSONCoding.encoder.encode(sequence)
        let decoded = try JSONCoding.decoder.decode(StrategySequence.self, from: encoded)
        XCTAssertEqual(decoded, sequence)
    }
}
