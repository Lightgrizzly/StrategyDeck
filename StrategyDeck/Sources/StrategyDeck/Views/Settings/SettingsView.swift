import SwiftUI
import StrategyDeckCore

struct SettingsView: View {
    @EnvironmentObject var environment: AppEnvironment
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @State private var alertState: AlertState?
    @State private var showingExportSuccess = false
    @State private var defaultPinned = PanelFrameStore.savedPinned()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("SETTINGS")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.cyan)
                    .kerning(2)
                    .padding(.top, 4)

                settingsSection("Startup") {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    .tint(AC.cyan)
                    .disabled(!launchAtLogin.isAvailable)

                    if let err = launchAtLogin.lastError {
                        Text(err)
                            .font(.system(size: 10))
                            .foregroundStyle(AC.threat)
                    }

                    Toggle("Pin panel by default", isOn: $defaultPinned)
                        .tint(AC.cyan)
                        .onChange(of: defaultPinned) { _, v in PanelFrameStore.save(pinned: v) }
                }

                settingsSection("Global Shortcut") {
                    HStack {
                        Text("Toggle panel")
                        Spacer()
                        Text("⌘⇧Space")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AC.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                AngularCardShape(cornerRadius: 4, cornerCut: 6)
                                    .fill(AC.surfaceHi)
                            )
                    }
                    Text("Customizable shortcut configuration will be added in a future version.")
                        .font(.system(size: 10))
                        .foregroundStyle(AC.textDim)
                }

                settingsSection("Data") {
                    Button("Export Cards & Sequences…") { exportData() }
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                    Button("Import Cards & Sequences…") { importData() }
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))

                    Rectangle().fill(AC.borderDim).frame(height: 1).padding(.vertical, 2)

                    Button("Reset to Default Cards…") {
                        alertState = .destructive(
                            title: "Reset to Default Cards?",
                            message: "Your custom cards will be permanently replaced with the built-in defaults. Saved sequences are not affected.",
                            confirmLabel: "Reset"
                        ) {
                            environment.cardStore.resetToSeed()
                        }
                    }
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.threat.opacity(0.55)))
                    .foregroundStyle(AC.threat)
                }

                settingsSection("About") {
                    Text("Strategy Deck — local-first, no account required.")
                        .font(.system(size: 11))
                        .foregroundStyle(AC.textSub)
                }
            }
            .padding(18)
        }
        .background(AC.bg)
        .colorScheme(.dark)
        .frame(minWidth: 360, idealWidth: 400)
        .alertState($alertState)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ArenaSectionLabel(text: title)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .foregroundStyle(AC.text)
        }
        .padding(12)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(AC.surface)
        )
        .overlay(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .stroke(AC.borderDim, lineWidth: 0.75)
        )
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
