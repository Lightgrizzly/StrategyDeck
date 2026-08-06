import SwiftUI
import StrategyDeckCore

/// Replaces the step timeline: a scenario selector strip. A scenario is a
/// different configuration/condition of the same shared workflow — not a
/// moment in a sequence — so there is no "next"/"previous" here, just
/// selection among scenarios that all coexist.
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 10)).foregroundStyle(AC.cyan.opacity(0.7))
                Text("SCENARIO")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.cyan)
                    .kerning(1)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(scenarios.sorted { $0.order < $1.order }) { scenario in
                            ScenarioPill(
                                scenario: scenario,
                                isSelected: scenario.id == (selectedScenarioID ?? currentScenario?.id)
                            ) {
                                onSelectScenario(scenario.id)
                            }
                        }
                    }
                }

                Button(action: onNewScenario) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.cyan)
                .help("New Scenario")

                Spacer()

                Button(action: onCompareScenarios) {
                    Label("COMPARE", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                .disabled(scenarios.count < 2)

                Menu {
                    Button("Duplicate Scenario", action: onDuplicateCurrentScenario)
                    Button("Rename Scenario", action: onRenameCurrentScenario)
                    Button("Set As Default", action: onSetCurrentScenarioDefault)
                    Button("Reset Scenario", action: onResetCurrentScenario)
                    Divider()
                    Button("Delete Scenario", role: .destructive, action: onDeleteCurrentScenario)
                        .disabled(scenarios.count <= 1)
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 13))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(AC.textSub)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if let selectedElementLabel {
                HStack(spacing: 5) {
                    Image(systemName: "scope").font(.system(size: 9)).foregroundStyle(AC.textDim)
                    Text("Selected Element: \(selectedElementLabel)")
                        .font(.system(size: 10))
                        .foregroundStyle(AC.textSub)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(AC.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(AC.borderDim).frame(height: 1) }
    }
}

private struct ScenarioPill: View {
    let scenario: SystemScenario
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if scenario.isDefault {
                    Image(systemName: "star.fill").font(.system(size: 7))
                }
                Text(scenario.name.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .kerning(0.5)
                if !scenario.cardStatusOverrides.isEmpty || !scenario.elementOverrides.isEmpty || !scenario.flowOverrides.isEmpty {
                    Circle().fill(isSelected ? AC.bg : AC.cyan).frame(width: 4, height: 4)
                }
            }
            .foregroundStyle(isSelected ? AC.bg : AC.textSub)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? AC.cyan : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(isSelected ? AC.cyan : AC.borderDim, lineWidth: 0.75))
            )
        }
        .buttonStyle(.plain)
        .help(scenario.description.isEmpty ? scenario.name : scenario.description)
    }
}
