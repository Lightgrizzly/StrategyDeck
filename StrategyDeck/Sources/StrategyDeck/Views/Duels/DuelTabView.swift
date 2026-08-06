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
        .background(AC.bg)
        .colorScheme(.dark)
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

// MARK: - Empty state / list

private struct DuelEmptyStateView: View {
    let duels: [Duel]
    let onCreate: () -> Void
    let onOpen: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        ZStack {
            DigitalArenaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DUEL COMIC")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.cyan)
                            .kerning(2)
                        Text("Build a turn-based strategic sequence using your existing cards. Create opponent moves, player responses, and shared battlefield state as comic-style panels.")
                            .font(.system(size: 12))
                            .foregroundStyle(AC.textSub)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                    Button(action: onCreate) {
                        Label("CREATE DUEL", systemImage: "sparkles")
                    }
                    .buttonStyle(ArenaButtonStyle())
                    .padding(.horizontal, 18)

                    Group {
                        ArenaSectionLabel(text: "Saved Duels")
                            .padding(.horizontal, 18)

                        if duels.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No duels yet.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AC.text)
                                Text("Create your first duel and map out your strategy in scenes and steps.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AC.textSub)
                            }
                            .padding(18)
                            .background(
                                AngularCardShape(cornerRadius: 10, cornerCut: 16)
                                    .fill(AC.surface)
                                    .overlay(AngularCardShape(cornerRadius: 10, cornerCut: 16).stroke(AC.borderDim, lineWidth: 0.75))
                            )
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
}

private struct DuelSummaryRow: View {
    let duel: Duel
    let onOpen: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(duel.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AC.text)
                    if let outcome = duel.duelOutcome {
                        Image(systemName: outcome.systemImage)
                            .font(.system(size: 11))
                            .foregroundStyle(outcomeColor(outcome))
                    }
                }
                if !duel.victoryCondition.isEmpty {
                    Text("Victory: \(duel.victoryCondition)")
                        .font(.system(size: 11))
                        .foregroundStyle(AC.textSub)
                        .lineLimit(1)
                } else if !duel.description.isEmpty {
                    Text(duel.description)
                        .font(.system(size: 11))
                        .foregroundStyle(AC.textSub)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text("Panels: \(duel.sortedPanels.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AC.textDim)
                    Text("Updated: \(duel.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AC.textDim)
                }
            }
            Spacer()
            Button(action: { onOpen(duel.id) }) {
                Text("OPEN")
            }
            .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
            Button(role: .destructive, action: { onDelete(duel.id) }) {
                Image(systemName: "trash")
                    .foregroundStyle(AC.threat.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            AngularCardShape(cornerRadius: 10, cornerCut: 16)
                .fill(AC.surface)
        )
        .overlay(
            AngularCardShape(cornerRadius: 10, cornerCut: 16)
                .stroke(AC.borderDim, lineWidth: 0.75)
        )
    }

    private func outcomeColor(_ outcome: DuelOutcome) -> Color {
        switch outcome {
        case .victory: return AC.gold
        case .partialVictory: return .orange
        case .stalemate: return AC.textDim
        case .failure: return AC.threat
        case .abandoned: return AC.textDim
        }
    }
}

// MARK: - New duel sheet

private struct NewDuelSheet: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CREATE A NEW DUEL")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(AC.cyan)
                .kerning(1.5)

