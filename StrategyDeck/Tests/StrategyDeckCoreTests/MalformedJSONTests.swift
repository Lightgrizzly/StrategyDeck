import XCTest
@testable import StrategyDeckCore

final class MalformedJSONTests: XCTestCase {
    private var tempDir: URL!
    private var persistence: JSONPersistenceService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        persistence = JSONPersistenceService(containerDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testMalformedJSONThrowsDecodeFailed() {
        let bad = "{ not valid json !!!".data(using: .utf8)!
        try! bad.write(to: persistence.url(for: "cards.json"))
        XCTAssertThrowsError(try persistence.load([KnowledgeCard].self, from: "cards.json")) { error in
            if case PersistenceError.decodeFailed = error { /* expected */ }
            else { XCTFail("Expected decodeFailed, got \(error)") }
        }
    }

    func testWrongTypeThrowsDecodeFailed() throws {
        let encoded = try JSONCoding.encoder.encode([1, 2, 3])
        try encoded.write(to: persistence.url(for: "cards.json"))
        XCTAssertThrowsError(try persistence.load(KnowledgeCard.self, from: "cards.json")) { error in
            if case PersistenceError.decodeFailed = error { /* expected */ }
            else { XCTFail("Unexpected error type: \(error)") }
        }
    }

    func testMissingFileThrowsDecodeFailed() {
        XCTAssertThrowsError(try persistence.load([KnowledgeCard].self, from: "nonexistent.json"))
    }

    func testCardWithMissingOptionalFieldsDecodes() throws {
        let json = """
        [{"title":"Minimal Card"}]
        """.data(using: .utf8)!
        try json.write(to: persistence.url(for: "cards.json"))
        let loaded = try persistence.load([KnowledgeCard].self, from: "cards.json")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Minimal Card")
        XCTAssertEqual(loaded.first?.kind, .action)
        XCTAssertTrue(loaded.first?.suitIDs.isEmpty ?? false)
        XCTAssertTrue(loaded.first?.tags.isEmpty ?? false)
    }

    func testImportExportRoundTrip() throws {
        let service = ImportExportService()
        let original = SeedCardProvider.makeLibrary()
        let exported = try service.export(original)
        let imported = try service.import(from: exported)
        XCTAssertEqual(original.cards.count, imported.cards.count)
    }

    func testImportInvalidJSONThrows() {
        let service = ImportExportService()
        let bad = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try service.import(from: bad))
    }
}
