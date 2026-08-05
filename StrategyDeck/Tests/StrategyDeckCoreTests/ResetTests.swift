import XCTest
@testable import StrategyDeckCore

@MainActor
final class ResetTests: XCTestCase {

    func testResetRestoresDefaultCards() {
        let mem = InMemoryPersistence()
        let store = CardStore(persistence: mem)
        store.loadOrSeed()

        let seedCount = store.cards.count

        store.add(KnowledgeCard(deckIDs: ["software-engineering"], suitIDs: ["debugging"], kind: .action, title: "My Custom Card"))
        XCTAssertEqual(store.cards.count, seedCount + 1)

        store.resetToSeed()
        XCTAssertEqual(store.cards.count, seedCount)
        XCTAssertFalse(store.cards.contains { $0.title == "My Custom Card" })
    }

    func testResetDoesNotAffectSequences() {
        let mem = InMemoryPersistence()
        let cardStore = CardStore(persistence: mem)
        let sequenceStore = SequenceStore(persistence: mem)
        cardStore.loadOrSeed()
        sequenceStore.load()

        let cardID = cardStore.cards.first!.id
        sequenceStore.addToTray(cardID: cardID)
        sequenceStore.saveSequence(name: "Keep Me", description: "")

        cardStore.resetToSeed()

        XCTAssertEqual(sequenceStore.savedSequences.count, 1)
        XCTAssertEqual(sequenceStore.savedSequences.first?.name, "Keep Me")
    }

    func testFirstLaunchSeedsFromProvider() {
        let mem = InMemoryPersistence()
        XCTAssertFalse(mem.fileExists("knowledge-cards.json"))

        let store = CardStore(persistence: mem)
        store.loadOrSeed()

        XCTAssertFalse(store.cards.isEmpty, "Should have seeded cards on first launch")
        XCTAssertTrue(mem.fileExists("knowledge-cards.json"), "Should have persisted seeded cards")
    }

    func testImportedDecksSuitsAndRelationshipsSurviveARelaunch() {
        // Regression test: CardStore.save() originally persisted only
        // cards.json, so importLibrary's changes to decks/suits/relationships
        // were silently lost the next time loadOrSeed() ran (e.g. on relaunch).
        let mem = InMemoryPersistence()
        let store = CardStore(persistence: mem)
        store.loadOrSeed()

        let wholeSecond = Date.wholeSecondForTesting()
        let importedDeck = KnowledgeDeck(id: "japanese", name: "Japanese")
        let importedSuit = CardSuit(id: "particles", deckID: "japanese", name: "Particles")
        let importedCard = KnowledgeCard(
            deckIDs: ["japanese"], suitIDs: ["particles"], kind: .relation, title: "は",
            createdAt: wholeSecond, updatedAt: wholeSecond
        )
        let importedRelationship = CardRelationship(sourceCardID: UUID(), targetCardID: UUID(), type: .enables)

        store.importLibrary(
            KnowledgeLibrary(
                decks: [importedDeck],
                suits: [importedSuit],
                cards: [importedCard],
                relationships: [importedRelationship]
            ),
            merging: true
        )

        // Simulate a relaunch: a fresh store reading the same persisted files.
        let relaunched = CardStore(persistence: mem)
        relaunched.loadOrSeed()

        XCTAssertTrue(relaunched.decks.contains(importedDeck))
        XCTAssertTrue(relaunched.suits.contains(importedSuit))
        XCTAssertTrue(relaunched.cards.contains(importedCard))
        XCTAssertTrue(relaunched.relationships.contains(importedRelationship))
    }
}