            VStack(alignment: .leading, spacing: 10) {
                Text("DUEL NAME")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(1)
                TextField("e.g. Unexpected Requirements vs Clarify", text: $name)
                    .arenaFieldStyle()

                Text("GOAL OR DESCRIPTION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(1)
                TextField("e.g. Solve the integration problem", text: $description)
                    .arenaFieldStyle()
            }

            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { onCreate(); isPresented = false }
                    .buttonStyle(ArenaButtonStyle(isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .background(AC.bg)
        .colorScheme(.dark)
    }
}

// MARK: - Duel editor

private struct DuelEditorView: View {
    @EnvironmentObject var duelStore: DuelStore
    @EnvironmentObject var cardStore: CardStore

    @State private var boardViewMode: DuelBoardViewMode = .board
    @State private var showingCardPicker = false
    @State private var pickerZone: DuelZone = .player
    @State private var selectedCardForPreview: KnowledgeCard?
    @State private var selectedSuiteForPreview: CardSuit?
    @State private var alertState: AlertState?
    @State private var showingCompletionSheet = false
    @State private var showingReopenAlert = false

    private var duel: Duel? { duelStore.currentDuel }
    private var panel: DuelPanel? { duelStore.currentPanel }

    private var cardsByID: [UUID: KnowledgeCard] {
        Dictionary(uniqueKeysWithValues: cardStore.cards.map { ($0.id, $0) })
    }

    private var previousPanel: DuelPanel? {
        guard let duel, let panel else { return nil }
        let sorted = duel.sortedPanels
        guard let idx = sorted.firstIndex(where: { $0.id == panel.id }), idx > 0 else { return nil }
        return sorted[idx - 1]
    }

    var body: some View {
        if let duel, let panel {
            VStack(spacing: 0) {
                DuelHeader(
                    duel: duel,
                    onSave: updateDuel,
                    onExport: exportCurrentDuel,
                    onComplete: { showingCompletionSheet = true },
                    onReopen: { showingReopenAlert = true }
                )

                Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)

                // Board / Comic mode toggle strip
                HStack {
                    Picker("View", selection: $boardViewMode) {
                        ForEach(DuelBoardViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AC.cyan)
                    .frame(width: 180)
                    .padding(.leading, 14)
                    Spacer()
                }
                .frame(height: 36)
                .background(AC.surface)

                Rectangle().fill(AC.borderDim).frame(height: 1)

                Group {
                    if boardViewMode == .board {
                        StrategyDuelBoardView(
                            duel: duel,
                            panel: panel,
                            previousPanel: previousPanel,
                            onUpdate: { duelStore.updatePanel($0) },
                            onAddSnapshot: { cardID, zone in
                                duelStore.addSnapshot(to: panel.id, cardID: cardID, zone: zone)
                                duelStore.recalculatePanel(id: panel.id, allCards: cardStore.cards)
                            },
                            onDeleteSnapshot: { duelStore.deleteSnapshot(id: $0, in: panel.id) },
                            onUpdateSnapshot: { snapshot in
                                duelStore.updateSnapshot(snapshot, in: panel.id)
                                if !snapshot.isManuallyOverridden {
                                    duelStore.recalculatePanel(id: panel.id, allCards: cardStore.cards)
                                }
                            },
                            onShowPicker: { zone in
                                pickerZone = zone
                                showingCardPicker = true
                            },
                            onAddStep: { duelStore.addStep(after: panel.id) },
                            onSelectPanel: { duelStore.setCurrentPanel(id: $0) }
                        )
                    } else {
                        ZStack {
                            DigitalArenaBackground()
                            HStack(spacing: 0) {
                                DuelPanelBrowser(
                                    duel: duel,
                                    selectedPanelID: panel.id,
                                    onSelect: duelStore.setCurrentPanel,
                                    onDuplicate: duelStore.duplicatePanel,
                                    onDelete: { id in
                                        alertState = .destructive(
                                            title: "Delete this panel?",
                                            message: "The panel will be removed from the duel.",
                                            confirmLabel: "Delete"
                                        ) {
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
                                Rectangle().fill(AC.borderDim).frame(width: 1)
                                DuelPanelEditorView(
                                    panel: panel,
                                    previousPanel: previousPanel,
                                    allCards: cardStore.cards,
                                    allSuits: cardStore.suits,
                                    onUpdate: { duelStore.updatePanel($0) },
                                    onAddSnapshot: { cardID, zone in
                                        duelStore.addSnapshot(to: panel.id, cardID: cardID, zone: zone)
                                        duelStore.recalculatePanel(id: panel.id, allCards: cardStore.cards)
                                    },
                                    onDeleteSnapshot: { duelStore.deleteSnapshot(id: $0, in: panel.id) },
                                    onUpdateSnapshot: { snapshot in
                                        duelStore.updateSnapshot(snapshot, in: panel.id)
                                        if !snapshot.isManuallyOverridden {
                                            duelStore.recalculatePanel(id: panel.id, allCards: cardStore.cards)
                                        }
                                    },
                                    onShowPicker: { zone in
                                        pickerZone = zone
                                        showingCardPicker = true
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCardPicker) {
                DuelCardPickerView(
                    zone: pickerZone,
                    duel: duel,
                    currentPanel: panel,
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
            .sheet(isPresented: $showingCompletionSheet) {
                DuelCompletionSheet(
                    duel: duel,
                    isPresented: $showingCompletionSheet,
                    onComplete: { outcome, reflection in
                        duelStore.completeDuel(outcome: outcome, reflection: reflection)
                    },
                    onCreateCard: { title, body in
                        let newCard = KnowledgeCard(
                            deckIDs: cardStore.cards.first?.deckIDs ?? [],
                            suitIDs: cardStore.cards.first?.suitIDs ?? [],
                            kind: .principle,
                            title: title,
                            frontText: body
                        )
                        cardStore.add(newCard)
                    }
                )
                .frame(minWidth: 520, minHeight: 600)
            }
            .alertState($alertState)
            .alert("Reopen Duel?", isPresented: $showingReopenAlert) {
                Button("Reopen") { duelStore.reopenDuel() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear the current outcome and allow further edits.")
            }
        } else {
            ZStack {
                AC.bg
                Text("No duel selected.")
                    .foregroundStyle(AC.textSub)
                    .padding()
            }
        }
    }

    private func updateDuel(_ updated: Duel) {
        duelStore.updateCurrentDuel { duel in
            duel.name = updated.name
            duel.description = updated.description
            duel.victoryCondition = updated.victoryCondition
            duel.failureCondition = updated.failureCondition
            duel.currentProblem = updated.currentProblem
            duel.knownInformation = updated.knownInformation
            duel.unknownInformation = updated.unknownInformation
            duel.constraints = updated.constraints
            duel.updatedAt = Date()
        }
    }

    private func exportCurrentDuel() {
        guard let duel = duelStore.currentDuel else { return }
        let exportView = DuelExportView(duel: duel, allCards: cardStore.cards, allSuits: cardStore.suits)
        let width: CGFloat = 760
        let height: CGFloat = max(900, CGFloat(duel.sortedPanels.count) * 300)
        let hostingView = NSHostingView(rootView: exportView.frame(width: width, height: height))
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let pdfData = hostingView.dataWithPDF(inside: hostingView.bounds)

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(duel.name)-duel.pdf"
        savePanel.allowedContentTypes = [.pdf]
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try pdfData.write(to: url, options: [.atomic])
            } catch {
                alertState = .error(error)
            }
        }
    }
}

// MARK: - Header

private struct DuelHeader: View {
    @State var duel: Duel
    let onSave: (Duel) -> Void
    let onExport: () -> Void
    let onComplete: () -> Void
    let onReopen: () -> Void

    @State private var showingContext = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Duel name", text: $duel.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AC.text)
                        .textFieldStyle(.plain)
                    TextField("Describe the goal or situation", text: $duel.description)
                        .font(.system(size: 12))
                        .textFieldStyle(.plain)
                        .foregroundStyle(AC.textSub)
                }
                Spacer()
                if duel.isCompleted {
                    Button(action: onReopen) {
                        Label("Reopen", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(ArenaOutlineButtonStyle())
                } else {
                    Button(action: onComplete) {
                        Label("Complete", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.gold.opacity(0.55)))
                }
                Button(action: onExport) { Text("Export PDF") }
                    .buttonStyle(ArenaOutlineButtonStyle())
                Button(action: { onSave(duel) }) { Text("Save Duel") }
                    .buttonStyle(ArenaButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Victory condition (always visible)
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AC.gold)
                Text("Victory:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AC.textSub)
                TextField("Define what success looks like…", text: $duel.victoryCondition)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .foregroundStyle(AC.text)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            // Outcome badge (if completed)
            if let outcome = duel.duelOutcome {
                HStack(spacing: 6) {
                    Image(systemName: outcome.systemImage)
                        .font(.system(size: 10))
                    Text(outcome.title)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(outcomeColor(outcome))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    AngularCardShape(cornerRadius: 6, cornerCut: 10)
                        .fill(outcomeColor(outcome).opacity(0.15))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
            }

            // Expandable context
            DisclosureGroup(isExpanded: $showingContext) {
                VStack(alignment: .leading, spacing: 6) {
                    DuelContextField(label: "Problem", placeholder: "What is the current situation?", text: $duel.currentProblem)
                    DuelContextField(label: "Known", placeholder: "What is already understood?", text: $duel.knownInformation)
                    DuelContextField(label: "Unknown", placeholder: "What is still unclear?", text: $duel.unknownInformation)
                    DuelContextField(label: "Constraints", placeholder: "What limits what you can do?", text: $duel.constraints)
                    DuelContextField(label: "Failure", placeholder: "What would make this a loss?", text: $duel.failureCondition)
                }
                .padding(.top, 6)
                .padding(.bottom, 4)
            } label: {
                Text("Context fields")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AC.textSub)
            }
            .tint(AC.cyan)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(AC.surface)
        .colorScheme(.dark)
        .onChange(of: duel) { _, new in onSave(new) }
    }

    private func outcomeColor(_ outcome: DuelOutcome) -> Color {
        switch outcome {
        case .victory: return AC.gold
        case .partialVictory: return .orange
        case .stalemate: return AC.textDim
        case .failure: return AC.threat
        case .abandoned: return AC.textDim
        }
    }
}

private struct DuelContextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
                .kerning(1)
                .frame(width: 74, alignment: .trailing)
            TextField(placeholder, text: $text)
                .arenaFieldStyle()
        }
    }
}

// MARK: - Export
//
// Rendered to PDF for sharing outside the app — kept on the system light
// chrome (rather than the arena theme) since it's a printable document, not
// an on-screen surface.

private struct DuelExportView: View {
    let duel: Duel
    let allCards: [KnowledgeCard]
    let allSuits: [CardSuit]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(duel.name)
                    .font(.system(size: 28, weight: .bold))
                if !duel.description.isEmpty {
                    Text(duel.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                if !duel.victoryCondition.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        Text("Victory Condition: \(duel.victoryCondition)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                if !duel.failureCondition.isEmpty {
                    Text("Failure Condition: \(duel.failureCondition)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                if !duel.currentProblem.isEmpty {
                    Text("Problem: \(duel.currentProblem)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Divider()
            }

            // Panels
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
                        DuelExportZoneView(
                            title: "Opponent",
                            snapshots: panel.snapshots.filter { $0.zone == .opponent },
                            allCards: allCards,
                            allSuits: allSuits
                        )
                        DuelExportZoneView(
                            title: "Battlefield",
                            snapshots: panel.snapshots.filter { $0.zone == .battlefield },
                            allCards: allCards,
                            allSuits: allSuits
                        )
                        DuelExportZoneView(
                            title: "Player",
                            snapshots: panel.snapshots.filter { $0.zone == .player },
                            allCards: allCards,
                            allSuits: allSuits
                        )
                    }
                    if !panel.outcome.isEmpty {
                        Text("Outcome: \(panel.outcome)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    if !panel.reasoning.isEmpty {
                        Divider()
                        DuelExportReasoningView(reasoning: panel.reasoning)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.windowBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separatorColor)))
            }

            // Outcome + reflection
            if let outcome = duel.duelOutcome {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: outcome.systemImage)
                        Text("Outcome: \(outcome.title)")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    if let reflection = duel.reflection, !reflection.isEmpty {
                        DuelExportReflectionView(reflection: reflection)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.title)
                                .font(.system(size: 11, weight: .semibold))
                            Text(snapshot.strategicZone.title)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
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

private struct DuelExportReasoningView: View {
    let reasoning: PanelReasoning

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Move Reasoning")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if !reasoning.whyThisCard.isEmpty {
                Text("Why: \(reasoning.whyThisCard)").font(.system(size: 10))
            }
            if !reasoning.whatChanged.isEmpty {
                Text("Changed: \(reasoning.whatChanged)").font(.system(size: 10))
            }
            if !reasoning.whatUnlocked.isEmpty {
                Text("Unlocked: \(reasoning.whatUnlocked)").font(.system(size: 10))
            }
            if !reasoning.whatBlocked.isEmpty {
                Text("Blocked: \(reasoning.whatBlocked)").font(.system(size: 10))
            }
            if !reasoning.riskIntroduced.isEmpty {
                Text("Risk: \(reasoning.riskIntroduced)").font(.system(size: 10))
            }
            if !reasoning.whatLearned.isEmpty {
                Text("Learned: \(reasoning.whatLearned)").font(.system(size: 10))
            }
        }
    }
}

private struct DuelExportReflectionView: View {
    let reflection: DuelReflection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !reflection.cardThatMatteredMost.isEmpty {
                Text("Most impactful: \(reflection.cardThatMatteredMost)").font(.system(size: 11))
            }
            if !reflection.lessonLearned.isEmpty {
                Text("Lesson: \(reflection.lessonLearned)")
                    .font(.system(size: 11, weight: .semibold))
            }
            if !reflection.doNextTime.isEmpty {
                Text("Next time: \(reflection.doNextTime)").font(.system(size: 11))
            }
        }
    }
}

// MARK: - Panel browser

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
                ArenaSectionLabel(text: "Panels")
                Spacer()
                Button(action: {
                    onInsertAfter(duel.currentPanel?.id ?? duel.sortedPanels.last?.id ?? duel.sortedPanels.first!.id)
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.cyan)
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
                            .foregroundStyle(isSelected ? AC.cyan : AC.text)
                        Text(panel.narration.isEmpty ? "No narration yet." : panel.narration)
                            .font(.system(size: 10))
                            .foregroundStyle(AC.textSub)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(action: { onDuplicate(panel.id) }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AC.textDim)
                    Button(action: { onDelete(panel.id) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AC.threat.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
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
                if !panel.reasoning.isEmpty {
                    Image(systemName: "text.quote")
                        .font(.system(size: 9))
                        .foregroundStyle(AC.textDim)
                        .help("Has move reasoning")
                }
            }
            .foregroundStyle(AC.textSub)
        }
        .padding(10)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(isSelected ? AC.cyanSoft : AC.surface)
        )
        .overlay(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .stroke(isSelected ? AC.cyan.opacity(0.5) : AC.borderDim, lineWidth: isSelected ? 1 : 0.75)
        )
    }
}

// MARK: - Panel editor

private struct DuelPanelEditorView: View {
    @State var panel: DuelPanel
    let previousPanel: DuelPanel?
    let allCards: [KnowledgeCard]
    let allSuits: [CardSuit]
    let onUpdate: (DuelPanel) -> Void
    let onAddSnapshot: (UUID, DuelZone) -> Void
    let onDeleteSnapshot: (UUID) -> Void
    let onUpdateSnapshot: (DuelCardSnapshot) -> Void
    let onShowPicker: (DuelZone) -> Void

    @State private var showingReasoning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // State transitions summary
                let transitions = PlayabilityEvaluator.stateTransitions(
                    from: previousPanel,
                    to: panel,
                    cardsByID: cardsByID
                )
                if !transitions.isEmpty {
                    DuelTransitionSummaryView(transitions: transitions)
                }

                // Panel fields
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Panel \(panel.order + 1)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AC.text)
                        Spacer()
                        if panel.order != 0 {
                            Text("Snapshot mode")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AC.textDim)
                        }
                    }
                    TextField("Panel title", text: $panel.title).arenaFieldStyle()
                    TextField("Narration or blurbs", text: $panel.narration).arenaFieldStyle()
                    TextField("Opponent caption", text: $panel.opponentCaption).arenaFieldStyle()
                    TextField("Player caption", text: $panel.playerCaption).arenaFieldStyle()
                    TextField("Outcome text", text: $panel.outcome).arenaFieldStyle()
                }

                // Zone editors
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

                // Move reasoning
                DisclosureGroup(isExpanded: $showingReasoning) {
                    DuelReasoningEditor(reasoning: $panel.reasoning)
                        .padding(.top, 6)
                } label: {
                    HStack(spacing: 6) {
                        Text("Move Reasoning")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AC.text)
                        if !panel.reasoning.isEmpty {
                            Circle()
                                .fill(AC.cyan)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .tint(AC.cyan)

                Button(action: savePanel) {
                    Text("Save Panel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ArenaButtonStyle())
                .padding(.top, 8)
            }
            .padding(18)
        }
        .background(Color.clear)
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

// MARK: - Transition summary

private struct DuelTransitionSummaryView: View {
    let transitions: [SnapshotChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArenaSectionLabel(text: "Changes since last panel")
            ForEach(Array(transitions.enumerated()), id: \.offset) { _, change in
                HStack(spacing: 6) {
                    Image(systemName: change.systemImage)
                        .font(.system(size: 10))
                        .foregroundStyle(changeColor(change))
                    Text(change.label)
                        .font(.system(size: 11))
                        .foregroundStyle(AC.textSub)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(AC.surface.opacity(0.7))
        )
    }

    private func changeColor(_ change: SnapshotChange) -> Color {
        switch change.kind {
        case .added: return AC.available
        case .removed: return AC.threat
        case .statusChanged: return .orange
        case .strategicZoneChanged: return AC.cyan
        }
    }
}

// MARK: - Reasoning editor

private struct DuelReasoningEditor: View {
    @Binding var reasoning: PanelReasoning

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReasoningField("Why this move?", placeholder: "The reason this card was selected", text: $reasoning.whyThisCard)
            ReasoningField("What changed?", placeholder: "What shifted in the situation", text: $reasoning.whatChanged)
            ReasoningField("Unlocked", placeholder: "Cards or options this enables", text: $reasoning.whatUnlocked)
            ReasoningField("Blocked", placeholder: "Cards or options this closes off", text: $reasoning.whatBlocked)
            ReasoningField("Risk introduced", placeholder: "What new risk did this create?", text: $reasoning.riskIntroduced)
            ReasoningField("What was learned?", placeholder: "New insight or information", text: $reasoning.whatLearned)
        }
    }
}

private struct ReasoningField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    init(_ label: String, placeholder: String, text: Binding<String>) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
                .kerning(0.5)
                .frame(width: 100, alignment: .trailing)
            TextField(placeholder, text: $text)
                .arenaFieldStyle()
        }
    }
}

