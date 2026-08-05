import SwiftUI
import StrategyDeckCore

/// Full inspector for a card, shown as a sheet.
struct KnowledgeCardDetailView: View {
    let card: KnowledgeCard
    let suite: CardSuit?
    let allCards: [KnowledgeCard]
    let relationships: [CardRelationship]
    let onEdit: () -> Void
    let onAddToTray: () -> Void
    let onDismiss: () -> Void

    private var softwareFields: SoftwareStrategyFields? {
        if case .softwareStrategy(let f) = card.metadata { return f }
        return nil
    }

    /// Relationships where this card is either end, paired with the label to
    /// show (using the inverse label when this card is the target).
    private var relatedRows: [(label: String, card: KnowledgeCard)] {
        relationships.compactMap { rel in
            if rel.sourceCardID == card.id {
                guard let target = allCards.first(where: { $0.id == rel.targetCardID }) else { return nil }
                return (rel.type.label, target)
            } else if rel.targetCardID == card.id {
                guard let source = allCards.first(where: { $0.id == rel.sourceCardID }) else { return nil }
                return (rel.type.inverseLabel, source)
            }
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.escape)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        onAddToTray()
                        onDismiss()
                    } label: {
                        Label("Add to Sequence", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        onEdit()
                        onDismiss()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 10) {
                        if let suite { SuiteBadge(suite: suite, size: 30) }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(card.kind.symbol).font(.system(size: 13))
                                Text(card.title).font(.system(size: 17, weight: .bold))
                            }
                            if let suite {
                                Text(suite.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(SuiteColors.color(for: suite.id))
                            }
                        }
                        Spacer()
                    }

                    if !card.tags.isEmpty { TagRow(tags: card.tags) }

                    if let f = softwareFields {
                        Group {
                            if !f.trigger.isEmpty { detailSection("Trigger", f.trigger) }
                            if !f.problemShape.isEmpty { detailSection("Problem Shape", f.problemShape) }
                            if !f.desiredResult.isEmpty { detailSection("Desired Result", f.desiredResult) }
                            if !f.mechanism.isEmpty { detailSection("Mechanism", f.mechanism) }
                        }

                        if !f.requirements.isEmpty { bulletSection("Requirements", f.requirements) }

                        HStack(alignment: .top, spacing: 12) {
                            if !f.advantages.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    label("Advantages")
                                    ForEach(f.advantages, id: \.self) { Text("↑ \($0)").font(.system(size: 11)) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if !f.costs.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    label("Costs")
                                    ForEach(f.costs, id: \.self) { Text("↓ \($0)").font(.system(size: 11)) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !f.failureModes.isEmpty { bulletSection("Failure Modes", f.failureModes) }

                        if !f.timeComplexity.isEmpty || !f.spaceComplexity.isEmpty {
                            HStack(spacing: 20) {
                                if !f.timeComplexity.isEmpty { complexityBadge("Time", f.timeComplexity) }
                                if !f.spaceComplexity.isEmpty { complexityBadge("Space", f.spaceComplexity) }
                            }
                        }

                        if !f.flowDescription.isEmpty { detailSection("Flow", f.flowDescription) }

                        if !f.codeExample.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                label("Code Example")
                                Text(f.codeExample)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.08)))
                            }
                        }

                        if !f.realWorldExample.isEmpty { detailSection("Real-World Example", f.realWorldExample) }
                    }

                    if !relatedRows.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            label("Relationships")
                            ForEach(Array(relatedRows.enumerated()), id: \.offset) { _, row in
                                Text("\(row.label): \(row.card.title)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !card.backText.isEmpty { detailSection("Notes", card.backText) }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Subviews

    private func detailSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletSection(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title)
            ForEach(items, id: \.self) {
                Text("• \($0)").font(.system(size: 11))
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
    }

    private func complexityBadge(_ kind: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.1)))
    }
}
