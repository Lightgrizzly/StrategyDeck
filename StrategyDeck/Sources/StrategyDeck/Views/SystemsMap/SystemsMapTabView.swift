import SwiftUI
import AppKit
import StrategyDeckCore

struct SystemsMapTabView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    @EnvironmentObject var cardStore: CardStore

    var body: some View {
        Group {
            if systemMapStore.currentSystemMap != nil {
                SystemsMapEditorView()
            } else {
                SystemsMapEmptyStateView()
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
    }
}

// MARK: - Empty state / list

private struct SystemsMapEmptyStateView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    @State private var showingNewSheet = false
    @State private var newTitle = ""
    @State private var newDescription = ""
    @State private var newGoal = ""
    @State private var alertState: AlertState?

    var body: some View {
        ZStack {
            DigitalArenaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SYSTEMS MAP")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.cyan)
                            .kerning(2)
                        Text("Build a Donella Meadows–style stock-and-flow diagram of the system you're working in, while seeing which strategy cards are active, available, locked, or disabled at every point. The diagram is the map of the system — the cards are the available interventions.")
                            .font(.system(size: 12))
                            .foregroundStyle(AC.textSub)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                    HStack(spacing: 10) {
                        Button(action: { showingNewSheet = true }) {
                            Label("CREATE SYSTEM MAP", systemImage: "point.3.connected.trianglepath.dotted")
                        }
                        .buttonStyle(ArenaButtonStyle())

                        Button(action: loadExample) {
                            Label("LOAD EXAMPLE: INVENTORY RESILIENCE", systemImage: "shippingbox")
                        }
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                    }
                    .padding(.horizontal, 18)

                    Group {
                        ArenaSectionLabel(text: "Saved System Maps").padding(.horizontal, 18)

                        if systemMapStore.systemMaps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No system maps yet.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AC.text)
                                Text("Create one, or load the example to see how it works.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AC.textSub)
                            }
                            .padding(18)
                            .background(AngularCardShape(cornerRadius: 10, cornerCut: 16).fill(AC.surface))
                            .padding(.horizontal, 18)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(systemMapStore.systemMaps.sorted { $0.updatedAt > $1.updatedAt }) { map in
                                    SystemMapSummaryRow(
                                        map: map,
                                        onOpen: { systemMapStore.openSystemMap(id: map.id) },
                                        onDuplicate: { systemMapStore.duplicateSystemMap(id: map.id) },
                                        onDelete: {
                                            alertState = .destructive(
                                                title: "Delete “\(map.title)”?",
                                                message: "This will remove the saved system map and its full step history permanently.",
                                                confirmLabel: "Delete"
                                            ) { systemMapStore.deleteSystemMap(id: map.id) }
                                        }
                                    )
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
        .alertState($alertState)
        .sheet(isPresented: $showingNewSheet) {
            NewSystemMapSheet(
                title: $newTitle,
                description: $newDescription,
                goal: $newGoal,
                isPresented: $showingNewSheet,
                onCreate: {
                    guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    systemMapStore.createSystemMap(title: newTitle, description: newDescription, primaryGoal: newGoal)
                    newTitle = ""; newDescription = ""; newGoal = ""
                }
            )
            .frame(minWidth: 420, minHeight: 260)
        }
    }

    private func loadExample() {
        systemMapStore.addAndOpen(SystemMapTemplates.inventoryResilience())
    }
}

private struct SystemMapSummaryRow: View {
    let map: SystemMap
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(map.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(AC.text)
                if !map.primaryGoal.isEmpty {
                    Text("Goal: \(map.primaryGoal)").font(.system(size: 11)).foregroundStyle(AC.textSub).lineLimit(1)
                } else if !map.description.isEmpty {
                    Text(map.description).font(.system(size: 11)).foregroundStyle(AC.textSub).lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text("Steps: \(map.steps.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(AC.textDim)
                    Text("Elements: \(map.latestStep?.elements.count ?? 0)").font(.system(size: 10, design: .monospaced)).foregroundStyle(AC.textDim)
                    Text("Updated: \(map.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))").font(.system(size: 10, design: .monospaced)).foregroundStyle(AC.textDim)
                }
            }
            Spacer()
            Button(action: onOpen) { Text("OPEN") }.buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
            Button(action: onDuplicate) { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).foregroundStyle(AC.textDim)
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(AC.threat.opacity(0.75))
        }
        .padding(12)
        .background(AngularCardShape(cornerRadius: 10, cornerCut: 16).fill(AC.surface))
        .overlay(AngularCardShape(cornerRadius: 10, cornerCut: 16).stroke(AC.borderDim, lineWidth: 0.75))
    }
}

private struct NewSystemMapSheet: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var goal: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CREATE A SYSTEM MAP").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1.5)
            VStack(alignment: .leading, spacing: 10) {
                labeledField("TITLE") { TextField("e.g. Inventory Resilience", text: $title).arenaFieldStyle() }
                labeledField("DESCRIPTION") { TextField("What system is this?", text: $description).arenaFieldStyle() }
                labeledField("PRIMARY GOAL") { TextField("What outcome are you trying to reach?", text: $goal).arenaFieldStyle() }
            }
            HStack {
                Button("Cancel") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { onCreate(); isPresented = false }
                    .buttonStyle(ArenaButtonStyle(isDisabled: title.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .background(AC.bg)
        .colorScheme(.dark)
    }

    @ViewBuilder
    private func labeledField<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
            content()
        }
    }
}

