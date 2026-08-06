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
                Text("SAVED SEQUENCES")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.cyan)
                    .kerning(1.5)
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AC.surface)

            Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)

            if sequenceStore.savedSequences.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(AC.textGhost)
                    Text("No saved sequences yet.\nBuild a tray and save it.")
                        .font(.system(size: 12))
                        .foregroundStyle(AC.textSub)
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
                        .listRowBackground(AC.bg)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
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
                    .foregroundStyle(AC.text)
                let names = sequence.orderedItems.sorted { $0.order < $1.order }.compactMap { item in
                    cards.first { $0.id == item.cardID }?.title
                }
                Text(names.prefix(4).joined(separator: " → "))
                    .font(.system(size: 10))
                    .foregroundStyle(AC.textSub)
                    .lineLimit(1)
            }
            Spacer()
            Button("Open") { onOpen() }
                .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AC.threat.opacity(0.75))
        }
        .padding(.vertical, 4)
    }
}
