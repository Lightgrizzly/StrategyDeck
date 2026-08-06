import SwiftUI
import StrategyDeckCore

// MARK: - Board view mode (shared with DuelTabView)

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

// MARK: - Arena color system

private enum AC {
    // Backgrounds
    static let bg         = Color(red: 0.03, green: 0.06, blue: 0.13)
    static let surface    = Color(red: 0.06, green: 0.10, blue: 0.20)
    static let surfaceHi  = Color(red: 0.09, green: 0.15, blue: 0.28)
    static let glassPanel = Color(red: 0.08, green: 0.14, blue: 0.26)
    // Cyan / player accent
    static let cyan       = Color(red: 0.15, green: 0.75, blue: 1.00)
    static let cyanDim    = Color(red: 0.10, green: 0.50, blue: 0.80)
    static let cyanGlow   = Color(red: 0.15, green: 0.75, blue: 1.00).opacity(0.55)
    static let cyanSoft   = Color(red: 0.10, green: 0.45, blue: 0.75).opacity(0.18)
    // Opponent accent
    static let threat     = Color(red: 0.95, green: 0.30, blue: 0.35)
    static let threatSoft = Color(red: 0.80, green: 0.20, blue: 0.25).opacity(0.18)
    // Objective
    static let gold       = Color(red: 1.00, green: 0.85, blue: 0.20)
    static let goldSoft   = Color(red: 1.00, green: 0.85, blue: 0.20).opacity(0.15)
    // Status
    static let available  = Color(red: 0.20, green: 0.90, blue: 0.50)
    static let lockedTint = Color(white: 0.35)
    static let exhausted  = Color(white: 0.28)
    static let resolved   = Color(red: 0.20, green: 0.85, blue: 0.65)
    // Grid / borders
    static let gridLine   = Color(red: 0.10, green: 0.30, blue: 0.60).opacity(0.18)
    static let border     = Color(red: 0.15, green: 0.40, blue: 0.75).opacity(0.55)
    static let borderDim  = Color(red: 0.10, green: 0.25, blue: 0.50).opacity(0.35)
    // Text
    static let text       = Color.white
    static let textSub    = Color(white: 0.68)
    static let textDim    = Color(white: 0.40)
    static let textGhost  = Color(white: 0.25)
}

// MARK: - Angular card shape (futuristic diagonal cut on top-right)

