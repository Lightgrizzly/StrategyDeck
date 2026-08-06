import XCTest
@testable import StrategyDeckCore

@MainActor
final class SystemMapStoreTests: XCTestCase {

    private func makeStore(_ persistence: PersistenceService = InMemoryPersistence()) -> SystemMapStore {
        SystemMapStore(persistence: persistence)
    }

    func testCreateSystemMapStartsWithOneStep() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map", primaryGoal: "Ship it")
        XCTAssertEqual(store.currentSystemMap?.title, "Test Map")
        XCTAssertEqual(store.currentSystemMap?.steps.count, 1)
        XCTAssertEqual(store.currentSystemMap?.primaryGoal, "Ship it")
    }

    func testAddElementTargetsLatestStep() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let stock = SystemElement(kind: .stock, name: "Inventory")
        store.addElement(stock)
        XCTAssertEqual(store.currentSystemMap?.latestStep?.elements.count, 1)
        XCTAssertEqual(store.currentSystemMap?.latestStep?.elements.first?.name, "Inventory")
    }

    func testNextStepDuplicatesStructureForward() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        store.addElement(SystemElement(kind: .stock, name: "Inventory"))
        store.addStep()
        XCTAssertEqual(store.currentSystemMap?.steps.count, 2)
        XCTAssertEqual(store.currentSystemMap?.latestStep?.index, 1)
        XCTAssertEqual(store.currentSystemMap?.latestStep?.elements.count, 1)
        XCTAssertTrue(store.currentSystemMap?.isViewingLatestStep ?? false)
    }

    func testViewingHistoricalStepDoesNotAffectLatest() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let firstStepID = store.currentSystemMap!.steps[0].id
        store.addStep()
        store.setCurrentStep(id: firstStepID)
        XCTAssertFalse(store.currentSystemMap?.isViewingLatestStep ?? true)
        store.returnToLatestStep()
        XCTAssertTrue(store.currentSystemMap?.isViewingLatestStep ?? false)
    }

    func testPlayCardRecordsPlayAndChangeEntry() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let card = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: "Measure Demand")
        store.playCard(card: card, targetElementID: nil, targetKind: .system, allCards: [card])
        let latest = store.currentSystemMap?.latestStep
        XCTAssertEqual(latest?.cardPlays.count, 1)
        XCTAssertEqual(latest?.cardPlays.first?.status, .active)
        XCTAssertTrue(latest?.changes.contains(where: { $0.kind == .cardPlayed }) ?? false)
    }

    func testExhaustsAfterUseCardIsRecordedAsExhausted() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let rules = CardPlayabilityRules(exhaustsAfterUse: true)
        let card = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: "One-Shot", playabilityRules: rules)
        store.playCard(card: card, targetElementID: nil, targetKind: .system, allCards: [card])
        XCTAssertEqual(store.currentSystemMap?.latestStep?.cardPlays.first?.status, .exhausted)
    }

    func testPersistenceRoundTrip() {
        let persistence = InMemoryPersistence()
        let store = makeStore(persistence)
        store.createSystemMap(title: "Persisted Map")
        store.addElement(SystemElement(kind: .stock, name: "Inventory", currentValue: 42))

        let reloaded = makeStore(persistence)
        reloaded.load()
        XCTAssertEqual(reloaded.systemMaps.count, 1)
        XCTAssertEqual(reloaded.systemMaps.first?.title, "Persisted Map")
        XCTAssertEqual(reloaded.systemMaps.first?.latestStep?.elements.first?.currentValue, 42)
    }

    func testTemplateLoadsWithExpectedStructure() {
        let map = SystemMapTemplates.inventoryResilience()
        XCTAssertEqual(map.title, "Inventory Resilience")
        XCTAssertEqual(map.latestStep?.elements.filter { $0.kind == .stock }.count, 3)
        XCTAssertEqual(map.latestStep?.flows.count, 4)
        XCTAssertFalse(map.primaryGoal.isEmpty)
    }
}