// MARK: - Editor

private struct SystemsMapEditorView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    @EnvironmentObject var cardStore: CardStore

    @State private var tool: DiagramTool = .select
    @State private var selection: DiagramSelection?
    @State private var pendingConnectSourceID: UUID?
    @State private var showingInspector = true
    @State private var showingPlaySheetFor: KnowledgeCard?
    @State private var showingRenameSheet = false
    @State private var renameText = ""
    @State private var alertState: AlertState?
    @State private var undoStack: [DiagramSnapshot] = []
    @State private var redoStack: [DiagramSnapshot] = []

    private struct DiagramSnapshot {
        var elements: [SystemElement]
        var flows: [SystemFlow]
        var relationships: [SystemRelationship]
    }

    private var map: SystemMap { systemMapStore.currentSystemMap ?? SystemMap(title: "") }
    private var step: SystemStep { map.currentStep ?? SystemStep(index: 0) }
    private var isEditable: Bool { map.isViewingLatestStep }

    private var selectedTargetKind: SystemTargetKind? {
        switch selection {
        case .element(let id):
            guard let el = step.elements.first(where: { $0.id == id }) else { return nil }
            return SystemMapEvaluator.targetKind(for: el.kind)
        case .flow: return .flow
        case .relationship: return .relationship
        case .none: return nil
        }
    }

    private var selectedElementIDForPlay: UUID? {
        if case .element(let id) = selection { return id }
        return nil
    }

    private var selectionLabel: String {
        switch selection {
        case .element(let id): return step.elements.first(where: { $0.id == id })?.name ?? "Element"
        case .flow(let id): return step.flows.first(where: { $0.id == id })?.name ?? "Flow"
        case .relationship: return "Relationship"
        case .none: return "Entire System"
        }
    }

    private var evaluations: [SystemCardEvaluation] {
        SystemMapEvaluator.evaluateAll(cards: cardStore.cards, step: step, selectedTargetKind: selectedTargetKind)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)

            SystemDiagramToolbar(
                tool: $tool,
                isEditable: isEditable,
                hasSelection: selection != nil,
                canUndo: !undoStack.isEmpty && isEditable,
                canRedo: !redoStack.isEmpty && isEditable,
                onDelete: deleteSelection,
                onUndo: undo,
                onRedo: redo,
                onZoomIn: {}, onZoomOut: {}, onFit: {}, onCenterSelection: {}
            )
            Rectangle().fill(AC.borderDim).frame(height: 1)

            HStack(spacing: 0) {
                SystemDiagramCanvasView(
                    step: step,
                    isEditable: isEditable,
                    selection: $selection,
                    tool: $tool,
                    pendingConnectSourceID: $pendingConnectSourceID,
                    onAddElement: { element in pushUndo(); systemMapStore.addElement(element) },
                    onMoveElement: { id, pos in pushUndo(); moveElement(id: id, to: pos) },
                    onAddFlow: { flow in pushUndo(); systemMapStore.addFlow(flow) },
                    onAddRelationship: { rel in pushUndo(); systemMapStore.addRelationship(rel) }
                )
                if showingInspector {
                    Rectangle().fill(AC.borderDim).frame(width: 1)
                    SystemElementInspectorView(
                        step: step,
                        selection: selection,
                        onUpdateElement: { el in pushUndo(); systemMapStore.updateElement(el) },
                        onUpdateFlow: { flow in pushUndo(); systemMapStore.updateFlow(flow) },
                        onUpdateRelationship: { rel in
                            pushUndo()
                            systemMapStore.deleteRelationship(id: rel.id)
                            systemMapStore.addRelationship(rel)
                        },
                        relatedCardCount: { kind in
                            cardStore.cards.filter { $0.playabilityRules.systemTargetTypes.contains(kind) }.count
                        }
                    )
                }
            }
            .frame(minHeight: 260, idealHeight: 340)

            SystemStepTimelineView(
                steps: map.steps,
                currentStepID: map.currentStepID,
                isViewingLatest: map.isViewingLatestStep,
                onSelectStep: { systemMapStore.setCurrentStep(id: $0) },
                onReturnToLatest: { systemMapStore.returnToLatestStep() },
                onNextStep: { systemMapStore.addStep(); selection = nil },
                onChangeSelected: { change in
                    if let id = change.relatedElementID { selection = .element(id) }
                }
            )

            SystemCardLibraryView(
                cards: cardStore.cards,
                suits: cardStore.suits,
                evaluations: evaluations,
                selectionLabel: selectionLabel,
                isEditable: isEditable,
                onPlay: { showingPlaySheetFor = $0 },
                onClearOverride: { systemMapStore.setManualOverride(cardID: $0.id, status: nil) }
            )
            .frame(maxHeight: .infinity)
        }
        .background(AC.bg)
        .colorScheme(.dark)
        .alertState($alertState)
        .sheet(item: $showingPlaySheetFor) { card in
            PlayCardSheet(
                card: card,
                targetLabel: selectionLabel,
                targetKind: selectedTargetKind ?? .system,
                onConfirm: { notes in
                    systemMapStore.playCard(
                        card: card,
                        targetElementID: selectedElementIDForPlay,
                        targetKind: selectedTargetKind ?? .system,
                        allCards: cardStore.cards,
                        notes: notes
                    )
                    showingPlaySheetFor = nil
                },
                onCancel: { showingPlaySheetFor = nil }
            )
            .frame(minWidth: 420, minHeight: 320)
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameSystemMapSheet(
                title: $renameText,
                isPresented: $showingRenameSheet,
                onSave: { systemMapStore.renameSystemMap(id: map.id, title: renameText) }
            )
            .frame(minWidth: 360, minHeight: 160)
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Button(action: { systemMapStore.closeCurrentSystemMap() }) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textSub)

                Button(action: { renameText = map.title; showingRenameSheet = true }) {
                    Text(map.title.uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.cyan)
                        .kerning(1)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { withAnimation { showingInspector.toggle() } }) {
                    Image(systemName: "sidebar.right").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(showingInspector ? AC.cyan : AC.textDim)
                .help("Toggle inspector")

                Button(action: exportJSON) {
                    Label("EXPORT JSON", systemImage: "square.and.arrow.up")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.5)))
            }
            if !map.primaryGoal.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered").font(.system(size: 9)).foregroundStyle(AC.gold)
                    Text("Goal: \(map.primaryGoal)").font(.system(size: 11)).foregroundStyle(AC.textSub).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AC.surface)
    }

    // MARK: - Actions

    private func moveElement(id: UUID, to position: SystemPoint) {
        guard var element = step.elements.first(where: { $0.id == id }) else { return }
        element.position = position
        systemMapStore.updateElement(element)
    }

    private func deleteSelection() {
        guard isEditable else { return }
        pushUndo()
        switch selection {
        case .element(let id): systemMapStore.deleteElement(id: id)
        case .flow(let id): systemMapStore.deleteFlow(id: id)
        case .relationship(let id): systemMapStore.deleteRelationship(id: id)
        case .none: break
        }
        selection = nil
    }

    private func pushUndo() {
        undoStack.append(DiagramSnapshot(elements: step.elements, flows: step.flows, relationships: step.relationships))
        redoStack.removeAll()
    }

    private func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(DiagramSnapshot(elements: step.elements, flows: step.flows, relationships: step.relationships))
        systemMapStore.replaceLatestStepDiagram(elements: last.elements, flows: last.flows, relationships: last.relationships)
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(DiagramSnapshot(elements: step.elements, flows: step.flows, relationships: step.relationships))
        systemMapStore.replaceLatestStepDiagram(elements: next.elements, flows: next.flows, relationships: next.relationships)
    }

    private func exportJSON() {
        guard let encoded = try? JSONCoding.encoder.encode(map) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(map.title)-system-map.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? encoded.write(to: url, options: [.atomic])
        }
    }
}

