import XCTest
@testable import StrategyDeckCore

final class CardKindTests: XCTestCase {
    func testEverySymbolIsNonEmpty() {
        for kind in CardKind.allCases {
            XCTAssertFalse(kind.symbol.isEmpty, "\(kind) has no symbol")
        }
    }

    func testEveryDisplayNameIsNonEmpty() {
        for kind in CardKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty, "\(kind) has no display name")
        }
    }

    func testSpecificSymbols() {
        XCTAssertEqual(CardKind.action.symbol, "▶")
        XCTAssertEqual(CardKind.strategy.symbol, "♜")
    }

    func testRoundTripsJSON() throws {
        let encoded = try JSONCoding.encoder.encode(CardKind.observation)
        let decoded = try JSONCoding.decoder.decode(CardKind.self, from: encoded)
        XCTAssertEqual(decoded, .observation)
    }

    func testSymbolsAreUniqueAcrossAllKinds() {
        let symbols = CardKind.allCases.map(\.symbol)
        XCTAssertEqual(Set(symbols).count, symbols.count, "Two kinds share a symbol, defeating grayscale identifiability")
    }
}
