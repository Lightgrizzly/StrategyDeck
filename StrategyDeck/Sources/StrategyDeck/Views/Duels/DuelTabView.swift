import SwiftUI
import AppKit
import StrategyDeckCore

struct DuelTabView: View {
    @EnvironmentObject var duelStore: DuelStore
    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var sequenceStore: SequenceStore

    @State private var showingNewDuel = false
    @State private var newDuelName = ""
    @State private var newDuelDescription = ""
    @State private var alertState: AlertState?

    var body: some View {
        Group {
            if let _ = duelStore.currentDuel {
                DuelEditorView()
            } else {
                DuelEmptyStateView(
                    duels: duelStore.duels,
                    onCreate: { showingNewDuel = true },
                    onOpen: { duelStore.openDuel(id: $0) },
                    onDelete: { id in
                        alertState = .destructive(
                            title: "Delete this duel?",
                            message: "This will remove the saved duel permanently.",
                            confirmLabel: "Delete"
                        ) { duelStore.deleteDuel(id: id) }
                    }
                )
            }
        }
        .background(Color(.windowBackgroundColor))
        .alertState($alertState)
        .sheet(isPresented: $showingNewDuel) {
            NewDuelSheet(
                name: $newDuelName,
                description: $newDuelDescription,
                isPresented: $showingNewDuel,
                onCreate: {
                    guard !newDuelName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    duelStore.createDuel(name: newDuelName, description: newDuelDescription)
                    newDuelName = ""
                    newDuelDescription = ""
                }
            )
            .frame(minWidth: 420, minHeight: 240)
        }
    }
}

private struct DuelEmptyStateView: View {
    let duels: [Duel]
    let onCreate: () -> Void
    let onOpen: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duel Comic")
                        .font(.system(size: 18, weight: .bold))
                    Text("Build a turn-based strategic sequence using your existing cards. Create opponent moves, player responses, and shared battlefield state as comic-style panels.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                Button(action: onCreate) {
                    Label("Create Duel", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)

                Group {
                    Text("Saved Duels")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .padding(.horizontal, 18)

                    if duels.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No duels yet.")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Create your first duel and map out your strategy in scenes and steps.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)))
                        .padding(.horizontal, 18)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(duels.sorted { $0.updatedAt > $1.updatedAt }) { duel in
                                DuelSummaryRow(duel: duel, onOpen: onOpen, onDelete: onDelete)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
                Spacer()
            }
            .padding(.bottom, 24)
        }
    }
}

private struct DuelSummaryRow: View {
    let duel: Duel
    let onOpen: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(duel.name)
                    .font(.system(size: 13, weight: .semibold))
                if !duel.description.isEmpty {
                    Text(duel.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text("Panels: \(duel.sortedPanels.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Updated: \(duel.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: { onOpen(duel.id) }) {
                Text("Open")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor))
            }
            .buttonStyle(.plain)
            Button(role: .destructive, action: { onDelete(duel.id) }) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor)))
    }
}

private struct NewDuelSheet: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a New Duel")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text("Duel Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Unexpected Requirements vs Clarify", text: $name)
                    .textFieldStyle(.roundedBorder)

                Text("Goal or description")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Solve the integration problem", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    onCreate()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}

private struct DuelEditorView: View {
    @EnvironmentObject var duelStore: DuelStore
    @EnvironmentObject var cardStore: CardStore

    @State private var showingCardPicker = false
    @State private var pickerZone: DuelZone = .player
    @State private var selectedCardForPreview: KnowledgeCard?
    @State private var selectedSuiteForPreview: CardSuit?
    @State private var alertState: AlertState?

    private var duel: Duel? { duelStore.currentDuel }
    private var panel: DuelPanel? { duelStore.currentPanel }

