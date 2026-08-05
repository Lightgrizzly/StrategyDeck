import SwiftUI
import StrategyDeckCore

// MARK: - Board view mode

enum DuelBoardViewMode: String, CaseIterable {
    case board = "Board"
    case comic = "Comic"

    var systemImage: String {
        switch self {
        case .board: return "rectangle.3.group"
        case .comic: return "rectangle.stack"
        }
    }
}

// MARK: - Layout constants

private enum BL {
    static let opponentCardSize  = CGSize(width: 78,  height: 94)
    static let fieldCardSize     = CGSize(width: 88,  height: 108)
    static let handCardSize      = CGSize(width: 90,  height: 116)
    static let handNegativeGap: CGFloat = 22
}

// MARK: - Card kind SF symbol mapping (UI-only extension)

private extension CardKind {
    var boardSFSymbol: String {
        switch self {
        case .action:      return "bolt.fill"
        case .condition:   return "exclamationmark.circle.fill"
        case .principle:   return "star.fill"
        case .observation: return "eye.fill"
        case .entity:      return "person.fill"
        case .relation:    return "arrow.left.and.right"
        case .modifier:    return "slider.horizontal.3"
        case .chunk:       return "rectangle.stack.fill"
        case .strategy:    return "map.fill"
        }
    }
}

// MARK: - Main board view

struct StrategyDuelBoardView: View {
    @EnvironmentObject var cardStore: CardStore

    let duel: Duel
    let panel: DuelPanel
    let previousPanel: DuelPanel?
    let onUpdate: (DuelPanel) -> Void
    let onAddSnapshot: (UUID, DuelZone) -> Void
    let onDeleteSnapshot: (UUID) -> Void
    let onUpdateSnapshot: (DuelCardSnapshot) -> Void
    let onShowPicker: (DuelZone) -> Void
    let onAddStep: () -> Void

    @State private var selectedID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.25, dampingFraction: 0.85)
    }

    // MARK: Lookups

    private var cardsByID: [UUID: KnowledgeCard] {
        Dictionary(uniqueKeysWithValues: cardStore.cards.map { ($0.id, $0) })
    }
    private var suitsByID: [String: CardSuit] {
        Dictionary(uniqueKeysWithValues: cardStore.suits.map { ($0.id, $0) })
    }

    // MARK: Zone partitions

    private func snaps(_ zone: DuelZone) -> [DuelCardSnapshot] {
        panel.snapshots.filter { $0.zone == zone }.sorted { $0.order < $1.order }
    }

    private var playerHandSnaps: [DuelCardSnapshot] {
        snaps(.player).filter {
            $0.strategicZone == .hand || $0.strategicZone == .locked || $0.strategicZone == .deck
        }
    }
    private var playerFieldSnaps: [DuelCardSnapshot] {
        snaps(.player).filter {
            $0.strategicZone == .field
        }
    }
    private var playerUsedSnaps: [DuelCardSnapshot] {
        snaps(.player).filter {
            $0.strategicZone == .exhausted || $0.strategicZone == .resolved || $0.strategicZone == .discarded
        }
    }

    private var playabilityContext: PlayabilityContext {
        PlayabilityEvaluator.context(from: panel, duel: duel, cardsByID: cardsByID)
    }

    // MARK: Selection

    private func select(_ id: UUID) {
        withAnimation(animation) {
            selectedID = (selectedID == id) ? nil : id
        }
    }

    private func deselect() {
        withAnimation(animation) { selectedID = nil }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Board background
                LinearGradient(
                    stops: [
                        .init(color: Color.blue.opacity(0.06), location: 0),
                        .init(color: Color(.windowBackgroundColor), location: 0.38),
                        .init(color: Color(.windowBackgroundColor), location: 0.62),
                        .init(color: Color.accentColor.opacity(0.06), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Main layout
                VStack(spacing: 0) {
                    // Opponent identity strip
                    OpponentHeaderBar(duel: duel, panel: panel)
                        .frame(height: 34)

                    // Opponent zone
                    BoardOpponentArea(
                        snapshots: snaps(.opponent),
                        cardsByID: cardsByID,
                        suitsByID: suitsByID,
                        selectedID: selectedID,
                        onSelect: select,
                        onAdd: { onShowPicker(.opponent) }
                    )
                    .frame(height: max(120, geo.size.height * 0.24))

                    BoardZoneDivider(
                        label: "SHARED SITUATION",
                        trailingLabel: duel.victoryCondition.isEmpty ? "" : "★ \(duel.victoryCondition)"
                    )

                    // Shared battlefield
                    BoardSharedArea(
                        duel: duel,
                        snapshots: snaps(.battlefield),
                        cardsByID: cardsByID,
                        suitsByID: suitsByID,
                        selectedID: selectedID,
                        onSelect: select,
                        onAdd: { onShowPicker(.battlefield) }
                    )
                    .frame(height: max(80, geo.size.height * 0.14))

                    BoardZoneDivider(label: "STRATEGY FIELD", trailingLabel: "")

                    // Player active field
                    BoardPlayerArea(
                        fieldSnaps: playerFieldSnaps,
                        usedSnaps: playerUsedSnaps,
                        cardsByID: cardsByID,
                        suitsByID: suitsByID,
                        selectedID: selectedID,
                        onSelect: select,
                        onAdd: { onShowPicker(.player) }
                    )
                    .frame(height: max(120, geo.size.height * 0.20))

                    // Turn controls
                    BoardTurnBar(
                        panel: panel,
                        totalSteps: duel.sortedPanels.count,
                        onAddStep: onAddStep
                    )
                    .frame(height: 38)

                    // Strategy hand
                    let handHeight: CGFloat = max(130, geo.size.height * 0.20)
                    StrategyHandRow(
                        snapshots: playerHandSnaps,
                        cardsByID: cardsByID,
                        suitsByID: suitsByID,
                        context: playabilityContext,
                        selectedID: selectedID,
                        onSelect: select,
                        onAdd: { onShowPicker(.player) }
                    )
                    .frame(height: handHeight)
                }

                // Card inspector overlay
                if let id = selectedID,
                   let snap = panel.snapshots.first(where: { $0.id == id }),
                   let card = cardsByID[snap.cardID] {
                    let handHeight: CGFloat = max(130, geo.size.height * 0.20)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            CardInspectorPanel(
                                snapshot: snap,
                                card: card,
                                suite: suitsByID[card.suitIDs.first ?? ""],
                                result: PlayabilityEvaluator.evaluate(card: card, context: playabilityContext),
                                onClose: deselect,
                                onUpdate: onUpdateSnapshot,
                                onDelete: {
                                    onDeleteSnapshot(snap.id)
                                    deselect()
                                },
                                onMoveToField: {
                                    var s = snap
                                    s.strategicZone = .field
                                    s.status = .active
                                    s.isManuallyOverridden = true
                                    onUpdateSnapshot(s)
                                    deselect()
                                }
                            )
                            .frame(width: min(geo.size.width - 32, 380))
                            Spacer()
                        }
                        .padding(.bottom, handHeight + 46)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(animation, value: selectedID)
                }
            }
        }
        // Keyboard: Escape to deselect
        .onKeyPress(.escape) {
            if selectedID != nil { deselect(); return .handled }
            return .ignored
        }
    }
}

