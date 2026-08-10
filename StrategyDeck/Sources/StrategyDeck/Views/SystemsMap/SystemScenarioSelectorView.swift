import SwiftUI
import StrategyDeckCore

/// A scenario is a different configuration/condition of the same shared
/// workflow — not a moment in a sequence — so this is a compact switcher,
/// not a stepper. Lives in the compact workspace header; folds scenario
/// switching and the current scenario's actions into one menu instead of a
/// permanent full-width strip.
struct SystemScenarioSelectorView: View {
    let scenarios: [SystemScenario]
    let selectedScenarioID: UUID?
    let selectedElementLabel: String?
    let onSelectScenario: (UUID) -> Void
    let onNewScenario: () -> Void
    let onDuplicateCurrentScenario: () -> Void
    let onRenameCurrentScenario: () -> Void
    let onSetCurrentScenarioDefault: () -> Void
    let onResetCurrentScenario: () -> Void
    let onDeleteCurrentScenario: () -> Void
    let onCompareScenarios: () -> Void

    private var currentScenario: SystemScenario? {
        scenarios.first(where: { $0.id == selectedScenarioID }) ?? scenarios.first
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("SCENARIO:")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
                .kerning(0.5)

            Menu {
                ForEach(scenarios.sorted { $0.order < $1.order }) { scenario in
                    Button {
                        onSelectScenario(scenario.id)
                    } label: {
                        if scenario.id == currentScenario?.id {
                            Label(scenario.name, systemImage: "checkmark")
                        } else {
                            Text(scenario.name)
                        }
                    }
                }
                Divider()
                Button("New Scenario", action: onNewScenario)
                Button("Duplicate Scenario", action: onDuplicateCurrentScenario)
                Button("Compare Scenarios", action: onCompareScenarios).disabled(scenarios.count < 2)
                Divider()
                Button("Rename Scenario", action: onRenameCurrentScenario)
                Button("Set As Default", action: onSetCurrentScenarioDefault)
                Button("Reset Scenario", action: onResetCurrentScenario)
                Divider()
                Button("Delete Scenario", role: .destructive, action: onDeleteCurrentScenario)
                    .disabled(scenarios.count <= 1)
            } label: {
                HStack(spacing: 3) {
                    if currentScenario?.isDefault == true {
                        Image(systemName: "star.fill").font(.system(size: 7))
                    }
                    Text(currentScenario?.name ?? "—").font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 7))
                }
                .foregroundStyle(AC.cyan)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .help(currentScenario?.description.isEmpty == false ? currentScenario!.description : "")
    }
}
