import SwiftUI
import StrategyDeckCore

// MARK: - Diagram toolbar

struct SystemDiagramToolbar: View {
    @Binding var tool: DiagramTool
    let isEditable: Bool
    let hasSelection: Bool
    let canUndo: Bool
    let canRedo: Bool
    let onDelete: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFit: () -> Void
    let onCenterSelection: () -> Void

    private let addTools: [DiagramTool] = [.addStock, .addDelay, .addConstraint, .addGoal, .addNote, .addFlow, .addRelationship]

    var body: some View {
        HStack(spacing: 6) {
            toolButton(.select)
            Rectangle().fill(AC.borderDim).frame(width: 1, height: 16)
            ForEach(addTools, id: \.self) { toolButton($0) }
            Rectangle().fill(AC.borderDim).frame(width: 1, height: 16)

            iconButton("trash", help: "Delete selected", enabled: hasSelection, action: onDelete)
            iconButton("arrow.uturn.backward", help: "Undo", enabled: canUndo, action: onUndo)
            iconButton("arrow.uturn.forward", help: "Redo", enabled: canRedo, action: onRedo)

            Spacer()

            iconButton("minus.magnifyingglass", help: "Zoom out", enabled: true, action: onZoomOut)
            iconButton("plus.magnifyingglass", help: "Zoom in", enabled: true, action: onZoomIn)
            iconButton("arrow.up.left.and.down.right.magnifyingglass", help: "Fit diagram", enabled: true, action: onFit)
            iconButton("scope", help: "Center selection", enabled: hasSelection, action: onCenterSelection)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AC.surface)
        .opacity(isEditable ? 1 : 0.5)
        .disabled(!isEditable)
    }

    @ViewBuilder
    private func toolButton(_ t: DiagramTool) -> some View {
        Button(action: { tool = t }) {
            Image(systemName: t.systemImage)
                .font(.system(size: 12))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tool == t ? AC.bg : AC.textSub)
        .background(
            Circle().fill(tool == t ? AC.cyan : Color.clear)
        )
        .help(t.label)
    }

    @ViewBuilder
    private func iconButton(_ systemImage: String, help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 12)).frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? AC.textSub : AC.textGhost)
        .disabled(!enabled)
        .help(help)
    }
}

// MARK: - Canvas
//
// Renders the *effective* diagram for the selected scenario (base structure
// merged with that scenario's value overrides) — the caller resolves
// `SystemMap.effectiveElements(for:)`/`effectiveFlows(for:)` and passes the
// result down, so this view has no scenario concept of its own.

struct SystemDiagramCanvasView: View {
    let elements: [SystemElement]
    let flows: [SystemFlow]
    let relationships: [SystemRelationship]
    /// Per-element/flow semantic state tag for the selected scenario, used
    /// only for visual dimming/badging (hidden/disabled/at-risk etc).
    let elementStates: [UUID: SystemElementState]
    /// Count of cards currently Active specifically on each element (via a
    /// `.thisElementOnly` override) — a compact "what's attached here"
    /// indicator. Selecting the element already reveals which cards via the
    /// card library below, so this is display-only.
    let elementActiveCardCounts: [UUID: Int]
    /// Total active issues/blockers/risks affecting each element, and how
    /// many of those are critical or blocker-type — a compact "what's
    /// wrong here" indicator. Full detail lives in the Issues panel.
    var elementIssueCounts: [UUID: Int] = [:]
    var elementCriticalBlockerCounts: [UUID: Int] = [:]
    let isEditable: Bool
    @Binding var selection: DiagramSelection?
    @Binding var tool: DiagramTool
    @Binding var pendingConnectSourceID: UUID?
    let onAddElement: (SystemElement) -> Void
    let onMoveElement: (UUID, SystemPoint) -> Void
    let onAddFlow: (SystemFlow) -> Void
    let onAddRelationship: (SystemRelationship) -> Void
    /// A card was dropped onto this target (`nil` = background / entire
    /// system). Dropping never changes state by itself — the caller decides
    /// what to do based on the card's effective status for this target.
    let onDropCard: (UUID, DiagramSelection?) -> Void
    var onDropIssue: (UUID, DiagramSelection?) -> Void = { _, _ in }

