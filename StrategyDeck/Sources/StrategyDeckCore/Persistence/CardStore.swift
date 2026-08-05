import Foundation

/// Manages the in-memory + persisted library: cards, decks, suits, and the
/// relationship graph between cards. All mutations go through this store;
/// UI reads via `@Published` properties. Persistence errors are surfaced
/// through `lastError` so the UI can alert.
@MainActor
public final class CardStore: ObservableObject {
    @Published public private(set) var cards: [KnowledgeCard] = []
    @Published public private(set) var decks: [KnowledgeDeck] = []
    @Published public private(set) var suits: [CardSuit] = []
    @Published public private(set) var relationships: [CardRelationship] = []
    @Published public var lastError: Error?

    private let persistence: PersistenceService
    // Deliberately not "cards.json"/"suites.json" — those names were used by
    // the pre-cutover StrategyCard/StrategySuite model, and a decode of that
    // old shape against KnowledgeCard's required `title` field throws. Using
    // distinct filenames means a machine that ran a pre-cutover build simply
    // has no file here yet and gets reseeded, rather than hitting a decode
    // error against incompatible leftover data.
    private static let cardsFilename = "knowledge-cards.json"
    private static let decksFilename = "decks.json"
    private static let suitsFilename = "suits.json"
    private static let relationshipsFilename = "relationships.json"

    public init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    // MARK: - Boot

    /// Call once on launch. Copies seed data on first run, then loads from disk.
    public func loadOrSeed() {
        let needsSeed = !persistence.fileExists(Self.cardsFilename)
        if needsSeed {
            do {
                let seed = try persistence.loadBundledLibrary()
                cards = seed.cards
                decks = seed.decks
                suits = seed.suits
                relationships = seed.relationships
                save()
            } catch {
                lastError = error
            }
            return
        }
        do {
            cards = try persistence.load([KnowledgeCard].self, from: Self.cardsFilename)
        } catch {
            lastError = error
        }
        // A corrupt/unreadable decks or suits file must not silently empty
        // the tree sidebar (the slice's headline navigation feature) — fall
        // back to the bundled seed's decks/suits rather than `[]`, mirroring
        // how the old StrategyStore fell back to StrategySuite.defaults.
        let seed = try? persistence.loadBundledLibrary()
        decks = (try? persistence.load([KnowledgeDeck].self, from: Self.decksFilename)) ?? seed?.decks ?? []
        suits = (try? persistence.load([CardSuit].self, from: Self.suitsFilename)) ?? seed?.suits ?? []
        relationships = (try? persistence.load([CardRelationship].self, from: Self.relationshipsFilename)) ?? []
    }

    // MARK: - Mutations

    public func add(_ card: KnowledgeCard) {
        cards.append(card)
        save()
    }

    public func update(_ card: KnowledgeCard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.updatedAt = Date()
        cards[idx] = updated
        save()
    }

    public func delete(id: UUID) {
        cards.removeAll { $0.id == id }
        save()
    }

    public func toggleFavorite(id: UUID) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[idx].isFavorite.toggle()
        cards[idx].updatedAt = Date()
        save()
    }

    public func duplicate(_ card: KnowledgeCard) {
        var copy = card
        copy.id = UUID()
        copy.title = card.title + " (copy)"
        copy.isFavorite = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        cards.append(copy)
        save()
    }

    // MARK: - Suit tree lookups

    public func rootSuits(forDeck deckID: String) -> [CardSuit] {
        suits.rootSuits(deckID: deckID)
    }

    public func childSuits(of suitID: String) -> [CardSuit] {
        suits.children(of: suitID)
    }

    // MARK: - Reset

    /// Replaces all cards with the bundled seed, discarding user edits to cards.
    public func resetToSeed() {
        do {
            let seed = try persistence.loadBundledLibrary()
            cards = seed.cards
            save()
        } catch {
            lastError = error
        }
    }

    // MARK: - Import / Export

    public func importLibrary(_ library: KnowledgeLibrary, merging: Bool = false) {
        if merging {
            let existingCardIDs = Set(cards.map(\.id))
            cards.append(contentsOf: library.cards.filter { !existingCardIDs.contains($0.id) })
            let existingSuitIDs = Set(suits.map(\.id))
            suits.append(contentsOf: library.suits.filter { !existingSuitIDs.contains($0.id) })
            let existingDeckIDs = Set(decks.map(\.id))
            decks.append(contentsOf: library.decks.filter { !existingDeckIDs.contains($0.id) })
            let existingRelationshipIDs = Set(relationships.map(\.id))
            relationships.append(contentsOf: library.relationships.filter { !existingRelationshipIDs.contains($0.id) })
        } else {
            cards = library.cards
            if !library.decks.isEmpty { decks = library.decks }
            if !library.suits.isEmpty { suits = library.suits }
            relationships = library.relationships
        }
        save()
    }

    public func exportLibrary(sequences: [StrategySequence]) -> KnowledgeLibrary {
        KnowledgeLibrary(decks: decks, suits: suits, cards: cards, relationships: relationships, sequences: sequences)
    }

    // MARK: - Private

    /// Persists every collection this store owns. `cards` mutates far more
    /// often than `decks`/`suits`/`relationships`, but writing all four
    /// together is what keeps `importLibrary` (which can change any of
    /// them) from silently losing whatever it just changed — a partial
    /// save() here was exactly the bug this store shipped with initially.
    private func save() {
        do {
            try persistence.save(cards, to: Self.cardsFilename)
            try persistence.save(decks, to: Self.decksFilename)
            try persistence.save(suits, to: Self.suitsFilename)
            try persistence.save(relationships, to: Self.relationshipsFilename)
        } catch {
            lastError = error
        }
    }
}