// MARK: - Zone editor

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
                        .foregroundStyle(AC.text)
                    Text(zone.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(AC.textDim)
                }
                Spacer()
                Button(action: onAdd) {
                    Label("Add Card", systemImage: "plus")
                }
                .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
            }

            if snapshots.isEmpty {
                Text("No cards yet in this zone. Add a card to start the scene.")
                    .font(.system(size: 11))
                    .foregroundStyle(AC.textSub)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        AngularCardShape(cornerRadius: 8, cornerCut: 12)
                            .fill(AC.surface)
                    )
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
        .background(
            AngularCardShape(cornerRadius: 10, cornerCut: 16)
                .fill(AC.glassPanel.opacity(0.6))
        )
        .overlay(
            AngularCardShape(cornerRadius: 10, cornerCut: 16)
                .stroke(AC.borderDim, lineWidth: 0.75)
        )
    }
}

// MARK: - Snapshot row

private struct DuelSnapshotRow: View {
    @State var snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let onStatusChange: (DuelCardSnapshot) -> Void
    let onDelete: () -> Void

    @State private var showingPlayability = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let suite { SuiteBadge(suite: suite, size: 18) }
                        Text(card.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AC.text)
                        if snapshot.isNew {
                            Text("NEW")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(AC.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(AngularCardShape(cornerRadius: 4, cornerCut: 6).fill(AC.cyanSoft))
                        }
                        if snapshot.isManuallyOverridden {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                                .help("Strategic zone manually set")
                        }
                    }
                    Text(snapshot.annotation.isEmpty ? card.frontText : snapshot.annotation)
                        .font(.system(size: 10))
                        .foregroundStyle(AC.textSub)
                        .lineLimit(2)
                }
                Spacer()

                // Strategic zone menu
                Menu {
                    ForEach(StrategicZone.allCases, id: \.self) { zone in
                        Button(action: {
                            snapshot.strategicZone = zone
                            snapshot.isManuallyOverridden = true
                            onStatusChange(snapshot)
                        }) {
                            Label(zone.title, systemImage: zone.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.strategicZone.systemImage)
                            .font(.system(size: 9))
                        Text(snapshot.strategicZone.title.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        AngularCardShape(cornerRadius: 5, cornerCut: 8)
                            .fill(strategicZoneColor(snapshot.strategicZone).opacity(0.14))
                    )
                    .foregroundStyle(strategicZoneColor(snapshot.strategicZone))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                // Status menu
                Menu {
                    Picker("Status", selection: Binding(
                        get: { snapshot.status },
                        set: { newValue in snapshot.status = newValue; onStatusChange(snapshot) }
                    )) {
                        ForEach(DuelCardStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    Divider()
                    Button("Discard") { snapshot.status = .discarded; onStatusChange(snapshot) }
                    Button("Resolved") { snapshot.status = .resolved; onStatusChange(snapshot) }
                } label: {
                    Text(snapshot.status.title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AC.textSub)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            AngularCardShape(cornerRadius: 5, cornerCut: 8)
                                .stroke(AC.borderDim, lineWidth: 0.75)
                        )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                // Playability info (only shown when rules are defined)
                if !card.playabilityRules.isEmpty {
                    Button(action: { showingPlayability.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(AC.textDim)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingPlayability, arrowEdge: .trailing) {
                        PlayabilityInfoPopover(card: card)
                    }
                }

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.threat.opacity(0.75))
            }
            TextField("Note", text: Binding(
                get: { snapshot.annotation },
                set: { snapshot.annotation = $0; onStatusChange(snapshot) }
            ))
            .arenaFieldStyle()
        }
        .padding(12)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(AC.surface)
        )
        .opacity(snapshot.strategicZone == .locked ? 0.65 : 1.0)
    }

    private func strategicZoneColor(_ zone: StrategicZone) -> Color {
        switch zone {
        case .deck: return AC.cyanDim
        case .hand: return AC.available
        case .field: return AC.cyan
        case .locked: return AC.lockedTint
        case .exhausted: return .orange
        case .discarded: return AC.threat
        case .resolved: return AC.resolved
        }
    }
}

