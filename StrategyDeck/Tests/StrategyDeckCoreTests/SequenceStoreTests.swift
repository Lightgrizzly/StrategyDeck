import XCTest
@testable import StrategyDeckCore

@MainActor
final class SequenceStoreTests: XCTestCase {

    private func makeStore() -> SequenceStore {
        SequenceStore(persistence: InMemoryPersistence())
    }

    func testAddToTray() {
        let store = makeStore()
        let id = UUID()
        store.addToTray(cardID: id)
        XCTAssertEqual(store.trayItems.count, 1)
        XCTAssertEqual(store.trayItems.first?.cardID, id)
    }

    func testRemoveFromTray() {
        let store = makeStore()
        let id = UUID()
        store.addToTray(cardID: id)
        guard let itemID = store.trayItems.first?.id else { return XCTFail() }
        store.removeFromTray(id: itemID)
        XCTAssertTrue(store.trayItems.isEmpty)
    }

    func testClearTray() {
        let store = makeStore()
        store.addToTray(cardID: UUID())
        store.addToTray(cardID: UUID())
        store.clearTray()
        XCTAssertTrue(store.trayItems.isEmpty)
    }

    func testReorderTray() {
        let store = makeStore()
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        store.addToTray(cardID: id1)
        store.addToTray(cardID: id2)
        store.addToTray(cardID: id3)

        store.moveTrayItem(from: IndexSet(integer: 0), to: 2)

        let ordered = store.trayItems.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.map(\.order), Array(0..<3))
    }

    func testSaveAndOpenSequence() {
        let store = makeStore()
        let id = UUID()
        store.addToTray(cardID: id)
        store.saveSequence(name: "My Sequence", description: "Test")

        XCTAssertEqual(store.savedSequences.count, 1)
        XCTAssertEqual(store.savedSequences.first?.name, "My Sequence")

        store.clearTray()
        XCTAssertTrue(store.trayItems.isEmpty)

        store.openSequence(store.savedSequences[0])
        XCTAssertEqual(store.trayItems.count, 1)
        XCTAssertEqual(store.trayItems.first?.cardID, id)
    }

    func testDeleteSequence() {
        let store = makeStore()
        store.addToTray(cardID: UUID())
        store.saveSequence(name: "To Delete", description: "")
        guard let id = store.savedSequences.first?.id else { return XCTFail() }
        store.deleteSequence(id: id)
        XCTAssertTrue(store.savedSequences.isEmpty)
    }
}
