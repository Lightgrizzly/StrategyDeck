import SwiftUI
import StrategyDeckCore

/// Compact inspector for whatever is currently selected on the diagram —
/// an element (stock/delay/constraint/goal/note), a flow, or a relationship.
///
/// Clearly separates two kinds of edit: structural fields (name,
/// description, category — shared across every scenario) versus this
/// scenario's overrides (current value, state, notes — independent per
/// scenario). Editing one never touches the other.
struct SystemElementInspectorView: View {
    let elements: [SystemElement]
    let flows: [SystemFlow]
    let relationships: [SystemRelationship]
    let scenario: SystemScenario
    let selection: DiagramSelection?
    let onUpdateElement: (SystemElement) -> Void
    let onUpdateFlow: (SystemFlow) -> Void
    let onUpdateRelationship: (SystemRelationship) -> Void
    let onUpdateElementOverride: (UUID, SystemElementOverride) -> Void
    let onUpdateFlowOverride: (UUID, SystemFlowOverride) -> Void
    let relatedCardCount: (SystemTargetKind) -> Int

    var body: some View {
        ScrollView {
            content
                .padding(12)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .element(let id):
            if let element = elements.first(where: { $0.id == id }) {
                ElementInspectorBody(
                    element: element,
                    override: scenario.elementOverrides[id] ?? SystemElementOverride(),
                    scenarioName: scenario.name,
                    onUpdate: onUpdateElement,
                    onUpdateOverride: { onUpdateElementOverride(id, $0) }
                )
                HStack(spacing: 5) {
                    Image(systemName: "link").font(.system(size: 9)).foregroundStyle(AC.cyan)
                    let connected = connectedElementCount(forElementID: id)
                    Text("\(connected) connected element\(connected == 1 ? "" : "s")")
                        .font(.system(size: 9))
                        .foregroundStyle(AC.textDim)
                }
                .padding(.top, 4)
                relatedCardsFooter(SystemMapEvaluator.targetKind(for: element.kind))
            } else {
                emptyState
            }
        case .flow(let id):
            if let flow = flows.first(where: { $0.id == id }) {
                FlowInspectorBody(
                    flow: flow,
                    override: scenario.flowOverrides[id] ?? SystemFlowOverride(),
                    scenarioName: scenario.name,
                    onUpdate: onUpdateFlow,
                    onUpdateOverride: { onUpdateFlowOverride(id, $0) }
                )
                relatedCardsFooter(.flow)
            } else {
                emptyState
            }
        case .relationship(let id):
            if let rel = relationships.first(where: { $0.id == id }) {
                RelationshipInspectorBody(relationship: rel, onUpdate: onUpdateRelationship)
                relatedCardsFooter(.relationship)
            } else {
                emptyState
            }
        case .none:
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing selected")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AC.textSub)
            Text("Select a stock, flow, relationship, or other element to inspect it and see which cards can act on it. Selecting the background evaluates cards that target the entire system.")
                .font(.system(size: 10))
                .foregroundStyle(AC.textDim)
        }
    }

    private func relatedCardsFooter(_ kind: SystemTargetKind) -> some View {
        let count = relatedCardCount(kind)
        return HStack(spacing: 5) {
            Image(systemName: "checkmark.circle").font(.system(size: 9)).foregroundStyle(AC.available)
            Text("\(count) card\(count == 1 ? "" : "s") can target this")
                .font(.system(size: 9))
                .foregroundStyle(AC.textDim)
        }
        .padding(.top, 8)
    }

    /// Flows and relationships touching an element — the "N connected
    /// elements" line in the DETAILS tab. Pure count over data already
    /// passed to this view; no new model or store method.
    private func connectedElementCount(forElementID id: UUID) -> Int {
        let flowCount = flows.filter { $0.sourceElementID == id || $0.targetElementID == id }.count
        let relationshipCount = relationships.filter { $0.sourceElementID == id || $0.targetElementID == id }.count
        return flowCount + relationshipCount
    }
}

// MARK: - Shared field helpers