    var body: some View {
        if let duel, let panel {
            VStack(spacing: 0) {
                DuelHeader(duel: duel, onSave: updateDuel, onExport: exportCurrentDuel)

                Divider()

                HStack(spacing: 0) {
                    DuelPanelBrowser(
                        duel: duel,
                        selectedPanelID: panel.id,
                        onSelect: duelStore.setCurrentPanel,
                        onDuplicate: duelStore.duplicatePanel,
                        onDelete: { id in
                            alertState = .destructive(title: "Delete this panel?", message: "The panel will be removed from the duel.", confirmLabel: "Delete") {
                                duelStore.deletePanel(id: id)
                            }
                        },
                        onInsertAfter: duelStore.addStep,
                        onMoveUp: { id in
                            guard let current = duel.sortedPanels.firstIndex(where: { $0.id == id }) else { return }
                            duelStore.movePanel(from: current, to: current - 1)
                        },
                        onMoveDown: { id in
                            guard let current = duel.sortedPanels.firstIndex(where: { $0.id == id }) else { return }
                            duelStore.movePanel(from: current, to: current + 1)
                        }
                    )
                    .frame(width: 240)
                    Divider()
                    DuelPanelEditorView(
                        panel: panel,
                        allCards: cardStore.cards,
                        allSuits: cardStore.suits,
                        onUpdate: { duelStore.updatePanel($0) },
                        onAddSnapshot: { duelStore.addSnapshot(to: panel.id, cardID: $0, zone: $1) },
                        onDeleteSnapshot: { duelStore.deleteSnapshot(id: $0, in: panel.id) },
                        onUpdateSnapshot: { duelStore.updateSnapshot($0, in: panel.id) },
                        onShowPicker: { zone in
                            pickerZone = zone
                            showingCardPicker = true
                        }
                    )
                }
            }
            .sheet(isPresented: $showingCardPicker) {
                DuelCardPickerView(
                    zone: pickerZone,
                    recentCardIDs: panel.snapshots.map { $0.cardID },
                    onAdd: { cardID in
                        duelStore.addSnapshot(to: panel.id, cardID: cardID, zone: pickerZone)
                        showingCardPicker = false
                    },
                    onDismiss: { showingCardPicker = false }
                )
                .frame(minWidth: 760, minHeight: 540)
            }
            .sheet(item: $selectedCardForPreview) { card in
                KnowledgeCardDetailView(
                    card: card,
                    suite: selectedSuiteForPreview,
                    allCards: cardStore.cards,
                    relationships: cardStore.relationships,
                    onEdit: {},
                    onAddToTray: {},
                    onDismiss: { selectedCardForPreview = nil }
                )
                .frame(minWidth: 420, minHeight: 520)
            }
            .alertState($alertState)
        } else {
            Text("No duel selected.")
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private func updateDuel(_ updated: Duel) {
        duelStore.updateCurrentDuel { duel in
            duel.name = updated.name
            duel.description = updated.description
            duel.updatedAt = Date()
        }
    }

    private func exportCurrentDuel() {
        guard let duel = duelStore.currentDuel else { return }
        let exportView = DuelExportView(duel: duel, allCards: cardStore.cards, allSuits: cardStore.suits)
        let width: CGFloat = 760
        let height: CGFloat = max(900, CGFloat(duel.sortedPanels.count) * 260)
        let hostingView = NSHostingView(rootView: exportView.frame(width: width, height: height))
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let pdfData = hostingView.dataWithPDF(inside: hostingView.bounds)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(duel.name)-duel.pdf"
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try pdfData.write(to: url, options: [.atomic])
            } catch {
                alertState = .error(error)
            }
        }
    }
}

private struct DuelHeader: View {
    @State var duel: Duel
    let onSave: (Duel) -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Duel name", text: $duel.name)
                    .font(.system(size: 18, weight: .bold))
                    .textFieldStyle(.plain)
                TextField("Describe the goal or situation", text: $duel.description)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onExport) {
                Text("Export PDF")
            }
            .buttonStyle(.bordered)
            Button(action: { onSave(duel) }) {
                Text("Save Duel")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
    }
}

