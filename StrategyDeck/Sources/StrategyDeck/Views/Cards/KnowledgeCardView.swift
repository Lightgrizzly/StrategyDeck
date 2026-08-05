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

    @State private var isHovered = false

    private var accentColor: Color {
        suite.map { SuiteColors.color(for: $0.id) } ?? .secondary
    }

    private var softwareFields: SoftwareStrategyFields? {
        if case .softwareStrategy(let f) = card.metadata { return f }
        return nil
    }

    private var triggerSummary: String {
        let trigger = softwareFields?.trigger ?? ""
        return trigger.isEmpty ? "No trigger described yet." : trigger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                if let suite { SuiteBadge(suite: suite, size: 16) }
                Text(card.kind.symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(card.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if card.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
            }

            Divider().padding(.vertical, 4)

            Text(triggerSummary)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if let adv = softwareFields?.advantages.first, !adv.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.green)
                        Text(adv)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
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
                        .foregroundStyle(.red.opacity(0.7))
                    Text(cost)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? accentColor.opacity(0.1)
                      : (isHovered ? Color(.controlBackgroundColor) : Color(.windowBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? accentColor.opacity(0.5) : Color(.separatorColor).opacity(0.6), lineWidth: isSelected ? 1 : 0.5)
                )
        )
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
        Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        Button { onFavorite() } label: {
            Label(card.isFavorite ? "Unfavorite" : "Favorite", systemImage: card.isFavorite ? "star.slash" : "star")
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
    }
}