private struct AngularCardShape: Shape {
    var cornerRadius: CGFloat = 7
    var cornerCut: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let cr  = min(cornerRadius, rect.width * 0.4, rect.height * 0.4)
        let cut = min(cornerCut,    rect.width * 0.4)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cr, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,       y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX,       y: rect.maxY - cr))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - cr, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + cr, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cr),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
        p.addQuadCurve(to: CGPoint(x: rect.minX + cr, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - CardKind arena extensions

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

    var arenaColor: Color {
        switch self {
        case .action:      return Color(red: 1.0, green: 0.50, blue: 0.10)
        case .condition:   return Color(red: 1.0, green: 0.25, blue: 0.32)
        case .principle:   return Color(red: 0.70, green: 0.35, blue: 1.00)
        case .observation: return Color(red: 0.15, green: 0.90, blue: 0.80)
        case .entity:      return Color(red: 0.25, green: 0.65, blue: 1.00)
        case .relation:    return Color(red: 0.20, green: 0.90, blue: 0.50)
        case .modifier:    return Color(red: 1.00, green: 0.80, blue: 0.10)
        case .chunk:       return Color(red: 0.60, green: 0.50, blue: 1.00)
        case .strategy:    return AC.cyan
        }
    }
}

// MARK: - Layout constants

private enum BL {
    static let opponentCard = CGSize(width: 80,  height: 98)
    static let fieldCard    = CGSize(width: 90,  height: 112)
    static let handCard     = CGSize(width: 94,  height: 122)
    static let handGap: CGFloat = -20
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
    let onSelectPanel: (UUID) -> Void

    @State private var selectedID: UUID?
    @State private var actionBanner: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var anim: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.26, dampingFraction: 0.82)
    }

    // MARK: Derived data

    private var cardsByID: [UUID: KnowledgeCard] {
        Dictionary(uniqueKeysWithValues: cardStore.cards.map { ($0.id, $0) })
    }
    private var suitsByID: [String: CardSuit] {
        Dictionary(uniqueKeysWithValues: cardStore.suits.map { ($0.id, $0) })
    }
    private func snaps(_ zone: DuelZone) -> [DuelCardSnapshot] {
        panel.snapshots.filter { $0.zone == zone }.sorted { $0.order < $1.order }
    }
    private var playerHandSnaps: [DuelCardSnapshot] {
        snaps(.player).filter {
            $0.strategicZone == .hand || $0.strategicZone == .locked || $0.strategicZone == .deck
        }
    }
    private var playerFieldSnaps: [DuelCardSnapshot] {
        snaps(.player).filter { $0.strategicZone == .field }
    }
    private var playerUsedSnaps: [DuelCardSnapshot] {
        snaps(.player).filter {
            $0.strategicZone == .exhausted || $0.strategicZone == .resolved || $0.strategicZone == .discarded
        }
    }
    private var playContext: PlayabilityContext {
        PlayabilityEvaluator.context(from: panel, duel: duel, cardsByID: cardsByID)
    }

    // MARK: Selection helpers

    private func select(_ id: UUID) {
        withAnimation(anim) { selectedID = (selectedID == id) ? nil : id }
    }
    private func deselect() {
        withAnimation(anim) { selectedID = nil }
    }
    private func flash(_ banner: String) {
        actionBanner = banner
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.4)) { actionBanner = nil }
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DigitalArenaBackground(reduceEffects: reduceMotion)

                VStack(spacing: 0) {
                    opponentSection(geo)
                    sharedSection(geo)
                    playerSection(geo)
                    stepSection(duel: duel, panel: panel, geo: geo)
                    handSection(geo)
                }

                inspectorLayer(geo: geo)

                if let banner = actionBanner {
                    ArenaActionBanner(text: banner)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
                        .animation(.spring(response: 0.3), value: actionBanner)
                }
            }
        }
        .onKeyPress(.escape) {
            if selectedID != nil { deselect(); return .handled }
            return .ignored
        }
    }

    // MARK: Section builders

    private func opponentSection(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            OpponentIdentityPanel(duel: duel, panel: panel)
                .frame(height: 42)
            OpponentFieldZone(
                snapshots: snaps(.opponent),
                cardsByID: cardsByID,
                suitsByID: suitsByID,
                selectedID: selectedID,
                onSelect: select,
                onAdd: { onShowPicker(.opponent) }
            )
            .frame(height: max(110, geo.size.height * 0.22))
        }
    }

    private func sharedSection(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ArenaZoneDivider(label: "MISSION", color: AC.gold)
            SharedObjectiveZone(
                duel: duel,
                snapshots: snaps(.battlefield),
                cardsByID: cardsByID,
                suitsByID: suitsByID,
                selectedID: selectedID,
                onSelect: select,
                onAdd: { onShowPicker(.battlefield) }
            )
            .frame(height: max(78, geo.size.height * 0.15))
            ArenaZoneDivider(label: "STRATEGY FIELD", color: AC.cyan)
        }
    }

    private func playerSection(_ geo: GeometryProxy) -> some View {
        PlayerFieldZone(
            fieldSnaps: playerFieldSnaps,
            usedSnaps: playerUsedSnaps,
            cardsByID: cardsByID,
            suitsByID: suitsByID,
            selectedID: selectedID,
            onSelect: select,
            onAdd: { onShowPicker(.player) }
        )
        .frame(height: max(110, geo.size.height * 0.19))
    }

    private func stepSection(duel: Duel, panel: DuelPanel, geo: GeometryProxy) -> some View {
        ArenaTurnBar(
            duel: duel,
            panel: panel,
            onAddStep: onAddStep,
            onSelectPanel: onSelectPanel
        )
        .frame(height: 52)
    }

    private func handSection(_ geo: GeometryProxy) -> some View {
        ArenaHandRow(
            snapshots: playerHandSnaps,
            cardsByID: cardsByID,
            suitsByID: suitsByID,
            context: playContext,
            selectedID: selectedID,
            onSelect: select,
            onAdd: { onShowPicker(.player) }
        )
        .frame(height: max(132, geo.size.height * 0.21))
    }

    @ViewBuilder
    private func inspectorLayer(geo: GeometryProxy) -> some View {
        if let id = selectedID,
           let snap = panel.snapshots.first(where: { $0.id == id }),
           let card = cardsByID[snap.cardID] {
            let handH: CGFloat = max(132, geo.size.height * 0.21)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ArenaCardInspector(
                        snapshot: snap,
                        card: card,
                        suite: suitsByID[card.suitIDs.first ?? ""],
                        result: PlayabilityEvaluator.evaluate(card: card, context: playContext),
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
                            flash("STRATEGY ACTIVATED")
                        },
                        onExhaust: {
                            var s = snap
                            s.strategicZone = .exhausted
                            s.status = .exhausted
                            s.isManuallyOverridden = true
                            onUpdateSnapshot(s)
                            deselect()
                            flash("STRATEGY USED")
                        },
                        onResolve: {
                            var s = snap
                            s.strategicZone = .resolved
                            s.status = .resolved
                            s.isManuallyOverridden = true
                            onUpdateSnapshot(s)
                            deselect()
                            flash("STRATEGY RESOLVED")
                        }
                    )
                    .frame(width: min(geo.size.width - 32, 390))
                    Spacer()
                }
                .padding(.bottom, handH + 54)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
            .animation(anim, value: selectedID)
        }
    }
}