// MARK: - Playability info popover

private struct PlayabilityInfoPopover: View {
    let card: KnowledgeCard

    var body: some View {
        let rules = card.playabilityRules
        VStack(alignment: .leading, spacing: 10) {
            ArenaSectionLabel(text: "Playability Rules")

            if !rules.prerequisites.isEmpty {
                PlayabilitySection(title: "Prerequisites", items: rules.prerequisites, color: AC.cyan)
            }
            if !rules.requiredActiveCardTitles.isEmpty {
                PlayabilitySection(title: "Requires active", items: rules.requiredActiveCardTitles, color: AC.available)
            }
            if !rules.blockedByCardTitles.isEmpty {
                PlayabilitySection(title: "Blocked by", items: rules.blockedByCardTitles, color: AC.threat)
            }
            if !rules.unlockedByCardTitles.isEmpty {
                PlayabilitySection(title: "Unlocked by", items: rules.unlockedByCardTitles, color: AC.resolved)
            }
            if !rules.unlocksCardTitles.isEmpty {
                PlayabilitySection(title: "Unlocks", items: rules.unlocksCardTitles, color: .purple)
            }
            if !rules.disablesCardTitles.isEmpty {
                PlayabilitySection(title: "Disables", items: rules.disablesCardTitles, color: .orange)
            }
            HStack(spacing: 12) {
                if !rules.canBeReused {
                    Label("Single use", systemImage: "1.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(AC.textSub)
                }
                if rules.exhaustsAfterUse {
                    Label("Exhausts after use", systemImage: "bolt.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(AC.textSub)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 220)
        .background(AC.glassPanel)
        .colorScheme(.dark)
    }
}

private struct PlayabilitySection: View {
    let title: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .kerning(1)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 4, height: 4)
                    Text(item).font(.system(size: 10)).foregroundStyle(AC.textSub)
                }
            }
        }
    }
}

