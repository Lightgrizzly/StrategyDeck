import Foundation
import StrategyDeckCore

/// Shared application state injected throughout the view hierarchy.
///
/// Owns the two stores and the service objects. Created once in AppDelegate.
@MainActor
final class AppEnvironment: ObservableObject {
    let cardStore: CardStore
    let sequenceStore: SequenceStore
    let importExport: ImportExportService

    init() {
        let persistence = JSONPersistenceService()
        cardStore = CardStore(persistence: persistence)
        sequenceStore = SequenceStore(persistence: persistence)
        importExport = ImportExportService()
    }

    func boot() {
        cardStore.loadOrSeed()
        sequenceStore.load()
    }
}