// MARK: - Digital arena background

private struct DigitalArenaBackground: View {
    let reduceEffects: Bool

    var body: some View {
        ZStack {
            AC.bg

            // Depth gradient — opponent recedes into dark
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.55), location: 0.00),
                    .init(color: Color.black.opacity(0.20), location: 0.28),
                    .init(color: Color.clear,               location: 0.48),
                    .init(color: AC.cyanSoft.opacity(0.3),  location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if !reduceEffects {
                // Circuit grid
                Canvas { ctx, size in
                    let s: CGFloat = 44
                    var grid = Path()
                    var x: CGFloat = 0
                    while x <= size.width  { grid.move(to: .init(x: x, y: 0)); grid.addLine(to: .init(x: x, y: size.height)); x += s }
                    var y: CGFloat = 0
                    while y <= size.height { grid.move(to: .init(x: 0, y: y)); grid.addLine(to: .init(x: size.width, y: y)); y += s }
                    ctx.stroke(grid, with: .color(AC.gridLine), lineWidth: 0.5)

                    // Center horizon glow
                    let mid = size.height * 0.5
                    var h = Path()
                    h.move(to: .init(x: 0, y: mid))
                    h.addLine(to: .init(x: size.width, y: mid))
                    ctx.stroke(h, with: .color(AC.cyan.opacity(0.10)), lineWidth: 1.5)
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Opponent identity panel

private struct OpponentIdentityPanel: View {
    let duel: Duel
    let panel: DuelPanel

    private var label: String {
        let d = duel.description.trimmingCharacters(in: .whitespaces)
        return (d.isEmpty || d.count > 32) ? "THE SYSTEM" : d.uppercased()
    }
    private var activeCount: Int {
        panel.snapshots.filter { $0.zone == .opponent && ($0.strategicZone == .field || $0.strategicZone == .hand) }.count
    }

    var body: some View {
        ZStack {
            AC.threatSoft
            HStack(spacing: 10) {
                // Threat indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(AC.threat)
                        .frame(width: 7, height: 7)
                        .shadow(color: AC.threat.opacity(0.8), radius: 4)
                    Text(label)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.threat)
                        .kerning(2)
                }
                Spacer()
                if !panel.opponentCaption.isEmpty {
                    Text(panel.opponentCaption)
                        .font(.system(size: 9))
                        .foregroundStyle(AC.textSub)
                        .lineLimit(1)
                }
                if activeCount > 0 {
                    Text("ACTIVE \(activeCount)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(AC.threat.opacity(0.8))
                        .kerning(1)
                }
            }
            .padding(.horizontal, 14)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AC.threat.opacity(0.4))
                .frame(height: 1)
        }
    }
}

// MARK: - Arena zone divider

private struct ArenaZoneDivider: View {
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, color.opacity(0.5)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                LinearGradient(colors: [color.opacity(0.5), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
            }
            HStack {
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(color.opacity(0.85))
                    .kerning(2.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        AngularCardShape(cornerRadius: 3, cornerCut: 6)
                            .fill(AC.bg)
                            .overlay(AngularCardShape(cornerRadius: 3, cornerCut: 6)
                                .stroke(color.opacity(0.35), lineWidth: 0.75))
                    )
                    .padding(.leading, 14)
                Spacer()
            }
        }
        .frame(height: 20)
        .shadow(color: color.opacity(0.3), radius: 6)
    }
}

// MARK: - Opponent field zone

private struct OpponentFieldZone: View {
    let snapshots: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    private var persistentSnaps: [DuelCardSnapshot] {
        snapshots.filter {
            $0.strategicZone != .field && $0.strategicZone != .hand
            && $0.strategicZone != .resolved && $0.strategicZone != .discarded
        }
    }
    private var activeSnaps: [DuelCardSnapshot] {
        snapshots.filter { $0.strategicZone == .field || $0.strategicZone == .hand }
    }
    private var resolvedCount: Int {
        snapshots.filter { $0.strategicZone == .resolved || $0.strategicZone == .discarded }.count
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AC.threatSoft.opacity(0.5)

            HStack(alignment: .top, spacing: 0) {
                // Persistent threats
                fieldLane(label: "PERSISTENT THREAT", snaps: persistentSnaps,
                          emptyText: "No conditions", accentColor: AC.threat.opacity(0.6))
                    .frame(maxWidth: .infinity)

                Rectangle().fill(AC.border.opacity(0.3)).frame(width: 1).padding(.vertical, 8)

                // Incoming move / active
                fieldLane(label: "INCOMING MOVE", snaps: activeSnaps,
                          emptyText: "No active threat", accentColor: AC.threat)
                    .frame(maxWidth: .infinity)

                if resolvedCount > 0 {
                    Rectangle().fill(AC.border.opacity(0.3)).frame(width: 1).padding(.vertical, 8)
                    VStack(spacing: 4) {
                        Spacer().frame(height: 24)
                        ArenaStackBadge(count: resolvedCount, label: "RESOLVED", color: AC.textDim)
                    }
                    .padding(.horizontal, 10)
                }
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AC.textDim)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    @ViewBuilder
    private func fieldLane(label: String, snaps: [DuelCardSnapshot],
                           emptyText: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor.opacity(0.7))
                .kerning(1.5)
                .padding(.horizontal, 10)
                .padding(.top, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if snaps.isEmpty {
                        ArenaEmptySlot(text: emptyText, size: BL.opponentCard,
                                       color: AC.threat.opacity(0.25))
                    }
                    ForEach(snaps) { snap in
                        if let card = cardsByID[snap.cardID] {
                            ArenaFieldCard(
                                snapshot: snap, card: card,
                                suite: suitsByID[card.suitIDs.first ?? ""],
                                isSelected: selectedID == snap.id,
                                size: BL.opponentCard
                            )
                            .onTapGesture { onSelect(snap.id) }
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Shared objective zone

private struct SharedObjectiveZone: View {
    let duel: Duel
    let snapshots: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Holographic surface
            ZStack {
                LinearGradient(
                    colors: [AC.goldSoft.opacity(0.4), AC.cyanSoft.opacity(0.2)],
                    startPoint: .leading, endPoint: .trailing
                )
                AC.glassPanel.opacity(0.6)
            }

            HStack(spacing: 0) {
                // Mission objective
                if !duel.victoryCondition.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(AC.gold)
                                .shadow(color: AC.gold.opacity(0.8), radius: 4)
                            Text("MISSION OBJECTIVE")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(AC.gold.opacity(0.85))
                                .kerning(1.5)
                        }
                        Text(duel.victoryCondition)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AC.text)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(minWidth: 140, maxWidth: 210, alignment: .leading)
                    .background(
                        AngularCardShape(cornerRadius: 6, cornerCut: 10)
                            .fill(AC.goldSoft)
                            .overlay(AngularCardShape(cornerRadius: 6, cornerCut: 10)
                                .stroke(AC.gold.opacity(0.45), lineWidth: 1))
                    )
                    .padding(.leading, 14)
                    .shadow(color: AC.gold.opacity(0.3), radius: 6)
                }

                // Context chips
                VStack(alignment: .leading, spacing: 4) {
                    if !duel.constraints.isEmpty {
                        contextChip("exclamationmark.triangle.fill", duel.constraints, .orange)
                    }
                    if !duel.knownInformation.isEmpty {
                        contextChip("checkmark.seal.fill", duel.knownInformation, AC.available)
                    }
                    if !duel.unknownInformation.isEmpty {
                        contextChip("questionmark.circle.fill", duel.unknownInformation, AC.textDim)
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                // Shared cards
                if !snapshots.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(snapshots) { snap in
                                if let card = cardsByID[snap.cardID] {
                                    ArenaFieldCard(
                                        snapshot: snap, card: card,
                                        suite: suitsByID[card.suitIDs.first ?? ""],
                                        isSelected: selectedID == snap.id,
                                        size: BL.opponentCard
                                    )
                                    .onTapGesture { onSelect(snap.id) }
                                }
                            }
                        }
                        .padding(.horizontal, 4).padding(.vertical, 6)
                    }
                }

                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AC.textDim)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
    }

