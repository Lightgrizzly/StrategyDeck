import SwiftUI
import StrategyDeckCore

/// The content shown inside the MenuBarExtra window.
///
/// Kept minimal — the full UI is in the floating panel.
struct MenuBarContentView: View {
    @EnvironmentObject var environment: AppEnvironment
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Strategy Deck")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(environment.cardStore.cards.count) cards")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if environment.sequenceStore.trayItems.isEmpty {
                Text("No cards selected.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                let items = environment.sequenceStore.trayItems.sorted { $0.order < $1.order }
                let cards = environment.cardStore.cards
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Sequence")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                    ForEach(items.prefix(6)) { item in
                        if let card = cards.first(where: { $0.id == item.cardID }) {
                            Text("→ \(card.title)")
                                .font(.system(size: 11))
                                .padding(.horizontal, 16)
                        }
                    }
                    if items.count > 6 {
                        Text("… and \(items.count - 6) more")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 6)
            }

            Divider()

            Button("Show Panel  ⌘⇧Space") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button("Settings…") { showingSettings = true }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            Button("Quit Strategy Deck") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(width: 240)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(environment)
        }
    }
}
