import XCTest
@testable import StrategyDeckCore

final class CardRelationshipTests: XCTestCase {
    func testLabelsAndInverseLabelsAreNonEmpty() {
        for type in CardRelationshipType.allCases {
            XCTAssertFalse(type.label.isEmpty)
            XCTAssertFalse(type.inverseLabel.isEmpty)
        }
    }

    func testRequiresInverseIsRequiredBy() {
        XCTAssertEqual(CardRelationshipType.requires.label, "Requires")
        XCTAssertEqual(CardRelationshipType.requires.inverseLabel, "Required by")
    }

    func testCanFollowAndCanPrecedeAreEachOthersInverse() {
        // A canFollow B (A comes after B) means, from B's side, "B canPrecede A".
        XCTAssertEqual(CardRelationshipType.canFollow.inverseLabel, CardRelationshipType.canPrecede.label)
        XCTAssertEqual(CardRelationshipType.canPrecede.inverseLabel, CardRelationshipType.canFollow.label)
    }

    func testSymmetricRelationshipsReadTheSameFromEitherSide() {
        // contrasts / combinesWith / equivalentExpression / relatedStrategy are
        // genuine symmetric relations — deliberately self-mapped, not an oversight.
        for type: CardRelationshipType in [.contrasts, .combinesWith, .equivalentExpression, .relatedStrategy] {
            XCTAssertEqual(type.label, type.inverseLabel, "\(type) is modeled as symmetric")
        }
    }

    func testDefaultIDIsGenerated() {
        let rel = CardRelationship(sourceCardID: UUID(), targetCardID: UUID(), type: .enables)
        XCTAssertNotNil(rel.id)
    }

    func testLenientDecodeDefaultsNoteToEmpty() throws {
        let json = """
        {"sourceCardID":"\(UUID().uuidString)","targetCardID":"\(UUID().uuidString)","type":"combinesWith"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(CardRelationship.self, from: json)
        XCTAssertEqual(decoded.note, "")
    }

    func testRoundTripsJSON() throws {
        let rel = CardRelationship(sourceCardID: UUID(), targetCardID: UUID(), type: .requires, note: "needs setup")
        let encoded = try JSONCoding.encoder.encode(rel)
        let decoded = try JSONCoding.decoder.decode(CardRelationship.self, from: encoded)
        XCTAssertEqual(decoded, rel)
    }
}
