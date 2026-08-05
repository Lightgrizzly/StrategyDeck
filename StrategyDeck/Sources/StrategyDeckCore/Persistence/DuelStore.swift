import Foundation

@MainActor
public final class DuelStore: ObservableObject {
    @Published public private(set) var duels: [Duel] = []
    @Published public var currentDuel: Duel?
    @Published public var lastError: Error?

    public var currentPanel: DuelPanel? {
        currentDuel?.currentPanel
    }

    private let persistence: PersistenceService
    private static let filename = "duels.json"

    public init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    public func load() {
        guard persistence.fileExists(Self.filename) else { return }
        do {
            duels = try persistence.load([Duel].self, from: Self.filename)
        } catch {
            lastError = error
        }
    }

    public func createDuel(name: String, description: String = "") {
        var duel = Duel(name: name, description: description)
        let firstPanel = DuelPanel(order: 0, title: "Step 1")
        duel.panels = [firstPanel]
        duel.currentPanelID = firstPanel.id
        duel.updatedAt = Date()
        duels.insert(duel, at: 0)
        currentDuel = duel
        persist()
    }

    public func openDuel(id: UUID) {
        guard let duel = duels.first(where: { $0.id == id }) else { return }
        currentDuel = duel
    }

    public func closeCurrentDuel() {
        currentDuel = nil
    }

    public func deleteDuel(id: UUID) {
        duels.removeAll { $0.id == id }
        if currentDuel?.id == id { currentDuel = nil }
        persist()
    }

    public func updateCurrentDuel(_ update: (inout Duel) -> Void) {
        guard var duel = currentDuel else { return }
        update(&duel)
        duel.updatedAt = Date()
        currentDuel = duel
        if let idx = duels.firstIndex(where: { $0.id == duel.id }) {
            duels[idx] = duel
        } else {
            duels.insert(duel, at: 0)
        }
        persist()
    }

    public func setCurrentPanel(id: UUID) {
        updateCurrentDuel { duel in
            duel.currentPanelID = id
        }
    }

    public func addStep(after panelID: UUID?) {
        guard var duel = currentDuel else { return }
        let panels = duel.sortedPanels
        let currentIndex = panels.firstIndex(where: { $0.id == panelID }) ?? (panels.count - 1)
        let baseIndex = max(0, currentIndex)
        let basePanel = panels[baseIndex]
        let insertIndex = baseIndex + 1
        let newPanel = basePanel.duplicated(order: insertIndex)
        var newPanels = panels
        for idx in insertIndex..<newPanels.count {
            newPanels[idx].order += 1
        }
        newPanels.insert(newPanel, at: insertIndex)
        updateCurrentDuel { duel in
            duel.panels = newPanels
            duel.currentPanelID = newPanel.id
        }
    }

    public func duplicatePanel(id: UUID) {
        guard let duel = currentDuel else { return }
        guard let index = duel.sortedPanels.firstIndex(where: { $0.id == id }) else { return }
        let duplicate = duel.sortedPanels[index].duplicated(order: index + 1)
        var newPanels = duel.sortedPanels
        for idx in index + 1..<newPanels.count {
            newPanels[idx].order += 1
        }
        newPanels.insert(duplicate, at: index + 1)
        updateCurrentDuel { duel in
            duel.panels = newPanels
            duel.currentPanelID = duplicate.id
        }
    }

    public func deletePanel(id: UUID) {
        guard var duel = currentDuel else { return }
        guard duel.panels.count > 1 else { return }
        var panels = duel.sortedPanels
        panels.removeAll { $0.id == id }
        for idx in panels.indices {
            panels[idx].order = idx
        }
        let selected = panels.first?.id
        updateCurrentDuel { duel in
            duel.panels = panels
            duel.currentPanelID = selected
        }
    }

    public func movePanel(from source: Int, to destination: Int) {
        guard var duel = currentDuel else { return }
        var panels = duel.sortedPanels
        let item = panels.remove(at: source)
        let adjusted = destination > source ? destination - 1 : destination
        panels.insert(item, at: min(adjusted, panels.count))
        for idx in panels.indices { panels[idx].order = idx }
        updateCurrentDuel { duel in
            duel.panels = panels
        }
    }

    public func updatePanel(_ panel: DuelPanel) {
        updateCurrentDuel { duel in
            if let idx = duel.panels.firstIndex(where: { $0.id == panel.id }) {
                var updated = panel
                updated.updatedAt = Date()
                duel.panels[idx] = updated
            }
        }
    }

    public func addSnapshot(to panelID: UUID, cardID: UUID, zone: DuelZone) {
        updateCurrentDuel { duel in
            guard let idx = duel.panels.firstIndex(where: { $0.id == panelID }) else { return }
            let panel = duel.panels[idx]
            let order = (panel.snapshots.filter { $0.zone == zone }.map(\.order).max() ?? -1) + 1
            var updatedPanel = panel
            updatedPanel.snapshots.append(DuelCardSnapshot(cardID: cardID, zone: zone, status: .available, isNew: true, order: order))
            updatedPanel.updatedAt = Date()
            duel.panels[idx] = updatedPanel
        }
    }

    public func updateSnapshot(_ snapshot: DuelCardSnapshot, in panelID: UUID) {
        updateCurrentDuel { duel in
            guard let panelIndex = duel.panels.firstIndex(where: { $0.id == panelID }) else { return }
            var panel = duel.panels[panelIndex]
            if let snapshotIndex = panel.snapshots.firstIndex(where: { $0.id == snapshot.id }) {
                panel.snapshots[snapshotIndex] = snapshot
                panel.updatedAt = Date()
                duel.panels[panelIndex] = panel
            }
        }
    }

    public func deleteSnapshot(id: UUID, in panelID: UUID) {
        updateCurrentDuel { duel in
            guard let panelIndex = duel.panels.firstIndex(where: { $0.id == panelID }) else { return }
            var panel = duel.panels[panelIndex]
            panel.snapshots.removeAll { $0.id == id }
            panel.updatedAt = Date()
            duel.panels[panelIndex] = panel
        }
    }

    private func persist() {
        do {
            try persistence.save(duels, to: Self.filename)
        } catch {
            lastError = error
        }
    }
}