    @ViewBuilder
    private func contextChip(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8)).foregroundStyle(color)
            Text(text).font(.system(size: 9)).lineLimit(1).foregroundStyle(AC.textSub)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12))
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5)))
    }
}

// MARK: - Player field zone

private struct PlayerFieldZone: View {
    let fieldSnaps: [DuelCardSnapshot]
    let usedSnaps: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AC.cyanSoft.opacity(0.5)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE STRATEGY")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.cyan.opacity(0.7))
                        .kerning(1.5)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if fieldSnaps.isEmpty {
                                ArenaEmptySlot(text: "Deploy from hand", size: BL.fieldCard,
                                               color: AC.cyan.opacity(0.4))
                            }
                            ForEach(fieldSnaps) { snap in
                                if let card = cardsByID[snap.cardID] {
                                    ArenaFieldCard(
                                        snapshot: snap, card: card,
                                        suite: suitsByID[card.suitIDs.first ?? ""],
                                        isSelected: selectedID == snap.id,
                                        size: BL.fieldCard
                                    )
                                    .onTapGesture { onSelect(snap.id) }
                                }
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: .infinity)

                if !usedSnaps.isEmpty {
                    Rectangle().fill(AC.border.opacity(0.3)).frame(width: 1).padding(.vertical, 8)
                    VStack(spacing: 4) {
                        Spacer().frame(height: 24)
                        ArenaStackBadge(count: usedSnaps.count, label: "USED", color: AC.textDim)
                    }
                    .padding(.horizontal, 10)
                }
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AC.textDim)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}

