import SwiftUI
import StrategyDeckCore

/// Compact inspector for whatever is currently selected on the diagram —
/// an element (stock/delay/constraint/goal/note), a flow, or a relationship.
/// Editable fields write straight back through the provided closures.
struct SystemElementInspectorView: View {
    let step: SystemStep
    let selection: DiagramSelection?
    let onUpdateElement: (SystemElement) -> Void
    let onUpdateFlow: (SystemFlow) -> Void
    let onUpdateRelationship: (SystemRelationship) -> Void
    let relatedCardCount: (SystemTargetKind) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArenaSectionLabel(text: "Inspector", icon: "sidebar.right")
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            ScrollView {
                content
                    .padding(12)
            }
        }
        .frame(width: 220)
        .background(AC.glassPanel)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .element(let id):
            if let element = step.elements.first(where: { $0.id == id }) {
                ElementInspectorBody(element: element, onUpdate: onUpdateElement)
                relatedCardsFooter(SystemMapEvaluator.targetKind(for: element.kind))
            } else {
                emptyState
            }
        case .flow(let id):
            if let flow = step.flows.first(where: { $0.id == id }) {
                FlowInspectorBody(flow: flow, onUpdate: onUpdateFlow)
                relatedCardsFooter(.flow)
            } else {
                emptyState
            }
        case .relationship(let id):
            if let rel = step.relationships.first(where: { $0.id == id }) {
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
            Text("Select a stock, flow, relationship, or other element to inspect it and see which cards can act on it.")
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
}

// MARK: - Element body

private struct ElementInspectorBody: View {
    let element: SystemElement
    let onUpdate: (SystemElement) -> Void

    @State private var local: SystemElement

    init(element: SystemElement, onUpdate: @escaping (SystemElement) -> Void) {
        self.element = element
        self.onUpdate = onUpdate
        _local = State(initialValue: element)
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
            field("Name") { TextField("Name", text: $local.name) }
            field("Description") { TextField("Description", text: $local.description, axis: .vertical) }

            if element.kind == .stock {
                stockFields
            } else if element.kind == .delay {
                delayFields
            } else if element.kind == .goal {
                goalFields
            }

            field("Category") { TextField("Category", text: $local.category) }
            field("Notes") { TextField("Notes", text: $local.notes, axis: .vertical) }
        }
        .onChange(of: local) { _, new in onUpdate(new) }
        .onChange(of: element.id) { _, _ in local = element }
    }

    private var stockFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                numberField("Current", $local.currentValue)
                numberField("Desired", $local.desiredValue)
            }
            HStack(spacing: 6) {
                numberField("Min", $local.minimumValue)
                numberField("Max", $local.maximumValue)
            }
            field("Unit") { TextField("e.g. units, $, %", text: $local.unit) }
        }
    }

    private var delayFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            field("Duration") { TextField("e.g. 3 steps", text: $local.delayDurationLabel) }
            Toggle("Pending", isOn: $local.delayIsPending).tint(AC.cyan).font(.system(size: 11))
            field("Completion condition") { TextField("What ends the delay", text: $local.delayCompletionCondition, axis: .vertical) }
        }
    }

    private var goalFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Primary goal", isOn: $local.isPrimaryGoal).tint(AC.gold).font(.system(size: 11))
            field("Success criteria") { TextField("What success looks like", text: $local.successCriteria, axis: .vertical) }
            field("Failure condition") { TextField("What failure looks like", text: $local.failureCondition, axis: .vertical) }
        }
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
                .kerning(0.5)
            content().arenaFieldStyle()
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
    let onUpdate: (SystemFlow) -> Void

    @State private var local: SystemFlow

    init(flow: SystemFlow, onUpdate: @escaping (SystemFlow) -> Void) {
        self.flow = flow
        self.onUpdate = onUpdate
        _local = State(initialValue: flow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.right").foregroundStyle(AC.cyan)
                Text("FLOW").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
            }
            field("Name") { TextField("Name", text: $local.name) }
            field("Description") { TextField("Description", text: $local.description, axis: .vertical) }
            Picker("Direction", selection: $local.direction) {
                ForEach(FlowDirection.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Enabled", isOn: $local.isEnabled).tint(AC.cyan).font(.system(size: 11))
            field("Delay") { TextField("e.g. 2 steps", text: $local.delayLabel) }
        }
        .onChange(of: local) { _, new in onUpdate(new) }
        .onChange(of: flow.id) { _, _ in local = flow }
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim)
            content().arenaFieldStyle()
        }
    }
}

// MARK: - Relationship body

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
            field("Label") { TextField("Optional label", text: $local.label) }
            field("Delay") { TextField("e.g. 1 step", text: $local.delayLabel) }
        }
        .onChange(of: local) { _, new in onUpdate(new) }
        .onChange(of: relationship.id) { _, _ in local = relationship }
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim)
            content().arenaFieldStyle()
        }
    }
}
