import SwiftUI
import StrategyDeckCore

/// The compact card shown in the grid. Intentionally small (~90pt tall).
struct KnowledgeCardView: View {
    let card: KnowledgeCard
    let suite: CardSuit?
    var isSelected: Bool = false
    let onTap: () -> Void
    let onAddToTray: () -> Void
    let onFavorite: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    /// Duplicate variations — all optional so existing call sites (e.g. the
    /// Duel tab's read-only card browser) compile unchanged.
    var availableSuits: [CardSuit] = []
    var onDuplicateIntoCurrentDeck: (() -> Void)? = nil
    var onDuplicateIntoSuite: ((CardSuit) -> Void)? = nil
    var onDuplicateAsVariation: (() -> Void)? = nil

    @State private var isHovered = false

    private var accentColor: Color {
        suite.map { SuiteColors.color(for: $0) } ?? card.kind.arenaColor
    }
    private var kindColor: Color { card.kind.arenaColor }

    private var softwareFields: SoftwareStrategyFields? {
        if case .softwareStrategy(let f) = card.metadata { return f }
        return nil
    }

    private var triggerSummary: String {
        let trigger = softwareFields?.trigger ?? ""
        return trigger.isEmpty ? "No trigger described yet." : trigger
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(isSelected ? kindColor.opacity(0.14) : (isHovered ? AC.surfaceHi : AC.surface))

            // Kind-colored left edge
            HStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(colors: [kindColor, kindColor.opacity(0.4)],
                                          startPoint: .top, endPoint: .bottom))
                    .frame(width: 2.5)
                Spacer()
            }
            .clipShape(AngularCardShape(cornerRadius: 8, cornerCut: 12))

            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .stroke(isSelected ? kindColor : AC.borderDim, lineWidth: isSelected ? 1.5 : 0.75)
                .shadow(color: isSelected ? kindColor.opacity(0.7) : .clear, radius: 6)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    if let suite { SuiteBadge(suite: suite, size: 16) }
                    Text(card.kind.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(kindColor.opacity(0.8))
                    Text(card.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AC.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if card.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AC.gold)
                            .shadow(color: AC.gold.opacity(0.6), radius: 3)
                    }
                }

                Rectangle().fill(AC.borderDim).frame(height: 1).padding(.vertical, 4)

                Text(triggerSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(AC.textSub)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    if let adv = softwareFields?.advantages.first, !adv.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(AC.available)
                            Text(adv)
                                .font(.system(size: 9))
                                .foregroundStyle(AC.textSub)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.spring(duration: 0.2)) { onAddToTray() }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Add to Sequence")
                }

                if let cost = softwareFields?.costs.first, !cost.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AC.threat.opacity(0.85))
                        Text(cost)
                            .font(.system(size: 9))
                            .foregroundStyle(AC.textSub)
                            .lineLimit(1)
                    }
                }
            }
            .padding(9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .contextMenu { contextMenu }
        .draggable(card.id.uuidString)
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button { onAddToTray() } label: { Label("Add to Sequence", systemImage: "plus.circle") }
        Divider()
        Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
        if onDuplicateIntoCurrentDeck == nil && onDuplicateIntoSuite == nil && onDuplicateAsVariation == nil {
            Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        } else {
            Menu {
                Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                if let onDuplicateIntoCurrentDeck {
                    Button("Duplicate into Current Deck", action: onDuplicateIntoCurrentDeck)
                }
                if let onDuplicateIntoSuite, !availableSuits.isEmpty {
                    Menu("Duplicate into Another Suite") {
                        ForEach(availableSuits.sorted { $0.displayOrder < $1.displayOrder }) { suit in
                            Button(suit.name) { onDuplicateIntoSuite(suit) }
                        }
                    }
                }
                if let onDuplicateAsVariation {
                    Button("Duplicate as Variation…", action: onDuplicateAsVariation)
                }
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
        }
        Button { onFavorite() } label: {
            Label(card.isFavorite ? "Unfavorite" : "Favorite", systemImage: card.isFavorite ? "star.slash" : "star")
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
    }
}