private struct RenameSystemMapSheet: View {
    @Binding var title: String
    @Binding var isPresented: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RENAME SYSTEM MAP").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
            TextField("Title", text: $title).arenaFieldStyle()
            HStack {
                Button("Cancel") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onSave(); isPresented = false }
                    .buttonStyle(ArenaButtonStyle(isDisabled: title.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .background(AC.bg)
        .colorScheme(.dark)
    }
}

// MARK: - Play card sheet

private struct PlayCardSheet: View {
    let card: KnowledgeCard
    let targetLabel: String
    let targetKind: SystemTargetKind
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var notes: String = ""

    private var softwareFields: SoftwareStrategyFields? {
        if case .softwareStrategy(let f) = card.metadata { return f }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PLAY CARD").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(card.kind.arenaColor).kerning(1.5)
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.title).font(.system(size: 16, weight: .bold)).foregroundStyle(AC.text)
                    HStack(spacing: 5) {
                        Image(systemName: "scope").font(.system(size: 9)).foregroundStyle(AC.cyan)
                        Text("Target: \(targetLabel) (\(targetKind.displayName))").font(.system(size: 11)).foregroundStyle(AC.cyan)
                    }
                    if let f = softwareFields {
                        if !f.trigger.isEmpty { detail("When", f.trigger, AC.cyan) }
                        if !f.mechanism.isEmpty { detail("Effect", f.mechanism, card.kind.arenaColor) }
                        if !f.desiredResult.isEmpty { detail("Result", f.desiredResult, AC.available) }
                        if !f.costs.isEmpty { detail("Costs", f.costs.joined(separator: "; "), AC.threat) }
                        if !f.failureModes.isEmpty { detail("Risks", f.failureModes.joined(separator: "; "), .orange) }
                    } else if !card.frontText.isEmpty {
                        detail("Description", card.frontText, card.kind.arenaColor)
                    }
                    if !card.playabilityRules.unlocksCardTitles.isEmpty {
                        detail("Unlocks", card.playabilityRules.unlocksCardTitles.joined(separator: ", "), AC.available)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTES (OPTIONAL)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                        TextField("What changed as a result?", text: $notes, axis: .vertical).arenaFieldStyle()
                    }
                }
                .padding(14)
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)
            HStack {
                Spacer()
                Button(action: { onConfirm(notes) }) {
                    Text(card.playabilityRules.exhaustsAfterUse ? "PLAY (WILL EXHAUST)" : "PLAY CARD")
                }
                .buttonStyle(ArenaButtonStyle(color: card.kind.arenaColor))
            }
            .padding(14)
            .background(AC.surface)
        }
        .background(AC.bg)
        .colorScheme(.dark)
    }

    private func detail(_ label: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(color.opacity(0.8)).kerning(1)
            Text(text).font(.system(size: 11)).foregroundStyle(AC.text)
        }
    }
}
