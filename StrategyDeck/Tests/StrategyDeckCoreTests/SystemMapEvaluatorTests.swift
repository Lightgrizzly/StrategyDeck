import XCTest
@testable import StrategyDeckCore

final class SystemMapEvaluatorTests: XCTestCase {

    private func makeCard(
        title: String,
        rules: CardPlayabilityRules = CardPlayabilityRules()
    ) -> KnowledgeCard {
        KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: title, playabilityRules: rules)
    }

    private func makeMap() -> SystemMap {
        SystemMap(title: "Test Map")
    }

    private func makeScenario() -> SystemScenario {
        SystemScenario(name: "Test Scenario", isDefault: true)
    }

    func testUnconstrainedCardIsAvailable() {
        let card = makeCard(title: "No Rules")
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: makeScenario(),
            selectedTargetKind: nil, selectedElementID: nil, allCards: [card]
        )
        XCTAssertEqual(result.automaticStatus, .available)
        XCTAssertEqual(result.effectiveStatus, .available)
        XCTAssertFalse(result.isOverridden)
        XCTAssertTrue(result.isPlayable)
    }

    func testMissingKnownInformationLocksCard() {
        let rules = CardPlayabilityRules(requiredKnownInfo: ["demand rate"])
        let card = makeCard(title: "Forecast Inventory", rules: rules)
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: makeScenario(),
            selectedTargetKind: nil, selectedElementID: nil, allCards: [card]
        )
        XCTAssertEqual(result.automaticStatus, .locked)
        XCTAssertTrue(result.automaticExplanation.contains("Locked because"))
    }

    func testKnownInformationUnlocksCard() {
        let rules = CardPlayabilityRules(requiredKnownInfo: ["demand rate"])
        let card = makeCard(title: "Forecast Inventory", rules: rules)
        var scenario = makeScenario()
        scenario.knownInformation = "The demand rate is now measured."
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: scenario,
            selectedTargetKind: nil, selectedElementID: nil, allCards: [card]
        )
        XCTAssertEqual(result.automaticStatus, .available)
    }

    func testCardIsIrrelevantWhenSelectionDoesNotMatchDeclaredTargets() {
        let rules = CardPlayabilityRules(systemTargetTypes: [.stock])
        let card = makeCard(title: "Measure Inventory", rules: rules)
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: makeScenario(),
            selectedTargetKind: .flow, selectedElementID: nil, allCards: [card]
        )
        XCTAssertEqual(result.automaticStatus, .irrelevant)
        XCTAssertFalse(result.relevance)
    }

    func testCardIsRecommendedWhenSelectionMatchesDeclaredTargets() {
        let rules = CardPlayabilityRules(systemTargetTypes: [.stock])
        let card = makeCard(title: "Measure Inventory", rules: rules)
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: makeScenario(),
            selectedTargetKind: .stock, selectedElementID: nil, allCards: [card]
        )
        XCTAssertEqual(result.automaticStatus, .recommended)
        XCTAssertTrue(result.isPlayable)
    }

    func testUntargetedCardIsNeverIrrelevant() {
        // No systemTargetTypes declared — must remain usable everywhere so
        // pre-existing cards authored before this feature keep working.
        let card = makeCard(title: "General Principle")
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: makeScenario(),
            selectedTargetKind: .flow, selectedElementID: nil, allCards: [card]
        )
        XCTAssertEqual(result.automaticStatus, .available)
    }

    func testReciprocalUnlockWorksFromEitherSide() {
        // Card A declares "unlocks: B" — B never declares "unlockedBy: A"
        // itself. The relationship should still gate B once A is marked
        // active in this scenario, without requiring both sides authored.
        let cardA = makeCard(title: "Measure Demand", rules: CardPlayabilityRules(unlocksCardTitles: ["Adjust Reorder Threshold"]))
        let cardB = makeCard(title: "Adjust Reorder Threshold", rules: CardPlayabilityRules(unlockedByCardTitles: ["Someone Else"]))
        let allCards = [cardA, cardB]

        let before = SystemMapEvaluator.evaluate(
            card: cardB, map: makeMap(), scenario: makeScenario(),
            selectedTargetKind: nil, selectedElementID: nil, allCards: allCards
        )
        XCTAssertEqual(before.automaticStatus, .locked)

        var scenarioAfter = makeScenario()
        scenarioAfter.cardStatusOverrides = [
            SystemCardStatusOverride(cardID: cardA.id, scope: .entireScenario, overriddenStatus: .active)
        ]
        let after = SystemMapEvaluator.evaluate(
            card: cardB, map: makeMap(), scenario: scenarioAfter,
            selectedTargetKind: nil, selectedElementID: nil, allCards: allCards
        )
        XCTAssertEqual(after.automaticStatus, .available)
        XCTAssertTrue(after.satisfiedRequirements.contains(where: { $0.contains("Measure Demand") }))
    }

    // MARK: - Overrides

    func testThisElementOnlyOverrideOnlyAppliesToThatElement() {
        let card = makeCard(title: "No Rules")
        let elementID = UUID()
        let otherElementID = UUID()
        var scenario = makeScenario()
        scenario.cardStatusOverrides = [
            SystemCardStatusOverride(cardID: card.id, targetElementID: elementID, scope: .thisElementOnly, overriddenStatus: .disabled)
        ]

        let onTarget = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: scenario,
            selectedTargetKind: .stock, selectedElementID: elementID, allCards: [card]
        )
        XCTAssertEqual(onTarget.effectiveStatus, .disabled)
        XCTAssertTrue(onTarget.isOverridden)

        let offTarget = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: scenario,
            selectedTargetKind: .stock, selectedElementID: otherElementID, allCards: [card]
        )
        XCTAssertEqual(offTarget.effectiveStatus, .available)
        XCTAssertFalse(offTarget.isOverridden)
    }

    func testEntireScenarioOverrideAppliesRegardlessOfSelection() {
        let card = makeCard(title: "No Rules")
        var scenario = makeScenario()
        scenario.cardStatusOverrides = [
            SystemCardStatusOverride(cardID: card.id, scope: .entireScenario, overriddenStatus: .active)
        ]
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: scenario,
            selectedTargetKind: .goal, selectedElementID: UUID(), allCards: [card]
        )
        XCTAssertEqual(result.effectiveStatus, .active)
        XCTAssertEqual(result.automaticStatus, .available, "automaticStatus must ignore the override")
    }

    func testWorkflowDefaultOverrideAppliesAcrossScenarios() {
        let card = makeCard(title: "No Rules")
        var map = makeMap()
        map.workflowDefaultOverrides = [
            SystemCardStatusOverride(cardID: card.id, scope: .workflowDefault, overriddenStatus: .resolved)
        ]
        let scenarioA = SystemScenario(name: "A")
        let scenarioB = SystemScenario(name: "B")
        for scenario in [scenarioA, scenarioB] {
            let result = SystemMapEvaluator.evaluate(
                card: card, map: map, scenario: scenario,
                selectedTargetKind: nil, selectedElementID: nil, allCards: [card]
            )
            XCTAssertEqual(result.effectiveStatus, .resolved)
        }
    }

    func testNarrowerScopeWinsOverBroaderScope() {
        let card = makeCard(title: "No Rules")
        let elementID = UUID()
        var scenario = makeScenario()
        scenario.cardStatusOverrides = [
            SystemCardStatusOverride(cardID: card.id, scope: .entireScenario, overriddenStatus: .disabled),
            SystemCardStatusOverride(cardID: card.id, targetElementID: elementID, scope: .thisElementOnly, overriddenStatus: .active)
        ]
        let result = SystemMapEvaluator.evaluate(
            card: card, map: makeMap(), scenario: scenario,
            selectedTargetKind: .stock, selectedElementID: elementID, allCards: [card]
        )
        XCTAssertEqual(result.effectiveStatus, .active, "the element-specific override should win over the scenario-wide one")
    }

    func testDifferentScenariosEvaluateIndependently() {
        // The same map, same selection, two different scenarios — a manual
        // override in one must never leak into the other.
        let card = makeCard(title: "No Rules")
        let map = makeMap()
        var scenarioA = SystemScenario(name: "A")
        scenarioA.cardStatusOverrides = [SystemCardStatusOverride(cardID: card.id, scope: .entireScenario, overriddenStatus: .disabled)]
        let scenarioB = SystemScenario(name: "B")

        let resultA = SystemMapEvaluator.evaluate(card: card, map: map, scenario: scenarioA, selectedTargetKind: nil, selectedElementID: nil, allCards: [card])
        let resultB = SystemMapEvaluator.evaluate(card: card, map: map, scenario: scenarioB, selectedTargetKind: nil, selectedElementID: nil, allCards: [card])

        XCTAssertEqual(resultA.effectiveStatus, .disabled)
        XCTAssertEqual(resultB.effectiveStatus, .available)
    }

    func testTargetKindMapping() {
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .stock), .stock)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .goal), .goal)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .constraint), .constraint)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .delay), .delay)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .note), .note)
    }
}
