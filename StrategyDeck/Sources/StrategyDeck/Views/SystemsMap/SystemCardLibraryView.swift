import SwiftUI
import StrategyDeckCore

/// The complete card library, always shown in full beneath the diagram —
/// every card, grouped by its dynamically computed ``SystemCardStatus``, so
/// the user can see the whole action vocabulary and understand why each
/// card is or isn't available right now.
struct SystemCardLibraryView: View {
    let cards: [KnowledgeCard]
    let suits: [CardSuit]
    let evaluations: [SystemCardEvaluation]
    let selectionLabel: String
    let isEditable: Bool
    let onPlay: (KnowledgeCard) -> Void
    let onClearOverride: (KnowledgeCard) -> Void

    @State private var searchText = ""
    @State private var statusFilter: SystemCardStatus?
    @State private var favoritesOnly = false

    private var evaluationByID: [UUID: SystemCardEvaluation] {
        Dictionary(uniqueKeysWithValues: evaluations.map { ($0.cardID, $0) })
    }

    private var filteredCards: [KnowledgeCard] {
        cards.filter { card in
            if favoritesOnly && !card.isFavorite { return false }
            if let statusFilter, evaluationByID[card.id]?.status != statusFilter { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                guard card.searchableText.contains(where: { $0.lowercased().contains(q) }) else { return false }
            }
            return true
        }
    }

    private var groupedCards: [(status: SystemCardStatus, title: String, cards: [KnowledgeCard])] {
        let groups = Dictionary(grouping: filteredCards) { evaluationByID[$0.id]?.status ?? .available }
        return SystemCardStatus.allCases
            .sorted { $0.groupRank < $1.groupRank }
            .reduce(into: [(SystemCardStatus, String, [KnowledgeCard])]()) { acc, status in
                guard let inGroup = groups[status], !inGroup.isEmpty else { return }
                // Avoid duplicate group headers for statuses sharing a groupRank/title.
                if let lastIdx = acc.indices.last, acc[lastIdx].1 == status.groupTitle {
                    acc[lastIdx].2.append(contentsOf: inGroup)
                } else {
                    acc.append((status, status.groupTitle, inGroup))
                }
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(AC.borderDim).frame(height: 1)

            if filteredCards.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.badge.magnifyingglass").font(.system(size: 22)).foregroundStyle(AC.textGhost)
                    Text("No cards match the current filters.").font(.system(size: 11)).foregroundStyle(AC.textSub)
                    Button("Reset Filters") { searchText = ""; statusFilter = nil; favoritesOnly = false }
                        .buttonStyle(ArenaOutlineButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedCards, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                ArenaSectionLabel(text: "\(group.title) (\(group.cards.count))", color: group.status.arenaColor)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 8)], spacing: 8) {
                                    ForEach(group.cards) { card in
                                        SystemLibraryCardView(
                                            card: card,
                                            suite: suits.first(where: { card.suitIDs.contains($0.id) }),
                                            evaluation: evaluationByID[card.id],
                                            isEditable: isEditable,
                                            onPlay: { onPlay(card) },
                                            onClearOverride: { onClearOverride(card) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(AC.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ArenaSectionLabel(text: "Card Library — \(selectionLabel)", icon: "square.stack.3d.up")
                Spacer()
                Text("\(filteredCards.count) / \(cards.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(AC.textDim)
            }
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(AC.textDim)
                    TextField("Search cards…", text: $searchText)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                        .foregroundStyle(AC.text)
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(AC.surface))

                Toggle("★", isOn: $favoritesOnly).toggleStyle(.button).font(.system(size: 10)).tint(AC.gold)

                Picker("Status", selection: $statusFilter) {
                    Text("All Statuses").tag(SystemCardStatus?.none)
                    ForEach(SystemCardStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(Optional(status))
                    }
                }
                .pickerStyle(.menu)
                .tint(AC.cyan)
                .frame(width: 140)

                if !searchText.isEmpty || statusFilter != nil || favoritesOnly {
                    Button("Reset") { searchText = ""; statusFilter = nil; favoritesOnly = false }
                        .buttonStyle(ArenaOutlineButtonStyle())
                }
            }
        }
        .padding(10)
        .background(AC.surface)
    }
}

// MARK: - One card in the library

private struct SystemLibraryCardView: View {
    let card: KnowledgeCard
    let suite: CardSuit?
    let evaluation: SystemCardEvaluation?
    let isEditable: Bool
    let onPlay: () -> Void
    let onClearOverride: () -> Void

    @State private var showingWhy = false

    private var status: SystemCardStatus { evaluation?.status ?? .available }
    private var kindColor: Color { card.kind.arenaColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let suite { SuiteBadge(suite: suite, size: 14) }
                Text(card.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AC.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                statusBadge
            }

            if let leverage = card.playabilityRules.leverageLevel {
                Text(leverage.displayName.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(0.5)
            }

            Button(action: { withAnimation(.easeInOut(duration: 0.12)) { showingWhy.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: showingWhy ? "chevron.down" : "chevron.right").font(.system(size: 7))
                    Text("Why?").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(AC.textDim)
            }
            .buttonStyle(.plain)

            if showingWhy, let evaluation {
                Text(evaluation.explanation)
                    .font(.system(size: 9))
                    .foregroundStyle(AC.textSub)
                    .fixedSize(horizontal: false, vertical: true)
                if evaluation.isManuallyOverridden {
                    Button("Clear manual override", action: onClearOverride)
                        .font(.system(size: 8, weight: .bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(AC.cyan)
                }
            }

            if isEditable, let evaluation, evaluation.isPlayable {
                Button(action: onPlay) {
                    Text(status == .recommended ? "PLAY (RECOMMENDED)" : "PLAY CARD")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ArenaButtonStyle(color: status == .recommended ? AC.gold : kindColor))
            }
        }
        .padding(9)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(status == .irrelevant ? AC.surface.opacity(0.4) : AC.surface)
        )
        .overlay(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .stroke(status.arenaColor.opacity(0.5), lineWidth: 1)
        )
        .opacity(status == .irrelevant ? 0.55 : 1.0)
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: status.systemImage).font(.system(size: 8))
            Text(status.displayName.uppercased()).font(.system(size: 7.5, weight: .black, design: .monospaced)).kerning(0.5)
            if evaluation?.isManuallyOverridden == true {
                Image(systemName: "hand.raised.fill").font(.system(size: 7))
            }
        }
        .foregroundStyle(status.arenaColor)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(status.arenaColor.opacity(0.15)))
    }
}