@ViewBuilder
private func inspectorField<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(label.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(AC.textDim)
            .kerning(0.5)
        content().arenaFieldStyle()
    }
}

private func sectionDivider(_ title: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        Rectangle().fill(AC.borderDim).frame(height: 1).padding(.vertical, 6)
        Text(title.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .kerning(1)
    }
}

// MARK: - Element body

private struct ElementInspectorBody: View {
    let element: SystemElement
    let override: SystemElementOverride
    let scenarioName: String
    let onUpdate: (SystemElement) -> Void
    let onUpdateOverride: (SystemElementOverride) -> Void

    @State private var localBase: SystemElement
    @State private var localOverride: SystemElementOverride

    init(
        element: SystemElement,
        override: SystemElementOverride,
        scenarioName: String,
        onUpdate: @escaping (SystemElement) -> Void,
        onUpdateOverride: @escaping (SystemElementOverride) -> Void
    ) {
        self.element = element
        self.override = override
        self.scenarioName = scenarioName
        self.onUpdate = onUpdate
        self.onUpdateOverride = onUpdateOverride
        _localBase = State(initialValue: element)
        _localOverride = State(initialValue: override)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: element.kind.systemImage).foregroundStyle(element.kind.arenaColor)
                Text(element.kind.displayName.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(element.kind.arenaColor)
                    .kerning(1)
            }

            sectionDivider("Structure — All Scenarios", color: AC.textDim)
            inspectorField("Name") { TextField("Name", text: $localBase.name) }
            inspectorField("Description") { TextField("Description", text: $localBase.description, axis: .vertical) }

            if element.kind == .stock {
                stockStructuralFields
            } else if element.kind == .delay {
                delayFields
            } else if element.kind == .goal {
                goalFields
            }

            inspectorField("Category") { TextField("Category", text: $localBase.category) }

            sectionDivider("This Scenario — \(scenarioName)", color: AC.cyan)
            Picker("State", selection: Binding(
                get: { localOverride.state ?? .normal },
                set: { localOverride.state = $0 == .normal ? nil : $0 }
            )) {
                ForEach(SystemElementState.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(AC.cyan)

            if element.kind == .stock {
                numberField("Current Value (this scenario)", Binding(
                    get: { localOverride.currentValue ?? localBase.currentValue },
                    set: { localOverride.currentValue = $0 }
                ))
            }
            inspectorField("Notes (this scenario)") {
                TextField("Notes specific to this scenario", text: Binding(
                    get: { localOverride.notes ?? localBase.notes },
                    set: { localOverride.notes = $0 }
                ), axis: .vertical)
            }
        }
        .onChange(of: localBase) { _, new in onUpdate(new) }
        .onChange(of: localOverride) { _, new in onUpdateOverride(new) }
        .onChange(of: element.id) { _, _ in localBase = element; localOverride = override }
    }

