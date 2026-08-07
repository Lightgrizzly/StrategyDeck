import SwiftUI

/// Minimal alert model for presenting errors and confirmations.
struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var primaryButton: ButtonRole?
    var primaryLabel: String = "OK"
    var action: (() -> Void)?

    static func error(_ error: Error) -> AlertState {
        AlertState(title: "Error", message: error.localizedDescription)
    }

    static func error(title: String = "Error", _ message: String) -> AlertState {
        AlertState(title: title, message: message)
    }

    static func destructive(
        title: String,
        message: String,
        confirmLabel: String = "Delete",
        action: @escaping () -> Void
    ) -> AlertState {
        AlertState(title: title, message: message, primaryButton: .destructive, primaryLabel: confirmLabel, action: action)
    }
}

extension View {
    func alertState(_ state: Binding<AlertState?>) -> some View {
        alert(state.wrappedValue?.title ?? "", isPresented: Binding(
            get: { state.wrappedValue != nil },
            set: { if !$0 { state.wrappedValue = nil } }
        )) {
            Button(state.wrappedValue?.primaryLabel ?? "OK", role: state.wrappedValue?.primaryButton) {
                state.wrappedValue?.action?()
                state.wrappedValue = nil
            }
            if state.wrappedValue?.action != nil {
                Button("Cancel", role: .cancel) { state.wrappedValue = nil }
            }
        } message: {
            Text(state.wrappedValue?.message ?? "")
        }
    }
}
