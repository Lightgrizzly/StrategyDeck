import XCTest
@testable import StrategyDeckCore

@MainActor
final class SystemMapStoreTests: XCTestCase {

    private func makeStore(_ persistence: PersistenceService = InMemoryPersistence()) -> SystemMapStore {
        SystemMapStore(persistence: persistence)
    }

    // MARK: - Map lifecycle

    func testCreateSystemMapStartsWithOneDefaultScenario() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map", primaryGoal: "Ship it")
        XCTAssertEqual(store.currentSystemMap?.title, "Test Map")
        XCTAssertEqual(store.currentSystemMap?.scenarios.count, 1)
        XCTAssertEqual(store.currentSystemMap?.scenarios.first?.isDefault, true)
        XCTAssertEqual(store.currentSystemMap?.primaryGoal, "Ship it")
    }

    // MARK: - Shared structure

    func testAddElementIsVisibleInEveryScenario() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        store.createScenario(name: "Second Scenario")
        store.addElement(SystemElement(kind: .stock, name: "Inventory"))

        guard let map = store.currentSystemMap else { return XCTFail("no map") }
        XCTAssertEqual(map.elements.count, 1)
        for scenario in map.scenarios {
            XCTAssertEqual(map.effectiveElements(for: scenario).count, 1)
        }
    }

    func testDeletingElementCleansUpScenarioOverrides() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let element = SystemElement(kind: .stock, name: "Inventory")
        store.addElement(element)
        guard let scenarioID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }
        store.setElementOverride(elementID: element.id, currentValue: 10, state: .atRisk, notes: nil, inScenario: scenarioID)
        store.deleteElement(id: element.id)

        XCTAssertEqual(store.currentSystemMap?.elements.count, 0)
        XCTAssertNil(store.currentSystemMap?.scenarios.first?.elementOverrides[element.id])
    }

    // MARK: - Scenario management

    func testDuplicateScenarioCopiesOverridesIndependently() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let element = SystemElement(kind: .stock, name: "Inventory", currentValue: 50)
        store.addElement(element)
        guard let originalID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }
        store.setElementOverride(elementID: element.id, currentValue: 0, state: .atRisk, notes: nil, inScenario: originalID)

        store.duplicateScenario(id: originalID)
        guard let map = store.currentSystemMap, map.scenarios.count == 2 else { return XCTFail("expected 2 scenarios") }
        let duplicateID = map.scenarios.first(where: { $0.id != originalID })!.id

        // Mutating the duplicate must not affect the original.
        store.setElementOverride(elementID: element.id, currentValue: 999, state: nil, notes: nil, inScenario: duplicateID)

        let refreshed = store.currentSystemMap!
        XCTAssertEqual(refreshed.scenarios.first(where: { $0.id == originalID })?.elementOverrides[element.id]?.currentValue, 0)
        XCTAssertEqual(refreshed.scenarios.first(where: { $0.id == duplicateID })?.elementOverrides[element.id]?.currentValue, 999)
    }

    func testDeleteScenarioRefusesToRemoveTheLastOne() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        guard let onlyID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }
        store.deleteScenario(id: onlyID)
        XCTAssertEqual(store.currentSystemMap?.scenarios.count, 1, "must always keep at least one scenario")
    }

    func testResetScenarioClearsAllOverrides() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let element = SystemElement(kind: .stock, name: "Inventory")
        store.addElement(element)
        guard let scenarioID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }
        store.setElementOverride(elementID: element.id, currentValue: 5, state: .disabled, notes: "test", inScenario: scenarioID)
        store.setKnownInformation("something known", inScenario: scenarioID)

        store.resetScenario(id: scenarioID)

        let scenario = store.currentSystemMap!.scenarios.first!
        XCTAssertTrue(scenario.elementOverrides.isEmpty)
        XCTAssertTrue(scenario.knownInformation.isEmpty)
    }

    // MARK: - Card status overrides / intervention

    func testApplyInterventionRecordsActiveOverride() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let card = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: "Measure Demand")
        guard let scenarioID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }

        store.applyIntervention(card: card, targetElementID: nil, scenarioID: scenarioID)

        let overrides = store.currentSystemMap!.scenarios.first!.cardStatusOverrides
        XCTAssertEqual(overrides.count, 1)
        XCTAssertEqual(overrides.first?.overriddenStatus, .active)
        XCTAssertEqual(overrides.first?.scope, .thisElementOnly)
    }

    func testExhaustsAfterUseCardInterventionRecordsExhausted() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let rules = CardPlayabilityRules(exhaustsAfterUse: true)
        let card = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: "One-Shot", playabilityRules: rules)
        guard let scenarioID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }

        store.applyIntervention(card: card, targetElementID: nil, scenarioID: scenarioID)
        XCTAssertEqual(store.currentSystemMap?.scenarios.first?.cardStatusOverrides.first?.overriddenStatus, .exhausted)
    }

    func testSettingOverrideReplacesAnyExistingOneForSameCardScopeAndTarget() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let card = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: "Card")
        guard let scenarioID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }

        store.setCardStatusOverride(cardID: card.id, targetElementID: nil, scope: .entireScenario, status: .locked, reason: "first", scenarioID: scenarioID)
        store.setCardStatusOverride(cardID: card.id, targetElementID: nil, scope: .entireScenario, status: .disabled, reason: "second", scenarioID: scenarioID)

        let overrides = store.currentSystemMap!.scenarios.first!.cardStatusOverrides
        XCTAssertEqual(overrides.count, 1, "should replace, not accumulate duplicates")
        XCTAssertEqual(overrides.first?.overriddenStatus, .disabled)
    }

    func testClearCardStatusOverrideRemovesIt() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let card = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: "Card")
        guard let scenarioID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }

        store.setCardStatusOverride(cardID: card.id, targetElementID: nil, scope: .entireScenario, status: .active, reason: "", scenarioID: scenarioID)
        store.clearCardStatusOverride(cardID: card.id, scope: .entireScenario, targetElementID: nil, scenarioID: scenarioID)

        XCTAssertTrue(store.currentSystemMap!.scenarios.first!.cardStatusOverrides.isEmpty)
    }

    func testWorkflowDefaultOverrideStoresOnMapNotScenario() {
        let store = makeStore()
        store.createSystemMap(title: "Test Map")
        let card = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: "Card")
        guard let scenarioID = store.currentSystemMap?.scenarios.first?.id else { return XCTFail("no scenario") }

        store.setCardStatusOverride(cardID: card.id, targetElementID: nil, scope: .workflowDefault, status: .resolved, reason: "", scenarioID: scenarioID)

        XCTAssertEqual(store.currentSystemMap?.workflowDefaultOverrides.count, 1)
        XCTAssertTrue(store.currentSystemMap?.scenarios.first?.cardStatusOverrides.isEmpty ?? false)
    }

    // MARK: - Persistence round trip

    func testPersistenceRoundTrip() {
        let persistence = InMemoryPersistence()
        let store = makeStore(persistence)
        store.createSystemMap(title: "Persisted Map")
        store.addElement(SystemElement(kind: .stock, name: "Inventory", currentValue: 42))
        store.createScenario(name: "Second Scenario")

        let reloaded = makeStore(persistence)
        reloaded.load()
        XCTAssertEqual(reloaded.systemMaps.count, 1)
        XCTAssertEqual(reloaded.systemMaps.first?.title, "Persisted Map")
        XCTAssertEqual(reloaded.systemMaps.first?.elements.first?.currentValue, 42)
        XCTAssertEqual(reloaded.systemMaps.first?.scenarios.count, 2)
    }

    func testTemplateLoadsWithExpectedStructure() {
        let map = SystemMapTemplates.inventoryResilience()
        XCTAssertEqual(map.title, "Inventory Resilience")
        XCTAssertEqual(map.elements.filter { $0.kind == .stock }.count, 3)
        XCTAssertEqual(map.flows.count, 4)
        XCTAssertEqual(map.scenarios.count, 2)
        XCTAssertEqual(map.scenarios.first(where: { $0.isDefault })?.name, "Normal Operations")
        XCTAssertFalse(map.primaryGoal.isEmpty)
    }

    // MARK: - Legacy migration

    /// A hand-authored pre-scenario save file: two steps, the latest one
    /// carrying an updated stock value and a recorded card play. Verifies
    /// the migration path in `SystemMap.init(from:)` without going through
    /// the store at all (pure decode).
    func testLegacyStepBasedSaveMigratesToScenarios() throws {
        let legacyJSON = """
        [
          {
            "id": "10000000-0000-0000-0000-000000000001",
            "title": "Legacy Map",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-02T00:00:00Z",
            "currentStepID": "10000000-0000-0000-0000-000000000011",
            "steps": [
              {
                "id": "10000000-0000-0000-0000-000000000010",
                "index": 0,
                "title": "Step 1",
                "elements": [
                  { "id": "10000000-0000-0000-0000-000000000020", "kind": "stock", "name": "Inventory" }
                ],
                "flows": [],
                "relationships": [],
                "knownInformation": "Initial known info",
                "cardPlays": []
              },
              {
                "id": "10000000-0000-0000-0000-000000000011",
                "index": 1,
                "title": "Step 2",
                "elements": [
                  { "id": "10000000-0000-0000-0000-000000000020", "kind": "stock", "name": "Inventory", "currentValue": 42 }
                ],
                "flows": [],
                "relationships": [],
                "knownInformation": "Latest known info",
                "cardPlays": [
                  { "id": "10000000-0000-0000-0000-000000000030", "cardID": "10000000-0000-0000-0000-000000000099", "targetKind": "stock", "status": "active", "playedAtStepIndex": 1 }
                ]
              }
            ]
          }
        ]
        """
        let data = legacyJSON.data(using: .utf8)!
        let maps = try JSONCoding.decoder.decode([SystemMap].self, from: data)
        XCTAssertEqual(maps.count, 1)
        let map = maps[0]

        XCTAssertEqual(map.elements.count, 1)
        XCTAssertEqual(map.elements.first?.name, "Inventory")
        XCTAssertEqual(map.elements.first?.currentValue, 42, "base structure should come from the latest step")

        XCTAssertEqual(map.scenarios.count, 2)
        XCTAssertEqual(map.scenarios.first(where: { $0.name == "Current State" })?.isDefault, true)
        XCTAssertNotNil(map.scenarios.first(where: { $0.name == "Initial State" }))

        let currentState = map.scenarios.first(where: { $0.name == "Current State" })!
        XCTAssertEqual(currentState.knownInformation, "Latest known info")
        XCTAssertEqual(currentState.cardStatusOverrides.count, 1)
        XCTAssertEqual(currentState.cardStatusOverrides.first?.overriddenStatus, .active)

        let initialState = map.scenarios.first(where: { $0.name == "Initial State" })!
        XCTAssertEqual(initialState.knownInformation, "Initial known info")

        XCTAssertEqual(map.legacyStepsArchive?.count, 2, "original step history must be preserved, not discarded")

        // And re-encoding must not blow up or reintroduce the old "steps" key.
        let reencoded = try JSONCoding.encoder.encode(map)
        let redecoded = try JSONCoding.decoder.decode(SystemMap.self, from: reencoded)
        XCTAssertEqual(redecoded.scenarios.count, 2)
    }

    func testBrandNewMapWithNoLegacyDataDecodesCleanly() throws {
        let store = makeStore()
        store.createSystemMap(title: "Fresh Map")
        let encoded = try JSONCoding.encoder.encode(store.systemMaps)
        let decoded = try JSONCoding.decoder.decode([SystemMap].self, from: encoded)
        XCTAssertEqual(decoded.first?.scenarios.count, 1)
        XCTAssertNil(decoded.first?.legacyStepsArchive)
    }
}