    private var stockStructuralFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                numberField("Desired", $localBase.desiredValue)
                numberField("Min", $localBase.minimumValue)
            }
            HStack(spacing: 6) {
                numberField("Max", $localBase.maximumValue)
                inspectorField("Unit") { TextField("e.g. units, $, %", text: $localBase.unit) }
            }
        }
    }

    private var delayFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspectorField("Duration") { TextField("e.g. 3 weeks", text: $localBase.delayDurationLabel) }
            Toggle("Pending", isOn: $localBase.delayIsPending).tint(AC.cyan).font(.system(size: 11))
            inspectorField("Completion condition") { TextField("What ends the delay", text: $localBase.delayCompletionCondition, axis: .vertical) }
        }
    }

    private var goalFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Primary goal", isOn: $localBase.isPrimaryGoal).tint(AC.gold).font(.system(size: 11))
            inspectorField("Success criteria") { TextField("What success looks like", text: $localBase.successCriteria, axis: .vertical) }
            inspectorField("Failure condition") { TextField("What failure looks like", text: $localBase.failureCondition, axis: .vertical) }
        }
    }

    private func numberField(_ label: String, _ binding: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
            TextField("—", text: Binding(
                get: { binding.wrappedValue.map { String(format: $0.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", $0) } ?? "" },
                set: { binding.wrappedValue = Double($0) }
            ))
            .arenaFieldStyle()
        }
    }
}

// MARK: - Flow body

private struct FlowInspectorBody: View {
    let flow: SystemFlow
    let override: SystemFlowOverride
    let scenarioName: String
    let onUpdate: (SystemFlow) -> Void
    let onUpdateOverride: (SystemFlowOverride) -> Void

    @State private var localBase: SystemFlow
    @State private var localOverride: SystemFlowOverride

    init(
        flow: SystemFlow,
        override: SystemFlowOverride,
        scenarioName: String,
        onUpdate: @escaping (SystemFlow) -> Void,
        onUpdateOverride: @escaping (SystemFlowOverride) -> Void
    ) {
        self.flow = flow
        self.override = override
        self.scenarioName = scenarioName
        self.onUpdate = onUpdate
        self.onUpdateOverride = onUpdateOverride
        _localBase = State(initialValue: flow)
        _localOverride = State(initialValue: override)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.right").foregroundStyle(AC.cyan)
                Text("FLOW").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
            }

            sectionDivider("Structure — All Scenarios", color: AC.textDim)
            inspectorField("Name") { TextField("Name", text: $localBase.name) }
            inspectorField("Description") { TextField("Description", text: $localBase.description, axis: .vertical) }
            Picker("Direction", selection: $localBase.direction) {
                ForEach(FlowDirection.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            inspectorField("Delay") { TextField("e.g. 2 weeks", text: $localBase.delayLabel) }

            sectionDivider("This Scenario — \(scenarioName)", color: AC.cyan)
            Picker("State", selection: Binding(
                get: { localOverride.state ?? .normal },
                set: { localOverride.state = $0 == .normal ? nil : $0 }
            )) {
                ForEach(SystemElementState.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(AC.cyan)
            Toggle("Enabled (this scenario)", isOn: Binding(
                get: { localOverride.isEnabled ?? localBase.isEnabled },
                set: { localOverride.isEnabled = $0 }
            ))
            .tint(AC.cyan)
            .font(.system(size: 11))
            rateField
        }
        .onChange(of: localBase) { _, new in onUpdate(new) }
        .onChange(of: localOverride) { _, new in onUpdateOverride(new) }
        .onChange(of: flow.id) { _, _ in localBase = flow; localOverride = override }
    }

    private var rateField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RATE (THIS SCENARIO)")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
            TextField("—", text: Binding(
                get: {
                    let value = localOverride.rate ?? localBase.rate
                    return value.map { $0.truncatingRemainder(dividingBy: 1) == 0 ? String(Int($0)) : String(format: "%.2f", $0) } ?? ""
                },
                set: { localOverride.rate = Double($0) }
            ))
            .arenaFieldStyle()
        }
    }
}

// MARK: - Relationship body
//
// Relationships are shared workflow structure (no scenario override in this
// version — the spec calls scenario-specific relationship state "optional
// for now" and structure lightweight relationshipStates are exposed at the
// map level for a future pass).

private struct RelationshipInspectorBody: View {
    let relationship: SystemRelationship
    let onUpdate: (SystemRelationship) -> Void

    @State private var local: SystemRelationship

    init(relationship: SystemRelationship, onUpdate: @escaping (SystemRelationship) -> Void) {
        self.relationship = relationship
        self.onUpdate = onUpdate
        _local = State(initialValue: relationship)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "link").foregroundStyle(relationship.relationshipType.arenaColor)
                Text("RELATIONSHIP").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(relationship.relationshipType.arenaColor).kerning(1)
            }
            Picker("Type", selection: $local.relationshipType) {
                ForEach(RelationshipType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(AC.cyan)
            Picker("Polarity", selection: $local.polarity) {
                ForEach(RelationshipPolarity.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            inspectorField("Label") { TextField("Optional label", text: $local.label) }
            inspectorField("Delay") { TextField("e.g. 1 week", text: $local.delayLabel) }
        }
        .onChange(of: local) { _, new in onUpdate(new) }
        .onChange(of: relationship.id) { _, _ in local = relationship }
    }
}