private struct DuelExportView: View {
    let duel: Duel
    let allCards: [KnowledgeCard]
    let allSuits: [CardSuit]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(duel.name)
                    .font(.system(size: 28, weight: .bold))
                if !duel.description.isEmpty {
                    Text(duel.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Divider()
            }
            ForEach(duel.sortedPanels) { panel in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Step \(panel.order + 1): \(panel.title)")
                        .font(.system(size: 18, weight: .semibold))
                    if !panel.narration.isEmpty {
                        Text(panel.narration)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        DuelExportZoneView(title: "Opponent", snapshots: panel.snapshots.filter { $0.zone == .opponent }, allCards: allCards, allSuits: allSuits)
                        DuelExportZoneView(title: "Battlefield", snapshots: panel.snapshots.filter { $0.zone == .battlefield }, allCards: allCards, allSuits: allSuits)
                        DuelExportZoneView(title: "Player", snapshots: panel.snapshots.filter { $0.zone == .player }, allCards: allCards, allSuits: allSuits)
                    }
                    if !panel.outcome.isEmpty {
                        Text("Outcome: \(panel.outcome)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.windowBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separatorColor)))
            }
        }
        .padding(24)
        .frame(maxWidth: 760)
    }
}

private struct DuelExportZoneView: View {
    let title: String
    let snapshots: [DuelCardSnapshot]
    let allCards: [KnowledgeCard]
    let allSuits: [CardSuit]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            ForEach(snapshots) { snapshot in
                if let card = allCards.first(where: { $0.id == snapshot.cardID }) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(card.title)
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(snapshot.status.title)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if !snapshot.annotation.isEmpty {
                        Text(snapshot.annotation)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DuelPanelBrowser: View {
    let duel: Duel
    let selectedPanelID: UUID
    let onSelect: (UUID) -> Void
    let onDuplicate: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onInsertAfter: (UUID) -> Void
    let onMoveUp: (UUID) -> Void
    let onMoveDown: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Panels")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { onInsertAfter(duel.currentPanel?.id ?? duel.sortedPanels.last?.id ?? duel.sortedPanels.first!.id) }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add step after current panel")
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(duel.sortedPanels) { panel in
                        DuelPanelBrowserRow(
                            panel: panel,
                            isSelected: panel.id == selectedPanelID,
                            panelCount: duel.sortedPanels.count,
                            onSelect: onSelect,
                            onDuplicate: onDuplicate,
                            onDelete: onDelete,
                            onMoveUp: onMoveUp,
                            onMoveDown: onMoveDown
                        )
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(14)
    }
}

private struct DuelPanelBrowserRow: View {
    let panel: DuelPanel
    let isSelected: Bool
    let panelCount: Int
    let onSelect: (UUID) -> Void
    let onDuplicate: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onMoveUp: (UUID) -> Void
    let onMoveDown: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { onSelect(panel.id) }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Step \(panel.order + 1): \(panel.title)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        Text(panel.narration.isEmpty ? "No narration yet." : panel.narration)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(action: { onDuplicate(panel.id) }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    Button(action: { onDelete(panel.id) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Button(action: { onMoveUp(panel.id) }) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(panel.order == 0)
                Button(action: { onMoveDown(panel.id) }) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(panel.order == panelCount - 1)
                Spacer()
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor)))
    }
}

private struct DuelPanelEditorView: View {
    @State var panel: DuelPanel
    let allCards: [KnowledgeCard]
    let allSuits: [CardSuit]
    let onUpdate: (DuelPanel) -> Void
    let onAddSnapshot: (UUID, DuelZone) -> Void
    let onDeleteSnapshot: (UUID) -> Void
    let onUpdateSnapshot: (DuelCardSnapshot) -> Void
    let onShowPicker: (DuelZone) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Panel \(panel.order + 1)")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if panel.order != 0 {
                            Text("Snapshot mode")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    TextField("Panel title", text: $panel.title)
                        .textFieldStyle(.roundedBorder)
                    TextField("Narration or blurbs", text: $panel.narration)
                        .textFieldStyle(.roundedBorder)
                    TextField("Opponent caption", text: $panel.opponentCaption)
                        .textFieldStyle(.roundedBorder)
                    TextField("Player caption", text: $panel.playerCaption)
                        .textFieldStyle(.roundedBorder)
                    TextField("Outcome text", text: $panel.outcome)
                        .textFieldStyle(.roundedBorder)
                }

                DuelZoneEditor(
                    zone: .opponent,
                    snapshots: snapshots(in: .opponent),
                    cardsByID: cardsByID,
                    suitsByID: suitsByID,
                    onAdd: { onShowPicker(.opponent) },
                    onUpdateSnapshot: onUpdateSnapshot,
                    onDeleteSnapshot: onDeleteSnapshot
                )
                DuelZoneEditor(
                    zone: .battlefield,
                    snapshots: snapshots(in: .battlefield),
                    cardsByID: cardsByID,
                    suitsByID: suitsByID,
                    onAdd: { onShowPicker(.battlefield) },
                    onUpdateSnapshot: onUpdateSnapshot,
                    onDeleteSnapshot: onDeleteSnapshot
                )
                DuelZoneEditor(
                    zone: .player,
                    snapshots: snapshots(in: .player),
                    cardsByID: cardsByID,
                    suitsByID: suitsByID,
                    onAdd: { onShowPicker(.player) },
                    onUpdateSnapshot: onUpdateSnapshot,
                    onDeleteSnapshot: onDeleteSnapshot
                )

                Button(action: savePanel) {
                    Text("Save Panel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(18)
        }
        .background(Color(.windowBackgroundColor))
        .onChange(of: panel) { _, _ in savePanel() }
    }

    private var cardsByID: [UUID: KnowledgeCard] {
        Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
    }

    private var suitsByID: [String: CardSuit] {
        Dictionary(uniqueKeysWithValues: allSuits.map { ($0.id, $0) })
    }

    private func snapshots(in zone: DuelZone) -> [DuelCardSnapshot] {
        panel.snapshots.filter { $0.zone == zone }.sorted { $0.order < $1.order }
    }