// MARK: - Opponent header bar

private struct OpponentHeaderBar: View {
    let duel: Duel
    let panel: DuelPanel

    private var opponentLabel: String {
        let d = duel.description.trimmingCharacters(in: .whitespaces)
        return (d.isEmpty || d.count > 30) ? "The System" : d
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red.opacity(0.75))
                    .frame(width: 7, height: 7)
                Text(opponentLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .kerning(1.5)
            }
            if !panel.opponentCaption.isEmpty {
                Text("· \(panel.opponentCaption)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("STEP \(panel.order + 1)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1)
        }
        .padding(.horizontal, 14)
        .background(Color(.windowBackgroundColor).opacity(0.5))
    }
}

// MARK: - Zone divider

private struct BoardZoneDivider: View {
    let label: String
    let trailingLabel: String

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, Color(.separatorColor).opacity(0.6)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 1)
                LinearGradient(
                    colors: [Color(.separatorColor).opacity(0.6), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 1)
            }
            HStack {
                Text(label)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .kerning(1.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.windowBackgroundColor))
                    .padding(.leading, 14)
                Spacer()
                if !trailingLabel.isEmpty {
                    Text(trailingLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.yellow.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.windowBackgroundColor))
                        .padding(.trailing, 14)
                }
            }
        }
        .frame(height: 22)
    }
}

// MARK: - Opponent zone

