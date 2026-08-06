import XCTest
@testable import StrategyDeckCore

@MainActor
final class CardStoreDeckTests: XCTestCase {

    private func makeStore() -> CardStore {
        let store = CardStore(persistence: InMemoryPersistence())
        store.loadOrSeed()
        return store
    }

    func testRenameDeck() {
        let store = makeStore()
        let deck = store.createDeck(name: "Original Name")
        store.renameDeck(id: deck.id, name: "New Name")
        XCTAssertEqual(store.decks.first(where: { $0.id == deck.id })?.name, "New Name")
    }

    func testDuplicateDeckCopiesSuitTreeButNotCards() {
        let store = makeStore()
        let deck = store.createDeck(name: "Original")
        let parent = store.createSuit(deckID: deck.id, name: "Parent")
        _ = store.createSuit(deckID: deck.id, name: "Child", parentSuitID: parent.id)

        let card = KnowledgeCard(deckIDs: [deck.id], suitIDs: [parent.id], kind: .action, title: "Card")
        store.add(card)

        guard let copy = store.duplicateDeck(id: deck.id) else { return XCTFail("expected a duplicate deck") }
        XCTAssertNotEqual(copy.id, deck.id)
        XCTAssertEqual(copy.name, "Original Copy")

        let copiedSuits = store.suits.filter { $0.deckID == copy.id }
        XCTAssertEqual(copiedSuits.count, 2, "parent + child suit structure should be duplicated")
        let copiedParent = copiedSuits.first(where: { $0.parentSuitID == nil })
        let copiedChild = copiedSuits.first(where: { $0.parentSuitID != nil })
        XCTAssertNotNil(copiedParent)
        XCTAssertEqual(copiedChild?.parentSuitID, copiedParent?.id, "child's parent reference should point at the new parent's new ID")

        // Card membership must NOT be copied — duplicating a deck's
        // structure should never silently multiply an existing card's
        // deck/suit associations.
        let reloadedCard = store.cards.first(where: { $0.id == card.id })
        XCTAssertEqual(reloadedCard?.deckIDs, [deck.id])
    }

    func testAddAndRemoveCardFromDeck() {
        let store = makeStore()
        let deckA = store.createDeck(name: "A")
        let deckB = store.createDeck(name: "B")
        let card = KnowledgeCard(deckIDs: [deckA.id], suitIDs: [], kind: .action, title: "Card")
        store.add(card)

        store.addCardToDeck(cardID: card.id, deckID: deckB.id)
        var reloaded = store.cards.first(where: { $0.id == card.id })
        XCTAssertEqual(Set(reloaded?.deckIDs ?? []), Set([deckA.id, deckB.id]), "a card may belong to multiple decks")

        // Adding again is a no-op, not a duplicate entry.
        store.addCardToDeck(cardID: card.id, deckID: deckB.id)
        reloaded = store.cards.first(where: { $0.id == card.id })
        XCTAssertEqual(reloaded?.deckIDs.filter { $0 == deckB.id }.count, 1)

        store.removeCardFromDeck(cardID: card.id, deckID: deckA.id)
        reloaded = store.cards.first(where: { $0.id == card.id })
        XCTAssertEqual(reloaded?.deckIDs, [deckB.id], "removing from a deck must not delete the card or its other deck membership")
    }
}
