import SwiftUI
import StrategyDeckCore

/// Sheet for browsing, opening, and deleting saved sequences.
struct SequenceManagerView: View {
    @EnvironmentObject var sequenceStore: SequenceStore
    @EnvironmentObject var cardStore: CardStore
    var onDismiss: () -> Void

    @State private var alertState: AlertState?
    @State private var pendingDeleteID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved Sequences")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if sequenceStore.savedSequences.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No saved sequences yet.\nBuild a tray and save it.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sequenceStore.savedSequences.sorted { $0.updatedAt > $1.updatedAt }) { sequence in
                        SequenceRow(
                            sequence: sequence,
                            cards: cardStore.cards,
                            onOpen: {
                                sequenceStore.openSequence(sequence)
                                onDismiss()
                            },
                            onDelete: {
                                pendingDeleteID = sequence.id
                                alertState = .destructive(
                                    title: "Delete \"\(sequence.name)\"?",
                                    message: "This sequence will be permanently removed.",
                                    confirmLabel: "Delete"
                                ) {
                                    if let id = pendingDeleteID { sequenceStore.deleteSequence(id: id) }
                                }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .alertState($alertState)
        .frame(minWidth: 320, minHeight: 300)
    }
}

private struct SequenceRow: View {
    let sequence: StrategySequence
    let cards: [KnowledgeCard]
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sequence.name)
                    .font(.system(size: 12, weight: .semibold))
                let names = sequence.orderedItems.sorted { $0.order < $1.order }.compactMap { item in
                    cards.first { $0.id == item.cardID }?.title
                }
                Text(names.prefix(4).joined(separator: " → "))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Open") { onOpen() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
