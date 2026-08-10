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
                MenuBarIconView(size: 13)
                    .foregroundStyle(AC.cyan)
                Text("STRATEGY DECK")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.text)
                    .kerning(1.5)
                Spacer()
                Text("\(environment.cardStore.cards.count) CARDS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)

            if environment.sequenceStore.trayItems.isEmpty {
                Text("No cards selected.")
                    .font(.system(size: 11))
                    .foregroundStyle(AC.textDim)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                let items = environment.sequenceStore.trayItems.sorted { $0.order < $1.order }
                let cards = environment.cardStore.cards
                VStack(alignment: .leading, spacing: 2) {
                    ArenaSectionLabel(text: "Current Sequence")
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                    ForEach(items.prefix(6)) { item in
                        if let card = cards.first(where: { $0.id == item.cardID }) {
                            Text("→ \(card.title)")
                                .font(.system(size: 11))
                                .foregroundStyle(AC.textSub)
                                .padding(.horizontal, 16)
                        }
                    }
                    if items.count > 6 {
                        Text("… and \(items.count - 6) more")
                            .font(.system(size: 10))
                            .foregroundStyle(AC.textDim)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 6)
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)

            Button("Show Panel  ⌘⇧Space") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(AC.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button("Settings…") { showingSettings = true }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(AC.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Rectangle().fill(AC.borderDim).frame(height: 1)

            Button("Quit Strategy Deck") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(AC.threat.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(width: 240)
        .background(AC.bg)
        .colorScheme(.dark)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(environment)
        }
    }
}