// MARK: - Arena turn bar + timeline

private struct ArenaTurnBar: View {
    let duel: Duel
    let panel: DuelPanel
    let onAddStep: () -> Void
    let onSelectPanel: (UUID) -> Void

    var body: some View {
        ZStack {
            AC.surface
            Rectangle().fill(AC.cyan.opacity(0.12)).frame(height: 1).frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                // Controls row
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(AC.cyan.opacity(0.7))
                        Text("STEP \(panel.order + 1) / \(duel.sortedPanels.count)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.cyan)
                            .kerning(1)
                    }
                    if !panel.narration.isEmpty {
                        Text("·  \(panel.narration)")
                            .font(.system(size: 9))
                            .foregroundStyle(AC.textSub)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !panel.outcome.isEmpty {
                        Text(panel.outcome)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AC.available)
                            .lineLimit(1)
                    }
                    Button(action: onAddStep) {
                        HStack(spacing: 5) {
                            Text("NEXT STEP")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .kerning(1.5)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(AC.bg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AC.cyan)
                        .clipShape(AngularCardShape(cornerRadius: 4, cornerCut: 6))
                    }
                    .buttonStyle(.plain)
                    .shadow(color: AC.cyanGlow, radius: 6)
                }
                .padding(.horizontal, 14)
                .frame(height: 32)

                // Timeline strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(duel.sortedPanels) { p in
                            let isCurrent = p.id == panel.id
                            Button(action: { onSelectPanel(p.id) }) {
                                VStack(spacing: 2) {
                                    Text("\(p.order + 1)")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(isCurrent ? AC.cyan : AC.textDim)
                                    Circle()
                                        .fill(p.snapshots.isEmpty ? Color.clear : (isCurrent ? AC.cyan : AC.textDim))
                                        .frame(width: 3, height: 3)
                                }
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isCurrent ? AC.cyan.opacity(0.15) : Color.clear)
                                        .overlay(RoundedRectangle(cornerRadius: 4)
                                            .stroke(isCurrent ? AC.cyan.opacity(0.55) : AC.borderDim, lineWidth: 0.75))
                                )
                            }
                            .buttonStyle(.plain)
                            .shadow(color: isCurrent ? AC.cyanGlow.opacity(0.5) : .clear, radius: 4)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 20)
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(AC.cyan.opacity(0.25)).frame(height: 1)
        }
    }
}

// MARK: - Strategy hand