private struct BoardOpponentArea: View {
    let snapshots: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    private var conditionSnaps: [DuelCardSnapshot] {
        snapshots.filter {
            $0.strategicZone != .field && $0.strategicZone != .hand
            && $0.strategicZone != .resolved && $0.strategicZone != .discarded
        }
    }
    private var activeSnaps: [DuelCardSnapshot] {
        snapshots.filter { $0.strategicZone == .field || $0.strategicZone == .hand }
    }
    private var resolvedSnaps: [DuelCardSnapshot] {
        snapshots.filter { $0.strategicZone == .resolved || $0.strategicZone == .discarded }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.blue.opacity(0.025)

            HStack(alignment: .top, spacing: 0) {
                // Conditions lane
                VStack(alignment: .leading, spacing: 4) {
                    zoneLaneLabel("CONDITIONS")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if conditionSnaps.isEmpty {
                                emptySlot(label: "No conditions", size: BL.opponentCardSize)
                            }
                            ForEach(conditionSnaps) { snap in
                                boardCard(snap, size: BL.opponentCardSize)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().padding(.vertical, 8)

                // Active threats lane
                VStack(alignment: .leading, spacing: 4) {
                    zoneLaneLabel("ACTIVE THREATS")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if activeSnaps.isEmpty {
                                emptySlot(label: "No active threats", size: BL.opponentCardSize)
                            }
                            ForEach(activeSnaps) { snap in
                                boardCard(snap, size: BL.opponentCardSize)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: .infinity)

                if !resolvedSnaps.isEmpty {
                    Divider().padding(.vertical, 8)
                    VStack(spacing: 4) {
                        Spacer().frame(height: 22)
                        CardStackBadge(count: resolvedSnaps.count, label: "Resolved")
                    }
                    .padding(.horizontal, 10)
                }
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    @ViewBuilder
    private func boardCard(_ snap: DuelCardSnapshot, size: CGSize) -> some View {
        if let card = cardsByID[snap.cardID] {
            BoardCardView(
                snapshot: snap,
                card: card,
                suite: suitsByID[card.suitIDs.first ?? ""],
                isSelected: selectedID == snap.id,
                size: size
            )
            .onTapGesture { onSelect(snap.id) }
        }
    }

    @ViewBuilder
    private func zoneLaneLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(.tertiary)
            .kerning(1)
            .padding(.horizontal, 10)
            .padding(.top, 8)
    }

    @ViewBuilder
    private func emptySlot(label: String, size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color(.separatorColor).opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
            .frame(width: size.width, height: size.height)
            .overlay(
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(4)
            )
    }
}

// MARK: - Shared zone

private struct BoardSharedArea: View {
    let duel: Duel
    let snapshots: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.controlBackgroundColor).opacity(0.35)

            HStack(spacing: 12) {
                // Objective + context
                VStack(alignment: .leading, spacing: 5) {
                    if !duel.constraints.isEmpty {
                        contextChip(icon: "exclamationmark.triangle.fill", text: duel.constraints, color: .orange)
                    }
                    if !duel.knownInformation.isEmpty {
                        contextChip(icon: "checkmark.circle.fill", text: duel.knownInformation, color: .green)
                    }
                    if !duel.unknownInformation.isEmpty {
                        contextChip(icon: "questionmark.circle.fill", text: duel.unknownInformation, color: .gray)
                    }
                    if duel.constraints.isEmpty && duel.knownInformation.isEmpty && duel.unknownInformation.isEmpty {
                        Text("No context set")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }
                .frame(minWidth: 120, maxWidth: 200, alignment: .leading)
                .padding(.leading, 14)

                Divider().padding(.vertical, 6)

                // Battlefield cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if snapshots.isEmpty {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separatorColor).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .frame(width: BL.opponentCardSize.width, height: BL.opponentCardSize.height)
                                .overlay(
                                    Text("Shared cards")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                )
                        }
                        ForEach(snapshots) { snap in
                            if let card = cardsByID[snap.cardID] {
                                BoardCardView(
                                    snapshot: snap,
                                    card: card,
                                    suite: suitsByID[card.suitIDs.first ?? ""],
                                    isSelected: selectedID == snap.id,
                                    size: BL.opponentCardSize
                                )
                                .onTapGesture { onSelect(snap.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }

                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
    }

    @ViewBuilder
    private func contextChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 9))
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.1)))
    }
}

// MARK: - Player field

private struct BoardPlayerArea: View {
    let fieldSnaps: [DuelCardSnapshot]
    let usedSnaps: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.accentColor.opacity(0.025)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE STRATEGIES")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .kerning(1)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if fieldSnaps.isEmpty {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .frame(width: BL.fieldCardSize.width, height: BL.fieldCardSize.height)
                                    .overlay(
                                        VStack(spacing: 4) {
                                            Image(systemName: "arrow.up.circle")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.accentColor.opacity(0.4))
                                            Text("Play from hand")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.tertiary)
                                        }
                                    )
                            }
                            ForEach(fieldSnaps) { snap in
                                if let card = cardsByID[snap.cardID] {
                                    BoardCardView(
                                        snapshot: snap,
                                        card: card,
                                        suite: suitsByID[card.suitIDs.first ?? ""],
                                        isSelected: selectedID == snap.id,
                                        size: BL.fieldCardSize
                                    )
                                    .onTapGesture { onSelect(snap.id) }
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: .infinity)

                if !usedSnaps.isEmpty {
                    Divider().padding(.vertical, 8)
                    VStack(spacing: 4) {
                        Spacer().frame(height: 22)
                        CardStackBadge(count: usedSnaps.count, label: "Used")
                    }
                    .padding(.horizontal, 10)
                }
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}

