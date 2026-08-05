import SwiftUI
import StrategyDeckCore

struct SettingsView: View {
    @EnvironmentObject var environment: AppEnvironment
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @State private var alertState: AlertState?
    @State private var showingExportSuccess = false
    @State private var defaultPinned = PanelFrameStore.savedPinned()

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .disabled(!launchAtLogin.isAvailable)

                if let err = launchAtLogin.lastError {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }

                Toggle("Pin panel by default", isOn: $defaultPinned)
                    .onChange(of: defaultPinned) { _, v in PanelFrameStore.save(pinned: v) }
            }

            Section("Global Shortcut") {
                HStack {
                    Text("Toggle panel")
                    Spacer()
                    Text("⌘⇧Space")
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.15)))
                }
                Text("Customizable shortcut configuration will be added in a future version.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Button("Export Cards & Sequences…") { exportData() }
                Button("Import Cards & Sequences…") { importData() }

                Divider()

                Button("Reset to Default Cards…", role: .destructive) {
                    alertState = .destructive(
                        title: "Reset to Default Cards?",
                        message: "Your custom cards will be permanently replaced with the built-in defaults. Saved sequences are not affected.",
                        confirmLabel: "Reset"
                    ) {
                        environment.cardStore.resetToSeed()
                    }
                }
            }

            Section("About") {
                Text("Strategy Deck — local-first, no account required.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 360, idealWidth: 400)
        .alertState($alertState)
    }

    // MARK: - Import / Export

    private func exportData() {
        let sequences = environment.sequenceStore.savedSequences
        let library = environment.cardStore.exportLibrary(sequences: sequences)
        guard let encoded = try? environment.importExport.export(library) else {
            alertState = .error(title: "Export Failed", "Could not encode the data for export.")
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "strategy-deck-export.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try encoded.write(to: url, options: [.atomic])
            } catch {
                alertState = .error(error)
            }
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let imported = try environment.importExport.importFile(at: url)
                alertState = AlertState(
                    title: "Import \(imported.cards.count) card(s)?",
                    message: "This will merge the imported cards and sequences into your library.",
                    primaryButton: nil,
                    primaryLabel: "Import"
                ) {
                    environment.cardStore.importLibrary(imported, merging: true)
                    environment.sequenceStore.importSequences(imported.sequences, merging: true)
                }
            } catch {
                alertState = .error(error)
            }
        }
    }
}
