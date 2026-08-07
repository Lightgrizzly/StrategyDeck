import SwiftUI

/// A deliberately higher-friction delete confirmation than a plain OK/Cancel
/// alert — the exact item name must be typed before the destructive button
/// enables. Reserved for deletions that are hard or impossible to undo (a
/// card, an entire deck and everything nested under it).
struct TypedDeleteConfirmationSheet: View {
    let title: String
    let itemName: String
    let message: String
    var confirmLabel: String = "Delete"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typedText = ""

    private var matches: Bool {
        typedText.trimmingCharacters(in: .whitespacesAndNewlines) == itemName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(AC.threat)
                .kerning(1.5)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(AC.textSub)

            VStack(alignment: .leading, spacing: 6) {
                Text("Type “\(itemName)” to confirm:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AC.text)
                TextField(itemName, text: $typedText)
                    .arenaFieldStyle()
                    .onSubmit { if matches { onConfirm() } }
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(confirmLabel, action: onConfirm)
                    .buttonStyle(ArenaButtonStyle(color: AC.threat, isDisabled: !matches))
                    .disabled(!matches)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .background(AC.bg)
        .colorScheme(.dark)
    }
}