private struct ArenaHandRow: View {
    let snapshots: [DuelCardSnapshot]
    let cardsByID: [UUID: KnowledgeCard]
    let suitsByID: [String: CardSuit]
    let context: PlayabilityContext
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Hand area background
            ZStack {
                AC.surface
                LinearGradient(
                    colors: [Color.clear, AC.cyanSoft.opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                Rectangle().fill(AC.cyan.opacity(0.20)).frame(height: 1)
            }

            VStack(spacing: 0) {
                // Label row
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(AC.cyan.opacity(0.6))
                    Text("STRATEGY HAND")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.cyan.opacity(0.6))
                        .kerning(2)
                    Spacer()
                    let lockedCount = snapshots.filter { $0.strategicZone == .locked }.count
                    if lockedCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill").font(.system(size: 8))
                            Text("\(lockedCount) LOCKED").font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(AC.textDim)
                    }
                    Button(action: onAdd) {
                        Label("ADD", systemImage: "plus")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(AC.cyan)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(
                                AngularCardShape(cornerRadius: 3, cornerCut: 5)
                                    .stroke(AC.cyan.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
                .padding(.leading, 14)
                .frame(height: 24)

                // Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: BL.handGap) {
                        if snapshots.isEmpty {
                            ArenaEmptySlot(text: "Add cards", size: BL.handCard, color: AC.cyan.opacity(0.3))
                                .onTapGesture { onAdd() }
                        }
                        ForEach(snapshots.indices, id: \.self) { idx in
                            let snap = snapshots[idx]
                            if let card = cardsByID[snap.cardID] {
                                let isSelected = selectedID == snap.id
                                let result = PlayabilityEvaluator.evaluate(card: card, context: context)
                                ArenaHandCard(
                                    snapshot: snap,
                                    card: card,
                                    suite: suitsByID[card.suitIDs.first ?? ""],
                                    isSelected: isSelected,
                                    result: result
                                )
                                .zIndex(isSelected ? 100 : Double(idx))
                                .offset(y: isSelected ? -16 : 0)
                                .onTapGesture { onSelect(snap.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

// MARK: - Arena field card

private struct ArenaFieldCard: View {
    let snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let isSelected: Bool
    let size: CGSize

    private var cr:  CGFloat { 7 }
    private var cut: CGFloat { 10 }

    private var isLocked:   Bool { snapshot.strategicZone == .locked }
    private var isExhausted: Bool {
        snapshot.strategicZone == .exhausted || snapshot.strategicZone == .discarded
    }
    private var isNew: Bool { snapshot.isNew }
    private var kindColor: Color { card.kind.arenaColor }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base surface
            AngularCardShape(cornerRadius: cr, cornerCut: cut)
                .fill(AC.surface)

            // Selection fill
            if isSelected {
                AngularCardShape(cornerRadius: cr, cornerCut: cut)
                    .fill(kindColor.opacity(0.12))
            }

            // Kind-colored left edge bar
            HStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [kindColor, kindColor.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 2.5)
                Spacer()
            }
            .clipShape(AngularCardShape(cornerRadius: cr, cornerCut: cut))

            // Border
            AngularCardShape(cornerRadius: cr, cornerCut: cut)
                .stroke(isSelected ? kindColor : AC.borderDim, lineWidth: isSelected ? 1.5 : 0.75)
                .shadow(color: isSelected ? kindColor.opacity(0.8) : .clear, radius: 6)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    if let suite { SuiteBadge(suite: suite, size: 10) }
                    Spacer()
                    Image(systemName: snapshot.strategicZone.systemImage)
                        .font(.system(size: 7))
                        .foregroundStyle(zoneColor.opacity(0.7))
                }
                Spacer()
                Text(card.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isExhausted ? AC.textDim : AC.text)
                    .lineLimit(3)
                Text(snapshot.status.title.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(zoneColor.opacity(0.6))
                    .kerning(1)
            }
            .padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 6)

            // Locked dim overlay
            if isLocked {
                AngularCardShape(cornerRadius: cr, cornerCut: cut)
                    .fill(Color.black.opacity(0.45))
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: AC.cyan.opacity(0.3), radius: 3)
            }

            // NEW badge
            if isNew {
                VStack {
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.bg)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(AngularCardShape(cornerRadius: 2, cornerCut: 4).fill(AC.cyan))
                            .shadow(color: AC.cyanGlow, radius: 4)
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
                        Circle().fill(Color.orange.opacity(0.7)).frame(width: 4, height: 4)
                    }
                }
                .padding(5)
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(isExhausted ? 0.50 : (isLocked ? 0.62 : 1.0))
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }

    private var zoneColor: Color {
        switch snapshot.strategicZone {
        case .hand:      return AC.available
        case .field:     return AC.cyan
        case .locked:    return AC.lockedTint
        case .exhausted: return .orange
        case .resolved:  return AC.resolved
        case .discarded: return AC.threat
        case .deck:      return AC.cyanDim
        }
    }
}

// MARK: - Arena hand card

private struct ArenaHandCard: View {
    let snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let isSelected: Bool
    let result: PlayabilityResult

    private var cr:  CGFloat { 8 }
    private var cut: CGFloat { 13 }
    private var kindColor: Color { card.kind.arenaColor }
    private var isLocked: Bool {
        snapshot.strategicZone == .locked || (!result.isPlayable && result.hasDetails)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base
            AngularCardShape(cornerRadius: cr, cornerCut: cut)
                .fill(AC.surfaceHi)

            // Selection gradient fill
            if isSelected {
                AngularCardShape(cornerRadius: cr, cornerCut: cut)
                    .fill(LinearGradient(
                        colors: [kindColor.opacity(0.22), AC.surfaceHi],
                        startPoint: .top, endPoint: .bottom
                    ))
            }

            // Kind left edge
            HStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [kindColor, kindColor.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3)
                Spacer()
            }
            .clipShape(AngularCardShape(cornerRadius: cr, cornerCut: cut))

            // Border
            AngularCardShape(cornerRadius: cr, cornerCut: cut)
                .stroke(isSelected ? kindColor : (isLocked ? AC.borderDim.opacity(0.5) : AC.border),
                        lineWidth: isSelected ? 2 : 0.75)
                .shadow(color: isSelected ? kindColor.opacity(0.9) : .clear, radius: 10)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let suite { SuiteBadge(suite: suite, size: 12) }
                    Spacer()
                    Text(card.kind.symbol)
                        .font(.system(size: 10))
                        .foregroundStyle(kindColor.opacity(0.6))
                }
                Text(card.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isLocked ? AC.textDim : AC.text)
                    .lineLimit(3)
                Spacer()
                if isLocked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.system(size: 8))
                        Text("LOCKED").font(.system(size: 7, weight: .black, design: .monospaced)).kerning(1)
                    }
                    .foregroundStyle(AC.textDim)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 8)).foregroundStyle(AC.available)
                        Text("READY").font(.system(size: 7, weight: .black, design: .monospaced)).kerning(1).foregroundStyle(AC.available.opacity(0.8))
                    }
                }
            }
            .padding(.leading, 9).padding(.trailing, 7).padding(.vertical, 8)

            // Locked dim
            if isLocked {
                AngularCardShape(cornerRadius: cr, cornerCut: cut)
                    .fill(Color.black.opacity(0.35))
            }

            // NEW badge
            if snapshot.isNew {
                VStack {
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.bg)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(AngularCardShape(cornerRadius: 2, cornerCut: 4).fill(AC.cyan))
                            .shadow(color: AC.cyanGlow, radius: 5)
                    }
                    Spacer()
                }
                .padding(5)
            }

            // Selected: lift prompt
            if isSelected {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("▲ OPEN")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.bg)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(AngularCardShape(cornerRadius: 3, cornerCut: 5).fill(kindColor))
                            .shadow(color: kindColor.opacity(0.7), radius: 5)
                        Spacer()
                    }
                    .padding(.bottom, 7)
                }
            }
        }
        .frame(width: BL.handCard.width, height: BL.handCard.height)
        .opacity(isLocked ? 0.68 : 1.0)
    }
}

