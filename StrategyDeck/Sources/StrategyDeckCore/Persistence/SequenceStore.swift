import Foundation

/// Manages saved sequences and the current (unsaved) working tray.
@MainActor
public final class SequenceStore: ObservableObject {
    /// The current unsaved tray — items the user has placed during this session.
    @Published public var trayItems: [StrategySequenceItem] = []
    /// All saved, named sequences.
    @Published public private(set) var savedSequences: [StrategySequence] = []
    @Published public var lastError: Error?

    private let persistence: PersistenceService
    private static let filename = "sequences.json"

    public init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    // MARK: - Boot

    public func load() {
        guard persistence.fileExists(Self.filename) else { return }
        do {
            savedSequences = try persistence.load([StrategySequence].self, from: Self.filename)
        } catch {
            lastError = error
        }
    }

    // MARK: - Tray

    public func addToTray(cardID: UUID) {
        let order = (trayItems.map(\.order).max() ?? -1) + 1
        trayItems.append(StrategySequenceItem(cardID: cardID, order: order))
    }

    public func removeFromTray(id: UUID) {
        trayItems.removeAll { $0.id == id }
        renormalizeOrder()
    }

    public func moveTrayItem(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let item = trayItems.remove(at: sourceIndex)
        let adjusted = destination > sourceIndex ? destination - 1 : destination
        trayItems.insert(item, at: min(adjusted, trayItems.count))
        renormalizeOrder()
    }

    public func updateNote(for itemID: UUID, note: String) {
        guard let idx = trayItems.firstIndex(where: { $0.id == itemID }) else { return }
        trayItems[idx].note = note
    }

    public func clearTray() {
        trayItems = []
    }

    private func renormalizeOrder() {
        for idx in trayItems.indices {
            trayItems[idx].order = idx
        }
    }

    // MARK: - Saved Sequences

    public func saveSequence(name: String, description: String, scenario: String = "") {
        let sorted = trayItems.sorted { $0.order < $1.order }
        let sequence = StrategySequence(name: name, description: description, scenario: scenario, orderedItems: sorted)
        savedSequences.append(sequence)
        persist()
    }

    public func openSequence(_ sequence: StrategySequence) {
        trayItems = sequence.normalizedItems
    }

    public func deleteSequence(id: UUID) {
        savedSequences.removeAll { $0.id == id }
        persist()
    }

    public func updateSequence(_ sequence: StrategySequence) {
        guard let idx = savedSequences.firstIndex(where: { $0.id == sequence.id }) else { return }
        var updated = sequence
        updated.updatedAt = Date()
        savedSequences[idx] = updated
        persist()
    }

    public func importSequences(_ sequences: [StrategySequence], merging: Bool = false) {
        if merging {
            let existingIDs = Set(savedSequences.map(\.id))
            savedSequences.append(contentsOf: sequences.filter { !existingIDs.contains($0.id) })
        } else {
            savedSequences = sequences
        }
        persist()
    }

    // MARK: - Private

    private func persist() {
        do {
            try persistence.save(savedSequences, to: Self.filename)
        } catch {
            lastError = error
        }
    }
}