// MARK: - Card picker

private struct DuelCardPickerView: View {
    @EnvironmentObject var cardStore: CardStore
    let zone: DuelZone
    let duel: Duel
    let currentPanel: DuelPanel
    let recentCardIDs: [UUID]
    let onAdd: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedDeckID: String?
    @State private var selectedSuitID: String?
    @State private var favoritesOnly = false
    @State private var previewCard: KnowledgeCard?
    @State private var previewSuite: CardSuit?
    @State private var showAvailableOnly = false

    private var cardsByID: [UUID: KnowledgeCard] {
        Dictionary(uniqueKeysWithValues: cardStore.cards.map { ($0.id, $0) })
    }

    private var playabilityContext: PlayabilityContext {
        PlayabilityEvaluator.context(from: currentPanel, duel: duel, cardsByID: cardsByID)
    }

    private func playabilityFor(_ card: KnowledgeCard) -> PlayabilityResult {
        PlayabilityEvaluator.evaluate(card: card, context: playabilityContext)
    }

    private var filter: CardFilter {
        CardFilter(query: searchText, deckID: selectedDeckID, suitID: selectedSuitID, favoritesOnly: favoritesOnly)
    }

    private var filteredCards: [KnowledgeCard] {
        let base = filter.apply(to: cardStore.cards, suits: cardStore.suits)
        if showAvailableOnly {
            return base.filter { playabilityFor($0).isPlayable }
        }
        return base
    }