// MARK: - Arena card inspector

private struct ArenaCardInspector: View {
    let snapshot: DuelCardSnapshot
    let card: KnowledgeCard
    let suite: CardSuit?
    let result: PlayabilityResult
    let onClose: () -> Void
    let onUpdate: (DuelCardSnapshot) -> Void
    let onDelete: () -> Void
    let onMoveToField: () -> Void
    let onExhaust: () -> Void
    let onResolve: () -> Void

    @State private var localAnnotation: String = ""
    private var kindColor: Color { card.kind.arenaColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            ZStack {
                kindColor.opacity(0.12)
                HStack(spacing: 8) {
                    if let suite { SuiteBadge(suite: suite, size: 14) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AC.text)
                        Text("\(card.kind.displayName.uppercased())  ·  \(snapshot.strategicZone.title.uppercased())")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(kindColor.opacity(0.8))
                            .kerning(1)
                    }
                    Spacer()
                    zoneMenu
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AC.textDim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(kindColor.opacity(0.35)).frame(height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !card.frontText.isEmpty {
                        Text(card.frontText)
                            .font(.system(size: 11))
                            .foregroundStyle(AC.textSub)
                    }
                    if result.hasDetails {
                        Rectangle().fill(AC.borderDim).frame(height: 1)
                        playabilityBlock
                    }
                    TextField("Add a note…", text: $localAnnotation)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .colorScheme(.dark)
                }
                .padding(12)
            }
            .frame(maxHeight: 140)

            // Actions
            ZStack {
                AC.surface
                HStack(spacing: 7) {
                    if snapshot.zone == .player && snapshot.strategicZone != .field {
                        Button(action: onMoveToField) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.circle.fill").font(.system(size: 11))
                                Text("DEPLOY").font(.system(size: 9, weight: .black, design: .monospaced)).kerning(1)
                            }
                            .foregroundStyle(AC.bg)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(AngularCardShape(cornerRadius: 4, cornerCut: 6).fill(kindColor))
                        }
                        .buttonStyle(.plain)
                        .shadow(color: kindColor.opacity(0.6), radius: 5)
                    }
                    quickActionButton("EXHAUST", icon: "minus.circle", action: onExhaust)
                    quickActionButton("RESOLVE", icon: "checkmark.circle", action: onResolve)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(AC.threat.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(AC.borderDim).frame(height: 1)
            }
        }
        .background(
            AngularCardShape(cornerRadius: 12, cornerCut: 18)
                .fill(AC.glassPanel)
                .shadow(color: .black.opacity(0.55), radius: 18, y: -4)
        )
        .overlay(
            AngularCardShape(cornerRadius: 12, cornerCut: 18)
                .stroke(kindColor.opacity(0.45), lineWidth: 1)
        )
        .clipShape(AngularCardShape(cornerRadius: 12, cornerCut: 18))
        .colorScheme(.dark)
        .onAppear { localAnnotation = snapshot.annotation }
        .onChange(of: localAnnotation) { _, new in
            var s = snapshot; s.annotation = new; onUpdate(s)
        }
    }

    @ViewBuilder
    private func quickActionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).kerning(1)
            }
            .foregroundStyle(AC.textSub)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(
                AngularCardShape(cornerRadius: 3, cornerCut: 5)
                    .stroke(AC.borderDim, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var zoneMenu: some View {
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
                Image(systemName: snapshot.strategicZone.systemImage).font(.system(size: 9))
                Text(snapshot.strategicZone.title.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).kerning(1)
                Image(systemName: "chevron.down").font(.system(size: 8))
            }
            .foregroundStyle(AC.textSub)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(
                AngularCardShape(cornerRadius: 3, cornerCut: 5)
                    .fill(AC.surface)
                    .overlay(AngularCardShape(cornerRadius: 3, cornerCut: 5)
                        .stroke(AC.borderDim, lineWidth: 0.75))
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var playabilityBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !result.availableReasons.isEmpty {
                playRow("checkmark.circle.fill", AC.available, "AVAILABLE BECAUSE:")
                ForEach(result.availableReasons, id: \.self) {
                    Text("· \($0)").font(.system(size: 10)).foregroundStyle(AC.textSub).padding(.leading, 12)
                }
            }
            if !result.blockedReasons.isEmpty {
                playRow("lock.fill", AC.threat, "LOCKED BECAUSE:")
                ForEach(result.blockedReasons, id: \.self) {
                    Text("· \($0)").font(.system(size: 10)).foregroundStyle(AC.textSub).padding(.leading, 12)
                }
            }
            if !result.unlockingCards.isEmpty {
                playRow("key.fill", AC.resolved, "DEPLOY FIRST:")
                ForEach(result.unlockingCards, id: \.self) {
                    Text("· \($0)").font(.system(size: 10)).foregroundStyle(AC.textSub).padding(.leading, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func playRow(_ icon: String, _ color: Color, _ label: String) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .kerning(1)
    }
}

// MARK: - Action banner

private struct ArenaActionBanner: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(text)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.cyan)
                    .kerning(3)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(
                        ZStack {
                            AngularCardShape(cornerRadius: 4, cornerCut: 14)
                                .fill(AC.bg.opacity(0.96))
                            AngularCardShape(cornerRadius: 4, cornerCut: 14)
                                .stroke(AC.cyan.opacity(0.8), lineWidth: 1.5)
                        }
                    )
                    .shadow(color: AC.cyanGlow, radius: 20)
                Spacer()
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Arena stack badge

private struct ArenaStackBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                ForEach(0..<min(count, 3), id: \.self) { i in
                    AngularCardShape(cornerRadius: 5, cornerCut: 7)
                        .fill(AC.surfaceHi)
                        .overlay(AngularCardShape(cornerRadius: 5, cornerCut: 7)
                            .stroke(AC.borderDim, lineWidth: 0.75))
                        .frame(width: 38, height: 50)
                        .offset(x: CGFloat(i) * 2, y: CGFloat(i) * -2)
                }
            }
            .frame(width: 44, height: 56)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))
                .kerning(1)
        }
    }
}

// MARK: - Empty zone slot

private struct ArenaEmptySlot: View {
    let text: String
    let size: CGSize
    let color: Color

    var body: some View {
        ZStack {
            AngularCardShape(cornerRadius: 7, cornerCut: 10)
                .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4]))
            AngularCardShape(cornerRadius: 7, cornerCut: 10)
                .fill(color.opacity(0.04))
            Text(text)
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(6)
        }
        .frame(width: size.width, height: size.height)
    }
}