// MARK: - Turn bar

private struct BoardTurnBar: View {
    let panel: DuelPanel
    let totalSteps: Int
    let onAddStep: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("STEP \(panel.order + 1) / \(totalSteps)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            if !panel.narration.isEmpty {
                Text(panel.narration)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !panel.outcome.isEmpty {
                Text(panel.outcome)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: onAddStep) {
                Label("Next Step", systemImage: "arrow.right.circle")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .background(Color(.controlBackgroundColor).opacity(0.8))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Strategy hand

private struct StrategyHandRow: View {
    let snapshots: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let context: PlayabilityContext
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(.controlBackgroundColor).opacity(0.5), Color(.windowBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .top) { Divider() }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("STRATEGY HAND")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .kerning(1.5)
                        .padding(.leading, 14)
                    Spacer()
                    let lockedCount = snapshots.filter { $0.strategicZone == .locked }.count
                    if lockedCount > 0 {
                        Label("\(lockedCount) locked", systemImage: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Button(action: onAdd) {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .padding(.trailing, 10)
                }
                .frame(height: 22)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: -(BL.handNegativeGap)) {
                        if snapshots.isEmpty {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .frame(width: BL.handCardSize.width, height: BL.handCardSize.height)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.tertiary)
                                        Text("Add cards to hand")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                    }
                                )
                                .onTapGesture { onAdd() }
                        }
                        ForEach(snapshots.indices, id: \.self) { idx in
                            let snap = snapshots[idx]
                            if let card = cardsByID[snap.cardID] {
                                let isSelected = selectedID == snap.id
                                let result: PlayabilityResult = card.playabilityRules.isEmpty
                                    ? .unconstrained
                                    : PlayabilityEvaluator.evaluate(card: card, context: context)
                                HandCardView(
                                    snapshot: snap,
                                    card: card,
                                    suite: suitsByID[card.suitIDs.first ?? ""],
                                    isSelected: isSelected,
                                    playabilityResult: result
                                )
                                .zIndex(isSelected ? 100 : Double(idx))
                                .offset(y: isSelected ? -14 : 0)
                                .onTapGesture { onSelect(snap.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Board card (field zones)

private struct BoardCardView: View {
    let snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let isSelected: Bool
    let size: CGSize

    private var isLocked:   Bool { snapshot.strategicZone == .locked }
    private var isExhausted: Bool { snapshot.strategicZone == .exhausted || snapshot.strategicZone == .discarded }
    private var isNew:       Bool { snapshot.isNew }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base fill
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(isSelected ? 0.14 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardBorderColor, lineWidth: isSelected ? 2 : 1)
                )
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.35) : Color.black.opacity(0.1),
                    radius: isSelected ? 6 : 2
                )

            // Card content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    if let suite { SuiteBadge(suite: suite, size: 11) }
                    Spacer()
                    Image(systemName: snapshot.strategicZone.systemImage)
                        .font(.system(size: 8))
                        .foregroundStyle(zoneColor)
                }
                Spacer()
                Text(card.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isExhausted ? Color.secondary : Color.primary)
                    .lineLimit(3)
                Text(snapshot.status.title)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .padding(6)

            // Lock overlay
            if isLocked {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.15))
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Spacer()
                    }
                    Spacer()
                }
            }

            // "NEW" badge
            if isNew {
                VStack {
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                    }
                    Spacer()
                }
                .padding(4)
            }

            // Manual override dot
            if snapshot.isManuallyOverridden {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(5)
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(isExhausted ? 0.55 : (isLocked ? 0.65 : 1.0))
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }

    private var cardBorderColor: Color {
        if isSelected { return Color.accentColor }
        if isNew { return Color.accentColor.opacity(0.4) }
        if isLocked { return Color(.separatorColor).opacity(0.4) }
        return Color(.separatorColor)
    }

    private var zoneColor: Color {
        switch snapshot.strategicZone {
        case .hand:       return .green
        case .field:      return .accentColor
        case .locked:     return .gray
        case .exhausted:  return .orange
        case .resolved:   return .teal
        case .discarded:  return .red
        case .deck:       return .blue
        }
    }
}

