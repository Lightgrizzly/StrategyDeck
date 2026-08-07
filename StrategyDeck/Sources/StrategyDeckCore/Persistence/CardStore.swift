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

    @discardableResult
    public func duplicate(_ card: KnowledgeCard, titleSuffix: String = " (copy)") -> KnowledgeCard {
        var copy = card
        copy.id = UUID()
        copy.title = card.title + titleSuffix
        copy.isFavorite = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        cards.append(copy)
        save()
        return copy
    }

    /// Duplicates a card into a specific deck rather than wherever the
    /// original lives — any suit membership that doesn't belong to the
    /// destination deck is dropped, since a suit only ever belongs to one
    /// deck.
    @discardableResult
    public func duplicateCard(_ card: KnowledgeCard, intoDeckID deckID: String) -> KnowledgeCard {
        var copy = card
        copy.id = UUID()
        copy.title = card.title + " (copy)"
        copy.deckIDs = [deckID]
        let deckSuitIDs = Set(suits.filter { $0.deckID == deckID }.map(\.id))
        copy.suitIDs = card.suitIDs.filter { deckSuitIDs.contains($0) }
        copy.isFavorite = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        cards.append(copy)
        save()
        return copy
    }

    /// Duplicates a card into a specific suit, adding that suit's deck to
    /// the copy's `deckIDs` if it isn't already there.
    @discardableResult
    public func duplicateCard(_ card: KnowledgeCard, intoSuitID suitID: String) -> KnowledgeCard {
        var copy = card
        copy.id = UUID()
        copy.title = card.title + " (copy)"
        copy.suitIDs = [suitID]
        if let deckID = suits.first(where: { $0.id == suitID })?.deckID, !copy.deckIDs.contains(deckID) {
            copy.deckIDs.append(deckID)
        }
        copy.isFavorite = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        cards.append(copy)
        save()
        return copy
    }

    // MARK: - Quick Create / Bulk Create

    /// Creates a fully valid, saved card from just a title — the same
    /// underlying model a card built through the full editor would produce,
    /// just reached in one step. Deck/suite membership is optional.
    @discardableResult
    public func quickCreateCard(title: String, deckID: String?, suitID: String?, shortDescription: String = "") -> KnowledgeCard {
        let card = KnowledgeCard(
            deckIDs: deckID.map { [$0] } ?? [],
            suitIDs: suitID.map { [$0] } ?? [],
            kind: .action,
            metadata: .softwareStrategy(SoftwareStrategyFields()),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            frontText: shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        cards.append(card)
        save()
        return card
    }

    /// Creates one card per entry in the same deck. Duplicate detection and
    /// row-level editing happen in the bulk-add UI before this is called —
    /// this always creates exactly what it's given.
    @discardableResult
    public func bulkCreateCards(_ entries: [(title: String, suitID: String?)], deckID: String?) -> [KnowledgeCard] {
        guard !entries.isEmpty else { return [] }
        let created = entries.map { entry in
            KnowledgeCard(
                deckIDs: deckID.map { [$0] } ?? [],
                suitIDs: entry.suitID.map { [$0] } ?? [],
                kind: .action,
                metadata: .softwareStrategy(SoftwareStrategyFields()),
                title: entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        cards.append(contentsOf: created)
        save()
        return created
    }

    // MARK: - Suit tree lookups

    public func rootSuits(forDeck deckID: String) -> [CardSuit] {
        suits.rootSuits(deckID: deckID)
    }

    public func childSuits(of suitID: String) -> [CardSuit] {
        suits.children(of: suitID)
    }

    // MARK: - Deck Management

    /// Creates a new deck and adds it to the library.
    /// - Parameters:
    ///   - name: The name of the new deck
    ///   - description: Optional description for the deck
    ///   - iconName: SF Symbol name for the deck icon (default: "square.stack.3d.up")
    /// - Returns: The newly created deck
    @discardableResult
    public func createDeck(
        name: String,
        description: String = "",
        iconName: String = "square.stack.3d.up"
    ) -> KnowledgeDeck {
        let id = UUID().uuidString
        let displayOrder = (decks.max(by: { $0.displayOrder < $1.displayOrder })?.displayOrder ?? -1) + 1
        let newDeck = KnowledgeDeck(
            id: id,
            name: name,
            description: description,
            iconName: iconName,
            displayOrder: displayOrder
        )
        decks.append(newDeck)
        save()
        return newDeck
    }

    /// Renames a deck in place.
    public func renameDeck(id deckID: String, name: String) {
        guard let idx = decks.firstIndex(where: { $0.id == deckID }) else { return }
        decks[idx].name = name
        save()
    }

    /// Duplicates a deck's structure (the deck row and its suit tree) as a
    /// new, empty deck — card membership is intentionally not copied, since
    /// a card can belong to multiple decks and silently multiplying that
    /// association would be surprising.
    /// - Returns: The newly created deck.
    @discardableResult
    public func duplicateDeck(id deckID: String) -> KnowledgeDeck? {
        guard let original = decks.first(where: { $0.id == deckID }) else { return nil }
        let newDeck = createDeck(name: original.name + " Copy", description: original.description, iconName: original.iconName)

        // Recreate the suit tree, preserving parent/child structure by
        // walking parents before children (suits are stored flat with a
        // `parentSuitID`, so a suit can only be recreated once its parent's
        // new ID is known).
        var oldToNewSuitID: [String: String] = [:]
        let originalSuits = suits.filter { $0.deckID == deckID }
        var remaining = originalSuits
        while !remaining.isEmpty {
            let ready = remaining.filter { $0.parentSuitID == nil || oldToNewSuitID[$0.parentSuitID!] != nil }
            guard !ready.isEmpty else { break } // malformed/cyclic parent chain — stop rather than loop forever
            for suit in ready {
                let newParentID = suit.parentSuitID.flatMap { oldToNewSuitID[$0] }
                let newSuit = createSuit(deckID: newDeck.id, name: suit.name, parentSuitID: newParentID, description: suit.description, iconName: suit.iconName)
                oldToNewSuitID[suit.id] = newSuit.id
            }
            remaining.removeAll { suit in ready.contains(where: { $0.id == suit.id }) }
        }
        return newDeck
    }

    /// Adds a card to a deck (a no-op if it's already a member). Deck
    /// membership is a reference — this never touches the reusable card
    /// definition itself beyond its `deckIDs` association.
    public func addCardToDeck(cardID: UUID, deckID: String) {
        guard let idx = cards.firstIndex(where: { $0.id == cardID }), !cards[idx].deckIDs.contains(deckID) else { return }
        cards[idx].deckIDs.append(deckID)
        cards[idx].updatedAt = Date()
        save()
    }

    /// Removes a card from a deck without deleting the card itself.
    public func removeCardFromDeck(cardID: UUID, deckID: String) {
        guard let idx = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cards[idx].deckIDs.removeAll { $0 == deckID }
        cards[idx].updatedAt = Date()
        save()
    }

    /// Deletes a deck and all its associated suits and cards.
    /// - Parameter deckID: The ID of the deck to delete
    public func deleteDeck(id deckID: String) {
        decks.removeAll { $0.id == deckID }
        let suitIDsInDeck = suits.filter { $0.deckID == deckID }.map { $0.id }
        suits.removeAll { $0.deckID == deckID }
        
        // Remove cards that only exist in this deck's suits
        let cardsInDeckSuits = cards.filter { card in
            card.suitIDs.contains { suitID in suitIDsInDeck.contains(suitID) }
        }
        for card in cardsInDeckSuits {
            let remainingSuitIDs = card.suitIDs.filter { !suitIDsInDeck.contains($0) }
            if remainingSuitIDs.isEmpty {
                cards.removeAll { $0.id == card.id }
            } else {
                if let idx = cards.firstIndex(where: { $0.id == card.id }) {
                    cards[idx].suitIDs = remainingSuitIDs
                }
            }
        }
        save()
    }

    // MARK: - Suit (Category) Management

    /// Creates a new suit (category) within a deck or as a subcategory.
    /// - Parameters:
    ///   - deckID: The ID of the deck this suit belongs to
    ///   - name: The name of the new suit
    ///   - parentSuitID: Optional ID of the parent suit for nested categories
    ///   - description: Optional description for the suit
    ///   - iconName: SF Symbol name for the suit icon (default: "square.stack.3d.up")
    /// - Returns: The newly created suit
    @discardableResult
    public func createSuit(
        deckID: String,
        name: String,
        parentSuitID: String? = nil,
        description: String = "",
        iconName: String = "square.stack.3d.up"
    ) -> CardSuit {
        let id = UUID().uuidString
        let displayOrder = (suits.filter { parentSuitID == nil ? $0.deckID == deckID && $0.parentSuitID == nil : $0.parentSuitID == parentSuitID }
            .max(by: { $0.displayOrder < $1.displayOrder })?.displayOrder ?? -1) + 1
        let newSuit = CardSuit(
            id: id,
            deckID: deckID,
            parentSuitID: parentSuitID,
            name: name,
            description: description,
            iconName: iconName,
            displayOrder: displayOrder
        )
        suits.append(newSuit)
        save()
        return newSuit
    }

    /// Deletes a suit and optionally its child suits.
    /// - Parameters:
    ///   - suitID: The ID of the suit to delete
    ///   - deleteChildren: Whether to also delete all child suits (default: true)
    public func deleteSuit(id suitID: String, deleteChildren: Bool = true) {
        guard let suit = suits.first(where: { $0.id == suitID }) else { return }
        
        var suitIDsToDelete = Set([suitID])
        
        if deleteChildren {
            // Recursively find all child suits
            func collectChildren(of parentID: String) {
                for childSuit in suits.filter({ $0.parentSuitID == parentID }) {
                    suitIDsToDelete.insert(childSuit.id)
                    collectChildren(of: childSuit.id)
                }
            }
            collectChildren(of: suitID)
        }
        
        // Remove the suits
        suits.removeAll { suitIDsToDelete.contains($0.id) }
        
        // Update cards: remove the deleted suit IDs from their suitIDs array
        for i in 0..<cards.count {
            cards[i].suitIDs.removeAll { suitIDsToDelete.contains($0) }
        }
        
        save()
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
        reconcileMissingDeckAndSuitReferences()
        save()
    }

    /// Imported cards can reference deck/suit IDs that the import payload
    /// never defines (e.g. a card-only `{"cards": [...]}` file pointing at
    /// a brand-new deck) — without this, those cards would silently import
    /// but be unreachable from any deck/suit filter in the UI. Synthesizes
    /// a minimal stub deck/suit per unresolved ID instead, named from the
    /// ID itself, so every imported card lands somewhere visible.
    private func reconcileMissingDeckAndSuitReferences() {
        var knownDeckIDs = Set(decks.map(\.id))

        func displayName(fromID id: String) -> String {
            id.replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }

        // A suit whose deckID is blank or doesn't resolve (e.g. an import
        // file that omitted deckID entirely) is attributed to a deck
        // inferred from a card that uses it, or the import's only deck if
        // there's just one — rather than being left permanently orphaned.
        for i in suits.indices where !knownDeckIDs.contains(suits[i].deckID) {
            if let inferredDeckID = cards.first(where: { $0.suitIDs.contains(suits[i].id) })?.deckIDs.first {
                suits[i].deckID = inferredDeckID
            } else if decks.count == 1 {
                suits[i].deckID = decks[0].id
            }
        }

        knownDeckIDs = Set(decks.map(\.id))
        var knownSuitIDs = Set(suits.map(\.id))

        for card in cards {
            for deckID in card.deckIDs where !knownDeckIDs.contains(deckID) {
                knownDeckIDs.insert(deckID)
                decks.append(KnowledgeDeck(id: deckID, name: displayName(fromID: deckID)))
            }
        }

        for card in cards {
            for suitID in card.suitIDs where !knownSuitIDs.contains(suitID) {
                knownSuitIDs.insert(suitID)
                let ownerDeckID = card.deckIDs.first ?? "imported"
                if !knownDeckIDs.contains(ownerDeckID) {
                    knownDeckIDs.insert(ownerDeckID)
                    decks.append(KnowledgeDeck(id: ownerDeckID, name: displayName(fromID: ownerDeckID)))
                }
                suits.append(CardSuit(id: suitID, deckID: ownerDeckID, name: displayName(fromID: suitID)))
            }
        }
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
