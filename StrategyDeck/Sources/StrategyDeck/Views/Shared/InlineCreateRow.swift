import SwiftUI

/// A compact "type a name, press Return or tap +" row — the fast
/// inline-creation pattern originally built for the Systems Map deck
/// picker, generalized here for reuse anywhere a new deck/suite/card just
/// needs a name (decks, suits, card titles).
struct InlineCreateRow: View {
    let placeholder: String
    var autoFocus: Bool = false
    let onCreate: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: $text)
                .arenaFieldStyle()
                .focused($isFocused)
                .onSubmit(submit)
            Button(action: submit) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(trimmed.isEmpty ? AC.textGhost : AC.cyan)
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
        }
        .onAppear { if autoFocus { isFocused = true } }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed)
        text = ""
        isFocused = true
    }
}