    private func savePanel() {
        onUpdate(panel)
    }
}

private struct DuelZoneEditor: View {
    let zone: DuelZone
    let snapshots: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let onAdd: () -> Void
    let onUpdateSnapshot: (DuelCardSnapshot) -> Void
    let onDeleteSnapshot: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(zone.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onAdd) {
                    Label("Add Card", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }

            if snapshots.isEmpty {
                Text("No cards yet in this zone. Add a card to start the scene.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.controlBackgroundColor)))
            } else {
                VStack(spacing: 10) {
                    ForEach(snapshots) { snapshot in
                        if let card = cardsByID[snapshot.cardID] {
                            DuelSnapshotRow(
                                snapshot: snapshot,
                                card: card,
                                suite: suitsByID[card.suitIDs.first ?? ""],
                                onStatusChange: { updated in onUpdateSnapshot(updated) },
                                onDelete: { onDeleteSnapshot(snapshot.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.controlBackgroundColor)))
    }
}

private struct DuelSnapshotRow: View {
    @State var snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let onStatusChange: (DuelCardSnapshot) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let suite { SuiteBadge(suite: suite, size: 18) }
                        Text(card.title)
                            .font(.system(size: 12, weight: .semibold))
                        if snapshot.isNew {
                            Text("new")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                    Text(snapshot.annotation.isEmpty ? card.frontText : snapshot.annotation)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Menu {
                    Picker("Status", selection: Binding(get: { snapshot.status }, set: { newValue in snapshot.status = newValue; onStatusChange(snapshot) })) {
                        ForEach(DuelCardStatus.allCases, id: \..self) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    Button("Discard") { snapshot.status = .discarded; onStatusChange(snapshot) }
                    Button("Resolved") { snapshot.status = .resolved; onStatusChange(snapshot) }
                } label: {
                    Text(snapshot.status.title)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.5)))
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
            TextField("Note", text: Binding(get: { snapshot.annotation }, set: { snapshot.annotation = $0; onStatusChange(snapshot) }))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
    }
}

private struct DuelCardPickerView: View {
    @EnvironmentObject var cardStore: CardStore
    let zone: DuelZone
    let recentCardIDs: [UUID]
    let onAdd: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedDeckID: String?
    @State private var selectedSuitID: String?
    @State private var favoritesOnly = false
    @State private var previewCard: KnowledgeCard?
    @State private var previewSuite: CardSuit?

    private var filter: CardFilter {
        CardFilter(query: searchText, deckID: selectedDeckID, suitID: selectedSuitID, favoritesOnly: favoritesOnly)
    }

    private var filteredCards: [KnowledgeCard] {
        filter.apply(to: cardStore.cards, suits: cardStore.suits)
    }

    private var recentCards: [KnowledgeCard] {
        recentCardIDs.compactMap { id in cardStore.cards.first(where: { $0.id == id }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add card to \(zone.title)")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Search and choose from your existing cards.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.bordered)
            }
            .padding(16)

            Divider()

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Search cards…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Favorites", isOn: $favoritesOnly)
                        .toggleStyle(.button)
                }

                HStack(spacing: 12) {
                    Picker("Deck", selection: $selectedDeckID) {
                        Text("All decks").tag(String?.none)
                        ForEach(cardStore.decks.sorted { $0.displayOrder < $1.displayOrder }) { deck in
                            Text(deck.name).tag(Optional(deck.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Category", selection: $selectedSuitID) {
                        Text("All categories").tag(String?.none)
                        ForEach(cardStore.suits.rootSuits(deckID: selectedDeckID ?? "")) { suit in
                            Text(suit.name).tag(Optional(suit.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            if !recentCards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentCards) { card in
                            Button(action: { onAdd(card.id) }) {
                                Text(card.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.controlBackgroundColor)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(filteredCards) { card in
                        KnowledgeCardView(
                            card: card,
                            suite: cardStore.suits.first(where: { card.suitIDs.contains($0.id) }),
                            onTap: {
                                previewCard = card
                                previewSuite = cardStore.suits.first(where: { card.suitIDs.contains($0.id) })
                            },
                            onAddToTray: { onAdd(card.id) },
                            onFavorite: {},
                            onEdit: {},
                            onDuplicate: {},
                            onDelete: {}
                        )
                        .frame(height: 120)
                        .contextMenu {
                            Button(action: { onAdd(card.id) }) {
                                Label("Add to \(zone.title)", systemImage: "plus.circle")
                            }
                            Button(action: {
                                previewCard = card
                                previewSuite = cardStore.suits.first(where: { card.suitIDs.contains($0.id) })
                            }) {
                                Label("Preview", systemImage: "eye")
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(item: $previewCard) { card in
            KnowledgeCardDetailView(
                card: card,
                suite: previewSuite,
                allCards: cardStore.cards,
                relationships: cardStore.relationships,
                onEdit: {},
                onAddToTray: {},
                onDismiss: { previewCard = nil }
            )
            .frame(minWidth: 420, minHeight: 520)
        }
    }
}
