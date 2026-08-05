import SwiftUI
import StrategyDeckCore

/// Collapsible bottom tray showing the current ordered sequence of selected cards.
struct SequenceTrayView: View {
    @EnvironmentObject var sequenceStore: SequenceStore
    @EnvironmentObject var cardStore: CardStore

    @State private var isExpanded = true
    @State private var showingSaveSheet = false
    @State private var showingManager = false
    @State private var saveSequenceName = ""
    @State private var saveSequenceDesc = ""
    @State private var alertState: AlertState?
    // TODO: no editor sheet consumes this yet — the note button sets it but
    // nothing reads it, matching the identical dead end in the old
    // LoadoutTrayView this was ported from. SequenceStore.updateNote(for:note:)
    // exists and works; it just has no UI caller.
    @State private var editingNoteForID: UUID?

    private var orderedItems: [StrategySequenceItem] {
        sequenceStore.trayItems.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Tray header
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Sequence")
                            .font(.system(size: 11, weight: .semibold))
                        if !sequenceStore.trayItems.isEmpty {
                            Text("\(sequenceStore.trayItems.count)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(.secondary.opacity(0.15)))
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if !sequenceStore.trayItems.isEmpty {
                    Button {
                        alertState = .destructive(
                            title: "Clear Sequence?",
                            message: "All items will be removed from the tray. Save first if you want to keep this sequence.",
                            confirmLabel: "Clear"
                        ) { sequenceStore.clearTray() }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear sequence")

                    Button {
                        saveSequenceName = ""
                        saveSequenceDesc = ""
                        showingSaveSheet = true
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Button {
                    showingManager = true
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open saved sequence")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // Tray content
            if isExpanded {
                if orderedItems.isEmpty {
                    emptyTray
                } else {
                    trayList
                }
            }
        }
        .alertState($alertState)
        // Save sheet
        .sheet(isPresented: $showingSaveSheet) {
            SaveSequenceSheet(
                name: $saveSequenceName,
                description: $saveSequenceDesc,
                onSave: {
                    guard !saveSequenceName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    sequenceStore.saveSequence(name: saveSequenceName, description: saveSequenceDesc)
                    showingSaveSheet = false
                },
                onCancel: { showingSaveSheet = false }
            )
        }
        // Sequence manager sheet
        .sheet(isPresented: $showingManager) {
            SequenceManagerView(onDismiss: { showingManager = false })
                .environmentObject(sequenceStore)
                .environmentObject(cardStore)
                .frame(minWidth: 340, minHeight: 320)
        }
        // Drop target: accept card IDs dragged from the grid
        .dropDestination(for: String.self) { items, _ in
            for item in items {
                if let id = UUID(uuidString: item) {
                    sequenceStore.addToTray(cardID: id)
                }
            }
            return !items.isEmpty
        }
    }

    // MARK: - Subviews

    private var emptyTray: some View {
        Text("Drag cards here or tap + on a card to build your sequence.")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(10)
    }

    private var trayList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(orderedItems.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        TrayItemRow(
                            item: item,
                            card: cardStore.cards.first { $0.id == item.cardID },
                            onRemove: { sequenceStore.removeFromTray(id: item.id) },
                            onEditNote: { editingNoteForID = item.id }
                        )

                        if index < orderedItems.count - 1 {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: 220)
    }
}

// MARK: - Tray Item Row

private struct TrayItemRow: View {
    let item: StrategySequenceItem
    let card: KnowledgeCard?
    let onRemove: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(card?.kind.symbol ?? "?")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(card?.title ?? "Unknown Card")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            Button(action: onEditNote) {
                Image(systemName: "note.text")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help("Edit note")

            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 5).fill(.secondary.opacity(0.05)))
    }
}

// MARK: - Save Sheet

private struct SaveSequenceSheet: View {
    @Binding var name: String
    @Binding var description: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Save Sequence")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                TextField("e.g. Reliable API Integration", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { if !name.isEmpty { onSave() } }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description (optional)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                TextField("Brief description", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(18)
        .frame(width: 300)
    }
}