// MARK: - Hand card view

private struct HandCardView: View {
    let snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let isSelected: Bool
    let playabilityResult: PlayabilityResult

    private var isLocked: Bool {
        snapshot.strategicZone == .locked || (!playabilityResult.isPlayable && playabilityResult.hasDetails)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base + selection highlight
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(isSelected ? 0.18 : 0), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color(.separatorColor), lineWidth: isSelected ? 2.5 : 1)
                )
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.45) : Color.black.opacity(0.12),
                    radius: isSelected ? 10 : 3
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let suite { SuiteBadge(suite: suite, size: 13) }
                    Spacer()
                    Text(card.kind.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Text(card.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(3)
                Spacer()
                HStack(spacing: 3) {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                        Text("Locked")
                            .font(.system(size: 8, weight: .medium))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                        Text("Available")
                            .font(.system(size: 8, weight: .medium))
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(8)

            // Lock overlay tint
            if isLocked {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
            }

            // NEW badge
            if snapshot.isNew {
                VStack {
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                    }
                    Spacer()
                }
                .padding(5)
            }

            // Selected: "▲ Play" prompt at bottom
            if isSelected {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("▲ Open")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.accentColor))
                        Spacer()
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(width: BL.handCardSize.width, height: BL.handCardSize.height)
        .opacity(isLocked ? 0.72 : 1.0)
    }
}

// MARK: - Card inspector panel

private struct CardInspectorPanel: View {
    let snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let result: PlayabilityResult
    let onClose: () -> Void
    let onUpdate: (DuelCardSnapshot) -> Void
    let onDelete: () -> Void
    let onMoveToField: () -> Void

    @State private var localAnnotation: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                if let suite { SuiteBadge(suite: suite, size: 15) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(card.kind.displayName + " · " + snapshot.strategicZone.title)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                strategicZoneMenu
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !card.frontText.isEmpty {
                        Text(card.frontText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if result.hasDetails {
                        Divider()
                        playabilitySection
                    }

                    TextField("Add a note…", text: $localAnnotation)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 150)

            Divider()

            // Actions
            HStack(spacing: 8) {
                if snapshot.zone == .player && snapshot.strategicZone != .field {
                    Button(action: onMoveToField) {
                        Label("Play to Field", systemImage: "arrow.up.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                Button("Exhaust") {
                    var s = snapshot; s.strategicZone = .exhausted; s.status = .exhausted
                    s.isManuallyOverridden = true; onUpdate(s); onClose()
                }
                .buttonStyle(.bordered).controlSize(.small)
                Button("Resolve") {
                    var s = snapshot; s.strategicZone = .resolved; s.status = .resolved
                    s.isManuallyOverridden = true; onUpdate(s); onClose()
                }
                .buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.8))
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.22), radius: 14, y: -4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { localAnnotation = snapshot.annotation }
        .onChange(of: localAnnotation) { _, new in
            var s = snapshot; s.annotation = new; onUpdate(s)
        }
    }

    @ViewBuilder
    private var strategicZoneMenu: some View {
        Menu {
            ForEach(StrategicZone.allCases, id: \.self) { zone in
                Button {
                    var s = snapshot; s.strategicZone = zone; s.isManuallyOverridden = true; onUpdate(s)
                } label: {
                    Label(zone.title, systemImage: zone.systemImage)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: snapshot.strategicZone.systemImage).font(.system(size: 10))
                Text(snapshot.strategicZone.title).font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(.controlBackgroundColor)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var playabilitySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !result.availableReasons.isEmpty {
                playRow(icon: "checkmark.circle.fill", color: .green, label: "Available because:")
                ForEach(result.availableReasons, id: \.self) {
                    Text("· \($0)").font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 12)
                }
            }
            if !result.blockedReasons.isEmpty {
                playRow(icon: "lock.fill", color: .orange, label: "Locked because:")
                ForEach(result.blockedReasons, id: \.self) {
                    Text("· \($0)").font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 12)
                }
            }
            if !result.unlockingCards.isEmpty {
                playRow(icon: "key.fill", color: .teal, label: "Play first to unlock:")
                ForEach(result.unlockingCards, id: \.self) {
                    Text("· \($0)").font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func playRow(icon: String, color: Color, label: String) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
    }
}

// MARK: - Card stack badge

private struct CardStackBadge: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                ForEach(0..<min(count, 3), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor)))
                        .frame(width: 36, height: 48)
                        .offset(x: CGFloat(i) * 2, y: CGFloat(i) * -2)
                }
            }
            .frame(width: 42, height: 54)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }
}
