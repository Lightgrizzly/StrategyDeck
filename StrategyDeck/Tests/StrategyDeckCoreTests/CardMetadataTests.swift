import XCTest
@testable import StrategyDeckCore

final class CardMetadataTests: XCTestCase {
    func testGenericHasNoSearchableText() {
        XCTAssertTrue(CardMetadata.generic.searchableText.isEmpty)
    }

    func testSoftwareStrategySearchableTextIncludesMechanismAndAdvantages() {
        let fields = SoftwareStrategyFields(
            mechanism: "Halve the search space",
            advantages: ["No preprocessing"]
        )
        let text = CardMetadata.softwareStrategy(fields).searchableText
        XCTAssertTrue(text.contains("Halve the search space"))
        XCTAssertTrue(text.contains("No preprocessing"))
    }

    func testSoftwareStrategyFieldsDefaultsAreAllEmpty() {
        let fields = SoftwareStrategyFields()
        XCTAssertEqual(fields.trigger, "")
        XCTAssertTrue(fields.requirements.isEmpty)
    }

    func testCardMetadataRoundTripsJSON() throws {
        let original = CardMetadata.softwareStrategy(SoftwareStrategyFields(trigger: "Find target"))
        let encoded = try JSONCoding.encoder.encode(original)
        let decoded = try JSONCoding.decoder.decode(CardMetadata.self, from: encoded)
        guard case .softwareStrategy(let fields) = decoded else {
            return XCTFail("Expected softwareStrategy case")
        }
        XCTAssertEqual(fields.trigger, "Find target")
    }

    func testGenericRoundTripsJSON() throws {
        let encoded = try JSONCoding.encoder.encode(CardMetadata.generic)
        let decoded = try JSONCoding.decoder.decode(CardMetadata.self, from: encoded)
        guard case .generic = decoded else { return XCTFail("Expected generic case") }
    }

    func testSoftwareStrategyFieldsLenientDecodeFillsMissingKeysWithDefaults() throws {
        let json = "{\"trigger\":\"Find target\"}".data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(SoftwareStrategyFields.self, from: json)
        XCTAssertEqual(decoded.trigger, "Find target")
        XCTAssertEqual(decoded.mechanism, "")
        XCTAssertTrue(decoded.requirements.isEmpty)
    }

    func testUnrecognizedMetadataCaseDecodesToGenericRatherThanThrowing() throws {
        // Simulates a file written by a future app version with a case this
        // version doesn't know about — must not fail the whole card/library.
        let json = "{\"someFutureCase\":{}}".data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(CardMetadata.self, from: json)
        guard case .generic = decoded else { return XCTFail("Expected fallback to .generic") }
    }

    func testEmptyObjectMetadataDecodesToGenericRatherThanThrowing() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(CardMetadata.self, from: json)
        guard case .generic = decoded else { return XCTFail("Expected fallback to .generic") }
    }
}