    private var recentCards: [KnowledgeCard] {
        recentCardIDs.compactMap { id in cardStore.cards.first(where: { $0.id == id }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADD CARD TO \(zone.title.uppercased())")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.cyan)
                        .kerning(1)
                    Text("Search and choose from your existing cards.")
                        .font(.system(size: 11))
                        .foregroundStyle(AC.textSub)
                }
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(ArenaOutlineButtonStyle())
            }
            .padding(16)
            .background(AC.surface)

            Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Search cards…", text: $searchText)
                        .arenaFieldStyle()
                    Toggle("Favorites", isOn: $favoritesOnly)
                        .toggleStyle(.button)
                        .tint(AC.gold)
                    Toggle("Available only", isOn: $showAvailableOnly)
                        .toggleStyle(.button)
                        .tint(AC.cyan)
                }

                HStack(spacing: 12) {
                    Picker("Deck", selection: $selectedDeckID) {
                        Text("All decks").tag(String?.none)
                        ForEach(cardStore.decks.sorted { $0.displayOrder < $1.displayOrder }) { deck in
                            Text(deck.name).tag(Optional(deck.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AC.cyan)

                    Picker("Category", selection: $selectedSuitID) {
                        Text("All categories").tag(String?.none)
                        ForEach(cardStore.suits.rootSuits(deckID: selectedDeckID ?? "")) { suit in
                            Text(suit.name).tag(Optional(suit.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AC.cyan)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
            .padding(.top, 10)

            if !recentCards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentCards) { card in
                            Button(action: { onAdd(card.id) }) {
                                Text(card.title)
                            }
                            .buttonStyle(ArenaOutlineButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(filteredCards) { card in
                        let result = playabilityFor(card)
                        ZStack(alignment: .bottomLeading) {
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
                            .opacity(result.isPlayable || card.playabilityRules.isEmpty ? 1.0 : 0.5)

                            if !card.playabilityRules.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: result.isPlayable ? "checkmark.circle.fill" : "lock.fill")
                                        .font(.system(size: 8))
                                    Text(result.isPlayable ? "Available" : "Locked")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(result.isPlayable ? AC.available.opacity(0.85) : AC.textDim.opacity(0.85)))
                                .foregroundStyle(AC.bg)
                                .padding(6)
                            }
                        }
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
                            if !card.playabilityRules.isEmpty && !result.isPlayable {
                                Divider()
                                Button(action: {}) {
                                    Label("Locked: \(result.blockedReasons.first ?? "see rules")", systemImage: "lock")
                                }
                                .disabled(true)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
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

// MARK: - Completion sheet

private struct DuelCompletionSheet: View {
    let duel: Duel
    @Binding var isPresented: Bool
    let onComplete: (DuelOutcome, DuelReflection) -> Void
    let onCreateCard: (String, String) -> Void

    @State private var selectedOutcome: DuelOutcome = .victory
    @State private var reflection = DuelReflection()
    @State private var showingCreateCard = false
    @State private var newCardTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMPLETE DUEL")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.gold)
                    .kerning(1.5)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            .background(AC.surface)
            Rectangle().fill(AC.gold.opacity(0.25)).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Outcome selector
                    VStack(alignment: .leading, spacing: 8) {
                        ArenaSectionLabel(text: "Outcome", color: AC.gold)
                        HStack(spacing: 8) {
                            ForEach(DuelOutcome.allCases, id: \.self) { outcome in
                                Button(action: { selectedOutcome = outcome }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: outcome.systemImage)
                                            .font(.system(size: 14))
                                        Text(outcome.title)
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .padding(10)
                                    .frame(minWidth: 70)
                                    .foregroundStyle(selectedOutcome == outcome ? AC.gold : AC.textSub)
                                    .background(
                                        AngularCardShape(cornerRadius: 8, cornerCut: 12)
                                            .fill(selectedOutcome == outcome ? AC.goldSoft : AC.surface)
                                    )
                                    .overlay(
                                        AngularCardShape(cornerRadius: 8, cornerCut: 12)
                                            .stroke(selectedOutcome == outcome ? AC.gold : AC.borderDim, lineWidth: selectedOutcome == outcome ? 1.25 : 0.75)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Rectangle().fill(AC.borderDim).frame(height: 1)

                    // Reflection
                    VStack(alignment: .leading, spacing: 6) {
                        ArenaSectionLabel(text: "Reflection · optional")
                        CompactReflectionField("Which card mattered most?", text: $reflection.cardThatMatteredMost)
                        CompactReflectionField("Should have played earlier?", text: $reflection.cardToPlayEarlier)
                        CompactReflectionField("Unnecessary card?", text: $reflection.unnecessaryCard)
                        CompactReflectionField("Incorrect assumption?", text: $reflection.incorrectAssumption)
                        CompactReflectionField("Discovered new strategy?", text: $reflection.discoveredStrategy)
                        CompactReflectionField("Rule to change for next time?", text: $reflection.ruleToChange)
                        CompactReflectionField("What to do next time?", text: $reflection.doNextTime)
                    }

                    // Lesson → card
                    VStack(alignment: .leading, spacing: 8) {
                        ArenaSectionLabel(text: "Lesson Learned")
                        TextField("Summarize the most important lesson…", text: $reflection.lessonLearned)
                            .arenaFieldStyle()
                        if !reflection.lessonLearned.isEmpty {
                            Button(action: { showingCreateCard = true }) {
                                Label("Create card from this lesson", systemImage: "plus.rectangle.on.rectangle")
                            }
                            .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                        }
                    }
                }
                .padding(18)
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)
            HStack {
                Spacer()
                Button("Complete Duel") {
                    onComplete(selectedOutcome, reflection)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(ArenaButtonStyle(color: AC.gold))
            }
            .padding(14)
            .background(AC.surface)
        }
        .background(AC.bg)
        .colorScheme(.dark)
        .sheet(isPresented: $showingCreateCard) {
            CreateCardFromLessonSheet(
                lessonText: reflection.lessonLearned,
                isPresented: $showingCreateCard,
                onCreate: { title in
                    newCardTitle = title
                    onCreateCard(title, reflection.lessonLearned)
                }
            )
            .frame(minWidth: 380, minHeight: 200)
        }
        .onAppear {
            if let existing = duel.duelOutcome {
                selectedOutcome = existing
            }
            if let existing = duel.reflection {
                reflection = existing
            }
        }
    }
}

private struct CompactReflectionField: View {
    let prompt: String
    @Binding var text: String

    init(_ prompt: String, text: Binding<String>) {
        self.prompt = prompt
        self._text = text
    }

    var body: some View {
        TextField(prompt, text: $text)
            .arenaFieldStyle()
    }
}

private struct CreateCardFromLessonSheet: View {
    let lessonText: String
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    @State private var cardTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CREATE CARD FROM LESSON")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(AC.cyan)
                .kerning(1)
            Text("Lesson: \(lessonText)")
                .font(.system(size: 11))
                .foregroundStyle(AC.textSub)
                .lineLimit(3)
            TextField("Card title (e.g. Reproduce Before Modification)", text: $cardTitle)
                .arenaFieldStyle()
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create Card") {
                    guard !cardTitle.isEmpty else { return }
                    onCreate(cardTitle)
                    isPresented = false
                }
                .buttonStyle(ArenaButtonStyle(isDisabled: cardTitle.trimmingCharacters(in: .whitespaces).isEmpty))
                .keyboardShortcut(.defaultAction)
                .disabled(cardTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear {
            cardTitle = lessonText
                .components(separatedBy: .whitespacesAndNewlines)
                .prefix(5)
                .joined(separator: " ")
                .trimmingCharacters(in: .punctuationCharacters)
        }
    }
}
