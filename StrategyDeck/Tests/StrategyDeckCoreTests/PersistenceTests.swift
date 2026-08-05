import XCTest
@testable import StrategyDeckCore

final class PersistenceTests: XCTestCase {
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

    func testSaveAndLoadCards() throws {
        let card = KnowledgeCard(deckIDs: ["software-engineering"], suitIDs: ["search"], kind: .action, title: "Test Card")
        let cards = [card]
        try persistence.save(cards, to: "cards.json")
        let loaded = try persistence.load([KnowledgeCard].self, from: "cards.json")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Test Card")
    }

    func testFileExistsAfterSave() throws {
        try persistence.save([KnowledgeCard](), to: "cards.json")
        XCTAssertTrue(persistence.fileExists("cards.json"))
    }

    func testDeleteRemovesFile() throws {
        try persistence.save([KnowledgeCard](), to: "cards.json")
        try persistence.delete("cards.json")
        XCTAssertFalse(persistence.fileExists("cards.json"))
    }

    func testSeedLoadsCards() throws {
        let seed = try persistence.loadBundledLibrary()
        XCTAssertFalse(seed.cards.isEmpty)
    }

    func testURLForFilename() {
        let url = persistence.url(for: "test.json")
        XCTAssertEqual(url.lastPathComponent, "test.json")
        XCTAssertTrue(url.path.hasPrefix(tempDir.path))
    }
}
