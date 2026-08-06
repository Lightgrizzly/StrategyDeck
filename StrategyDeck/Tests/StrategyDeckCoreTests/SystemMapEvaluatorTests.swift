import XCTest
@testable import StrategyDeckCore

final class SystemMapEvaluatorTests: XCTestCase {

    private func makeCard(
        title: String,
        rules: CardPlayabilityRules = CardPlayabilityRules()
    ) -> KnowledgeCard {
        KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, title: title, playabilityRules: rules)
    }

    private func makeStep(index: Int = 0) -> SystemStep {
        SystemStep(index: index)
    }

    func testUnconstrainedCardIsAvailable() {
        let card = makeCard(title: "No Rules")
        let result = SystemMapEvaluator.evaluate(card: card, step: makeStep(), selectedTargetKind: nil, allCards: [card])
        XCTAssertEqual(result.status, .available)
        XCTAssertTrue(result.isPlayable)
    }

    func testMissingKnownInformationLocksCard() {
        let rules = CardPlayabilityRules(requiredKnownInfo: ["demand rate"])
        let card = makeCard(title: "Forecast Inventory", rules: rules)
        let result = SystemMapEvaluator.evaluate(card: card, step: makeStep(), selectedTargetKind: nil, allCards: [card])
        XCTAssertEqual(result.status, .locked)
        XCTAssertTrue(result.explanation.contains("Locked because"))
    }

    func testKnownInformationUnlocksCard() {
        let rules = CardPlayabilityRules(requiredKnownInfo: ["demand rate"])
        let card = makeCard(title: "Forecast Inventory", rules: rules)
        var step = makeStep()
        step.knownInformation = "The demand rate is now measured."
        let result = SystemMapEvaluator.evaluate(card: card, step: step, selectedTargetKind: nil, allCards: [card])
        XCTAssertEqual(result.status, .available)
    }

    func testPlayedCardBecomesActive() {
        let card = makeCard(title: "Measure Demand")
        var step = makeStep()
        step.cardPlays = [SystemCardPlay(cardID: card.id, targetKind: .stock, status: .active, playedAtStepIndex: 0)]
        let result = SystemMapEvaluator.evaluate(card: card, step: step, selectedTargetKind: nil, allCards: [card])
        XCTAssertEqual(result.status, .active)
        XCTAssertFalse(result.isPlayable)
    }

    func testExhaustsAfterUseCardBecomesExhaustedOncePlayed() {
        let rules = CardPlayabilityRules(exhaustsAfterUse: true)
        let card = makeCard(title: "One-Shot Fix", rules: rules)
        var step = makeStep()
        step.cardPlays = [SystemCardPlay(cardID: card.id, targetKind: .stock, status: .exhausted, playedAtStepIndex: 0)]
        let result = SystemMapEvaluator.evaluate(card: card, step: step, selectedTargetKind: nil, allCards: [card])
        XCTAssertEqual(result.status, .exhausted)
    }

    func testCardIsIrrelevantWhenSelectionDoesNotMatchDeclaredTargets() {
        let rules = CardPlayabilityRules(systemTargetTypes: [.stock])
        let card = makeCard(title: "Measure Inventory", rules: rules)
        let result = SystemMapEvaluator.evaluate(card: card, step: makeStep(), selectedTargetKind: .flow, allCards: [card])
        XCTAssertEqual(result.status, .irrelevant)
        XCTAssertFalse(result.relevance)
    }

    func testCardIsRecommendedWhenSelectionMatchesDeclaredTargets() {
        let rules = CardPlayabilityRules(systemTargetTypes: [.stock])
        let card = makeCard(title: "Measure Inventory", rules: rules)
        let result = SystemMapEvaluator.evaluate(card: card, step: makeStep(), selectedTargetKind: .stock, allCards: [card])
        XCTAssertEqual(result.status, .recommended)
        XCTAssertTrue(result.isPlayable)
    }

    func testUntargetedCardIsNeverIrrelevant() {
        // No systemTargetTypes declared — must remain usable everywhere so
        // pre-existing cards authored before this feature keep working.
        let card = makeCard(title: "General Principle")
        let result = SystemMapEvaluator.evaluate(card: card, step: makeStep(), selectedTargetKind: .flow, allCards: [card])
        XCTAssertEqual(result.status, .available)
    }

    func testReciprocalUnlockWorksFromEitherSide() {
        // Card A declares "unlocks: B" — B never declares "unlockedBy: A"
        // itself. The relationship should still gate B until A is played,
        // without requiring the user to author both sides.
        let cardA = makeCard(title: "Measure Demand", rules: CardPlayabilityRules(unlocksCardTitles: ["Adjust Reorder Threshold"]))
        let cardB = makeCard(title: "Adjust Reorder Threshold", rules: CardPlayabilityRules(unlockedByCardTitles: ["Someone Else"]))
        let allCards = [cardA, cardB]

        let before = SystemMapEvaluator.evaluate(card: cardB, step: makeStep(), selectedTargetKind: nil, allCards: allCards)
        XCTAssertEqual(before.status, .locked)

        var stepAfter = makeStep()
        stepAfter.cardPlays = [SystemCardPlay(cardID: cardA.id, targetKind: .system, status: .active, playedAtStepIndex: 0)]
        let after = SystemMapEvaluator.evaluate(card: cardB, step: stepAfter, selectedTargetKind: nil, allCards: allCards)
        XCTAssertEqual(after.status, .available)
        XCTAssertTrue(after.satisfiedRequirements.contains(where: { $0.contains("Measure Demand") }))
    }

    func testManualOverrideWins() {
        let card = makeCard(title: "No Rules")
        var step = makeStep()
        step.manualStatusOverrides[card.id] = .disabled
        let result = SystemMapEvaluator.evaluate(card: card, step: step, selectedTargetKind: nil, allCards: [card])
        XCTAssertEqual(result.status, .disabled)
        XCTAssertTrue(result.isManuallyOverridden)
    }

    func testTargetKindMapping() {
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .stock), .stock)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .goal), .goal)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .constraint), .constraint)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .delay), .delay)
        XCTAssertEqual(SystemMapEvaluator.targetKind(for: .note), .note)
    }
}