    @State private var panOffset: CGSize = .zero
    @State private var zoom: CGFloat = 1.0
    @State private var draggingElementID: UUID?
    @State private var dragTranslation: CGSize = .zero
    @State private var dropTargetedSelection: DiagramSelection?
    @State private var isBackgroundDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func cardID(from items: [String]) -> UUID? {
        items.first.flatMap { UUID(uuidString: $0) }
    }

    private func issueID(from items: [String]) -> UUID? {
        items.first.flatMap { IssueDragPayload.decode($0) }
    }

    private var positionsByID: [UUID: CGPoint] {
        Dictionary(uniqueKeysWithValues: elements.map { ($0.id, CGPoint(x: $0.position.x, y: $0.position.y)) })
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DigitalArenaBackground(reduceEffects: reduceMotion)
                diagramLayer(in: geo.size)
                if tool != .select {
                    toolHintBanner
                }
            }
            .clipped()
        }
    }

    private func diagramLayer(in size: CGSize) -> some View {
        ZStack {
            edgeLinesLayer
            flowLabelsLayer
            relationshipLabelsLayer
            elementNodesLayer
        }
        .scaleEffect(zoom)
        .offset(panOffset)
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(backgroundTapGesture(in: size))
        .gesture(isEditable ? panGesture : nil)
        .gesture(MagnificationGesture().onChanged { value in
            zoom = min(max(0.4, value), 2.5)
        })
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .fill(isBackgroundDropTargeted ? AC.cyanSoft.opacity(0.15) : Color.clear)
                .allowsHitTesting(false)
        )
        .dropDestination(for: String.self, action: { items, _ in
            if let cardID = cardID(from: items) { onDropCard(cardID, nil); return true }
            if let issueID = issueID(from: items) { onDropIssue(issueID, nil); return true }
            return false
        }, isTargeted: { isBackgroundDropTargeted = $0 })
    }

    private var flowLabelsLayer: some View {
        ForEach(flows) { flow in
            if let (from, to) = endpoints(for: flow) {
                EdgeLabelView(
                    label: flow.name,
                    color: AC.cyan,
                    isSelected: selection == .flow(flow.id),
                    isEnabled: flow.isEnabled,
                    isDropTargeted: dropTargetedSelection == .flow(flow.id)
                )
                .position(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
                .onTapGesture { selection = .flow(flow.id) }
                .dropDestination(for: String.self, action: { items, _ in
                    if let cardID = cardID(from: items) { onDropCard(cardID, .flow(flow.id)); return true }
                    if let issueID = issueID(from: items) { onDropIssue(issueID, .flow(flow.id)); return true }
                    return false
                }, isTargeted: { targeted in
                    dropTargetedSelection = targeted ? .flow(flow.id) : (dropTargetedSelection == .flow(flow.id) ? nil : dropTargetedSelection)
                })
            }
        }
    }

    private var relationshipLabelsLayer: some View {
        ForEach(relationships) { rel in
            if let s = positionsByID[rel.sourceElementID], let t = positionsByID[rel.targetElementID] {
                EdgeLabelView(
                    label: rel.relationshipType.marker,
                    color: rel.relationshipType.arenaColor,
                    isSelected: selection == .relationship(rel.id),
                    isEnabled: true,
                    isDropTargeted: dropTargetedSelection == .relationship(rel.id)
                )
                .position(x: (s.x + t.x) / 2, y: (s.y + t.y) / 2 - 16)
                .onTapGesture { selection = .relationship(rel.id) }
                .dropDestination(for: String.self, action: { items, _ in
                    if let cardID = cardID(from: items) { onDropCard(cardID, .relationship(rel.id)); return true }
                    if let issueID = issueID(from: items) { onDropIssue(issueID, .relationship(rel.id)); return true }
                    return false
                }, isTargeted: { targeted in
                    dropTargetedSelection = targeted ? .relationship(rel.id) : (dropTargetedSelection == .relationship(rel.id) ? nil : dropTargetedSelection)
                })
            }
        }
    }

    private var elementNodesLayer: some View {
        ForEach(elements) { element in
            SystemElementNodeView(
                element: element,
                state: elementStates[element.id] ?? .normal,
                isSelected: selection == .element(element.id),
                isConnectSource: pendingConnectSourceID == element.id,
                isDropTargeted: dropTargetedSelection == .element(element.id),
                activeCardCount: elementActiveCardCounts[element.id] ?? 0,
                issueCount: elementIssueCounts[element.id] ?? 0,
                criticalBlockerCount: elementCriticalBlockerCounts[element.id] ?? 0
            )
            .position(
                x: element.position.x + (draggingElementID == element.id ? dragTranslation.width : 0),
                y: element.position.y + (draggingElementID == element.id ? dragTranslation.height : 0)
            )
            .gesture(isEditable ? nodeDragGesture(for: element) : nil)
            .onTapGesture { handleTap(elementID: element.id) }
            .highPriorityGesture(TapGesture().onEnded { handleTap(elementID: element.id) })
            .dropDestination(for: String.self, action: { items, _ in
                if let cardID = cardID(from: items) { onDropCard(cardID, .element(element.id)); return true }
                if let issueID = issueID(from: items) { onDropIssue(issueID, .element(element.id)); return true }
                return false
            }, isTargeted: { targeted in
                dropTargetedSelection = targeted ? .element(element.id) : (dropTargetedSelection == .element(element.id) ? nil : dropTargetedSelection)
            })
        }
    }

    // MARK: Edges
    //
    // Lines/arrowheads are drawn on a non-interactive Canvas (cheap, no hit
    // testing needed); the tappable label pill for each edge is a real
    // SwiftUI view layered on top so flows and relationships can actually
    // be selected — Canvas content alone can never receive taps.

    /// Resolves a flow's endpoints, synthesizing a short stub point for the
    /// "outside the system" end of an inflow/outflow so those still render
    /// as a visible arrow rather than being silently skipped.
    private func endpoints(for flow: SystemFlow) -> (CGPoint, CGPoint)? {
        let source = flow.sourceElementID.flatMap { positionsByID[$0] }
        let target = flow.targetElementID.flatMap { positionsByID[$0] }
        switch (source, target) {
        case (let s?, let t?): return (s, t)
        case (nil, let t?): return (CGPoint(x: t.x - 90, y: t.y - 70), t)
        case (let s?, nil): return (s, CGPoint(x: s.x + 90, y: s.y + 70))
        default: return nil
        }
    }

    private var edgeLinesLayer: some View {
        Canvas { ctx, _ in
            for flow in flows {
                guard let (s, t) = endpoints(for: flow) else { continue }
                drawLine(from: s, to: t, ctx: &ctx, color: AC.cyan, dashed: !flow.isEnabled)
            }
            for rel in relationships {
                guard let s = positionsByID[rel.sourceElementID], let t = positionsByID[rel.targetElementID] else { continue }
                drawLine(from: s, to: t, ctx: &ctx, color: rel.relationshipType.arenaColor, dashed: true)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawLine(from: CGPoint, to: CGPoint, ctx: inout GraphicsContext, color: Color, dashed: Bool) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        ctx.stroke(path, with: .color(color.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [5, 4] : []))

        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 9
        let p1 = CGPoint(x: to.x - arrowLength * cos(angle - .pi / 6), y: to.y - arrowLength * sin(angle - .pi / 6))
        let p2 = CGPoint(x: to.x - arrowLength * cos(angle + .pi / 6), y: to.y - arrowLength * sin(angle + .pi / 6))
        var arrow = Path()
        arrow.move(to: to); arrow.addLine(to: p1)
        arrow.move(to: to); arrow.addLine(to: p2)
        ctx.stroke(arrow, with: .color(color), lineWidth: 1.75)
    }

    // MARK: Gestures

    private func nodeDragGesture(for element: SystemElement) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                draggingElementID = element.id
                dragTranslation = CGSize(width: value.translation.width / zoom, height: value.translation.height / zoom)
            }
            .onEnded { value in
                let translation = CGSize(width: value.translation.width / zoom, height: value.translation.height / zoom)
                let newPosition = SystemPoint(x: element.position.x + translation.width, y: element.position.y + translation.height)
                draggingElementID = nil
                dragTranslation = .zero
                onMoveElement(element.id, newPosition)
            }
    }

    private var panGesture: some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                guard draggingElementID == nil else { return }
                panOffset = value.translation
            }
    }

    private func backgroundTapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                if tool.isAddElementTool, let kind = tool.elementKind, isEditable {
                    let canvasPoint = CGPoint(
                        x: (value.location.x - panOffset.width) / zoom,
                        y: (value.location.y - panOffset.height) / zoom
                    )
                    let newElement = SystemElement(
                        kind: kind,
                        name: "New \(kind.displayName)",
                        position: SystemPoint(x: canvasPoint.x, y: canvasPoint.y),
                        size: SystemSize(width: kind == .stock ? 130 : 110, height: kind == .stock ? 84 : 60)
                    )
                    onAddElement(newElement)
                    selection = .element(newElement.id)
                    tool = .select
                } else {
                    selection = nil
                    pendingConnectSourceID = nil
                }
            }
    }

    private func handleTap(elementID: UUID) {
        guard isEditable, tool == .addFlow || tool == .addRelationship else {
            selection = .element(elementID)
            return
        }
        if let sourceID = pendingConnectSourceID {
            guard sourceID != elementID else { return }
            if tool == .addFlow {
                onAddFlow(SystemFlow(name: "New Flow", sourceElementID: sourceID, targetElementID: elementID, direction: .transfer))
            } else {
                onAddRelationship(SystemRelationship(sourceElementID: sourceID, targetElementID: elementID, relationshipType: .increases))
            }
            pendingConnectSourceID = nil
            tool = .select
        } else {
            pendingConnectSourceID = elementID
        }
    }

    private var toolHintBanner: some View {
        VStack {
            HStack {
                Spacer()
                Text(hintText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AC.bg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AngularCardShape(cornerRadius: 4, cornerCut: 8).fill(AC.gold))
                Spacer()
            }
            .padding(.top, 8)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var hintText: String {
        switch tool {
        case .addFlow, .addRelationship:
            return pendingConnectSourceID == nil ? "TAP A SOURCE ELEMENT" : "TAP A TARGET ELEMENT"
        default:
            return "TAP THE CANVAS TO PLACE — \(tool.label.uppercased())"
        }
    }
}

// MARK: - Element node rendering

struct SystemElementNodeView: View {
    let element: SystemElement
    let state: SystemElementState
    let isSelected: Bool
    let isConnectSource: Bool
    var isDropTargeted: Bool = false
    var activeCardCount: Int = 0
    var issueCount: Int = 0
    var criticalBlockerCount: Int = 0

    private var color: Color { element.kind.arenaColor }
    private var isDimmed: Bool { state == .hidden || state == .disabled }

    var body: some View {
        Group {
            if element.kind == .stock {
                stockBody
            } else {
                badgeBody
            }
        }
        .frame(width: element.size.width, height: element.size.height)
        .overlay(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .stroke(isDropTargeted ? AC.gold : (isConnectSource ? AC.gold : (isSelected ? color : AC.borderDim)), lineWidth: isDropTargeted ? 2.5 : (isSelected || isConnectSource ? 2 : 1))
        )
        .overlay(alignment: .topTrailing) {
            if state != .normal {
                stateBadge
            }
        }
        .overlay(alignment: .topLeading) {
            if activeCardCount > 0 {
                activeCardBadge
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if issueCount > 0 {
                issueBadge
            }
        }
        .shadow(color: isDropTargeted ? AC.gold.opacity(0.8) : (isSelected ? color.opacity(0.6) : .clear), radius: isDropTargeted ? 12 : 8)
        .shadow(color: criticalBlockerCount > 0 ? AC.threat.opacity(0.5) : .clear, radius: 8)
        .opacity(isDimmed ? 0.5 : 1)
        .scaleEffect(isDropTargeted ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }

    private var activeCardBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "bolt.fill").font(.system(size: 6))
            Text("\(activeCardCount)").font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(AC.bg)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(Capsule().fill(AC.cyan))
        .shadow(color: AC.cyanGlow, radius: 3)
        .offset(x: -4, y: -4)
        .help("\(activeCardCount) card\(activeCardCount == 1 ? "" : "s") active on this element")
    }

    private var issueBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: criticalBlockerCount > 0 ? "hand.raised.fill" : "exclamationmark.triangle.fill").font(.system(size: 6))
            Text("\(issueCount)").font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(AC.bg)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(Capsule().fill(criticalBlockerCount > 0 ? AC.threat : .orange))
        .shadow(color: criticalBlockerCount > 0 ? AC.threat.opacity(0.8) : .orange.opacity(0.5), radius: 3)
        .offset(x: 4, y: 4)
        .help("\(issueCount) issue\(issueCount == 1 ? "" : "s") affecting this element\(criticalBlockerCount > 0 ? ", \(criticalBlockerCount) critical/blocker" : "")")
    }

    private var stateBadge: some View {
        Text(state.displayName.uppercased())
            .font(.system(size: 6, weight: .black, design: .monospaced))
            .foregroundStyle(AC.bg)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Capsule().fill(state.arenaColor))
            .offset(x: 4, y: -4)
    }

    private var stockBody: some View {
        ZStack(alignment: .bottom) {
            AngularCardShape(cornerRadius: 8, cornerCut: 12).fill(AC.surface)
            if let current = element.currentValue, let maxValue = element.maximumValue, maxValue > 0 {
                let ratio = Swift.min(Swift.max(current / maxValue, 0), 1)
                AngularCardShape(cornerRadius: 8, cornerCut: 12)
                    .fill(color.opacity(0.28))
                    .frame(height: element.size.height * ratio)
            }
            VStack(spacing: 3) {
                Image(systemName: element.kind.systemImage).font(.system(size: 11)).foregroundStyle(color)
                Text(element.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AC.text)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                if let current = element.currentValue {
                    Text(formatted(current) + (element.unit.isEmpty ? "" : " \(element.unit)"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(color)
                }
            }
            .padding(6)
        }
    }

    private var badgeBody: some View {
        ZStack {
            AngularCardShape(cornerRadius: 8, cornerCut: 12).fill(AC.surface)
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: element.kind.systemImage).font(.system(size: 10)).foregroundStyle(color)
                    if element.isPrimaryGoal {
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(AC.gold)
                    }
                }
                Text(element.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AC.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            .padding(6)
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Edge label (the tappable pill layered over a drawn line)

private struct EdgeLabelView: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let isEnabled: Bool
    var isDropTargeted: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(isSelected ? AC.bg : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Circle().fill(isSelected ? color : AC.bg.opacity(0.85))
            )
            .overlay(Circle().stroke(isDropTargeted ? AC.gold : color.opacity(isEnabled ? 0.8 : 0.3), lineWidth: isDropTargeted ? 2.5 : 1))
            .shadow(color: isDropTargeted ? AC.gold.opacity(0.8) : .clear, radius: 8)
            .scaleEffect(isDropTargeted ? 1.25 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isDropTargeted)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Circle())
    }
}
