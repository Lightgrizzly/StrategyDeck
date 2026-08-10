import SwiftUI
import StrategyDeckCore

/// The compact, two-row workspace header — replaces the old 4-row header
/// plus the standalone scenario strip. Deck and scenario controls live here
/// as menus rather than permanent full-width sections.
struct SystemsMapCompactHeaderView: View {
    let mapTitle: String
    let folderID: UUID?
    let primaryGoal: String
    let deckName: String
    let isUsingScenarioDeckOverride: Bool
    let isFocusMode: Bool
    let scenarios: [SystemScenario]
    let selectedScenarioID: UUID?

    let onNavigateFolder: (UUID?) -> Void
    let onClose: () -> Void
    let onRenameMap: () -> Void
    let onToggleFocusMode: () -> Void
    let onExport: () -> Void
    let onOpenDeckPicker: () -> Void
    let onOverrideDeckForScenario: () -> Void
    let onResetDeckOverride: () -> Void
    let onSelectScenario: (UUID) -> Void
    let onNewScenario: () -> Void
    let onDuplicateCurrentScenario: () -> Void
    let onRenameCurrentScenario: () -> Void
    let onSetCurrentScenarioDefault: () -> Void
    let onResetCurrentScenario: () -> Void
    let onDeleteCurrentScenario: () -> Void
    let onCompareScenarios: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textSub)

                SystemMapBreadcrumbView(folderID: folderID, onNavigate: onNavigateFolder)

                Button(action: onRenameMap) {
                    Text(mapTitle.uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.cyan)
                        .kerning(1)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onToggleFocusMode) {
                    Image(systemName: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(isFocusMode ? AC.cyan : AC.textDim)
                .help(isFocusMode ? "Exit Focus Mode (⌘⇧F)" : "Focus Mode (⌘⇧F)")

                Button(action: onExport) {
                    Label("EXPORT", systemImage: "square.and.arrow.up")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.5)))
            }

            HStack(spacing: 14) {
                deckMenu
                SystemScenarioSelectorView(
                    scenarios: scenarios,
                    selectedScenarioID: selectedScenarioID,
                    selectedElementLabel: nil,
                    onSelectScenario: onSelectScenario,
                    onNewScenario: onNewScenario,
                    onDuplicateCurrentScenario: onDuplicateCurrentScenario,
                    onRenameCurrentScenario: onRenameCurrentScenario,
                    onSetCurrentScenarioDefault: onSetCurrentScenarioDefault,
                    onResetCurrentScenario: onResetCurrentScenario,
                    onDeleteCurrentScenario: onDeleteCurrentScenario,
                    onCompareScenarios: onCompareScenarios
                )
                if !primaryGoal.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered").font(.system(size: 9)).foregroundStyle(AC.gold)
                        Text("Goal: \(primaryGoal)").font(.system(size: 11)).foregroundStyle(AC.textSub).lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AC.surface)
    }

    private var deckMenu: some View {
        Menu {
            Button("Choose Deck", action: onOpenDeckPicker)
            if isUsingScenarioDeckOverride {
                Button("Reset to Map Deck", action: onResetDeckOverride)
            } else {
                Button("Override for This Scenario", action: onOverrideDeckForScenario)
            }
            Divider()
            Button("Manage Decks", action: onOpenDeckPicker)
        } label: {
            HStack(spacing: 4) {
                Text("Deck:").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(0.5)
                Text(deckName).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.cyan)
                if isUsingScenarioDeckOverride {
                    Text("OVERRIDE").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(AC.gold)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(AC.goldSoft))
                }
                Image(systemName: "chevron.down").font(.system(size: 7)).foregroundStyle(AC.cyan)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
