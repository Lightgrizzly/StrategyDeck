import SwiftUI
import StrategyDeckCore

/// Paste many titles at once, preview/edit/dedupe them, then create them
/// all in the current deck in one commit. Deliberately skips the full card
/// editor entirely — every row becomes a title-only card, enrichable later.
struct BulkAddCardsSheet: View {
    let suits: [CardSuit]
    /// Titles already present in the current deck, used for duplicate
    /// detection (case-insensitive, trimmed).
    let existingTitles: [String]
    let onCommit: (_ entries: [(title: String, suitID: String?)]) -> Void
    let onDone: () -> Void

    init(
        suits: [CardSuit],
        existingTitles: [String],
        initialSuitID: String? = nil,
        onCommit: @escaping (_ entries: [(title: String, suitID: String?)]) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.suits = suits
        self.existingTitles = existingTitles
        self.onCommit = onCommit
        self.onDone = onDone
        _sharedSuitID = State(initialValue: initialSuitID)
    }

    private struct Row: Identifiable {
        let id = UUID()
        var title: String
        var suitID: String?
        var skip: Bool
    }

    private enum Stage { case paste, preview, done }

    @State private var pastedText = ""
    @State private var rows: [Row] = []
    @State private var sharedSuitID: String?
    @State private var stage: Stage = .paste
    @State private var summary: (created: Int, skipped: Int) = (0, 0)

    private var existingTitlesLower: Set<String> {
        Set(existingTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("BULK ADD CARDS")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.cyan)
                    .kerning(1.5)
                Spacer()
                Button(stage == .done ? "Done" : "Cancel", action: onDone)
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.escape)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            switch stage {
            case .paste: pasteStage
            case .preview: previewStage
            case .done: doneStage
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .background(AC.bg)
        .colorScheme(.dark)
    }

    // MARK: - Paste

    private var pasteStage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste or type one card title per line.")
                .font(.system(size: 11))
                .foregroundStyle(AC.textSub)
            TextEditor(text: $pastedText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .arenaFieldStyle()
                .frame(minHeight: 220)
            HStack {
                Spacer()
                Button("Next: Preview", action: buildRows)
                    .buttonStyle(ArenaButtonStyle(isDisabled: parsedTitles.isEmpty))
                    .disabled(parsedTitles.isEmpty)
            }
        }
        .padding(16)
    }

    private var parsedTitles: [String] {
        pastedText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func buildRows() {
        var seenInBatch: Set<String> = []
        rows = parsedTitles.map { title in
            let key = title.lowercased()
            let isDuplicate = existingTitlesLower.contains(key) || seenInBatch.contains(key)
            seenInBatch.insert(key)
            return Row(title: title, suitID: sharedSuitID, skip: isDuplicate)
        }
        stage = .preview
    }

    // MARK: - Preview

    private func isDuplicate(_ row: Row) -> Bool {
        let key = row.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return false }
        if existingTitlesLower.contains(key) { return true }
        return rows.filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }.count > 1
    }

    private var previewStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(rows.count) rows — \(rows.filter { !$0.skip }.count) will be created")
                    .font(.system(size: 11))
                    .foregroundStyle(AC.textSub)
                Spacer()
                if !suits.isEmpty {
                    Text("SUITE FOR ALL")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.textDim)
                        .kerning(1)
                    Picker("Suite for all", selection: $sharedSuitID) {
                        Text("No Suite").tag(String?.none)
                        ForEach(suits.sorted { $0.displayOrder < $1.displayOrder }) { s in
                            Text(s.name).tag(Optional(s.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(AC.cyan)
                    .onChange(of: sharedSuitID) { _, newValue in
                        for i in rows.indices { rows[i].suitID = newValue }
                    }
                }
            }
            .padding(12)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach($rows) { $row in
                        rowView($row)
                    }
                }
                .padding(.horizontal, 12)
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)
            HStack {
                Button("Back", action: { stage = .paste })
                    .buttonStyle(ArenaOutlineButtonStyle())
                Spacer()
                let createCount = rows.filter { !$0.skip }.count
                Button("Create \(createCount) Card\(createCount == 1 ? "" : "s")", action: commit)
                    .buttonStyle(ArenaButtonStyle(isDisabled: createCount == 0))
                    .disabled(createCount == 0)
            }
            .padding(14)
            .background(AC.surface)
        }
    }

    private func rowView(_ row: Binding<Row>) -> some View {
        HStack(spacing: 8) {
            TextField("Title", text: row.title)
                .arenaFieldStyle()
            if !suits.isEmpty {
                Picker("Suite", selection: row.suitID) {
                    Text("No Suite").tag(String?.none)
                    ForEach(suits.sorted { $0.displayOrder < $1.displayOrder }) { s in
                        Text(s.name).tag(Optional(s.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(AC.cyan)
                .frame(width: 120)
            }
            if isDuplicate(row.wrappedValue) {
                Text("DUPLICATE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.gold)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(AC.goldSoft))
                Toggle("Keep", isOn: Binding(get: { !row.wrappedValue.skip }, set: { row.wrappedValue.skip = !$0 }))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 9))
                    .foregroundStyle(AC.textSub)
            }
            Button(action: { rows.removeAll { $0.id == row.wrappedValue.id } }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AC.threat.opacity(0.75))
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(AC.surface))
    }

    private func commit() {
        let toCreate = rows.filter { !$0.skip }
        let entries = toCreate.map { (title: $0.title, suitID: $0.suitID) }
        onCommit(entries)
        summary = (created: entries.count, skipped: rows.count - toCreate.count)
        stage = .done
    }

    // MARK: - Done

    private var doneStage: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(AC.available)
            Text("\(summary.created) card\(summary.created == 1 ? "" : "s") created")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AC.text)
            if summary.skipped > 0 {
                Text("\(summary.skipped) duplicate\(summary.skipped == 1 ? "" : "s") skipped")
                    .font(.system(size: 11))
                    .foregroundStyle(AC.textSub)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
