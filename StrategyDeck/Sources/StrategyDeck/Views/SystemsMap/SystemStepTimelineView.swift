import SwiftUI
import StrategyDeckCore

/// Step strip + "Next Step" action + a compact "Changes This Step" summary.
/// Mirrors the Duel Board's `ArenaTurnBar` timeline strip.
struct SystemStepTimelineView: View {
    let steps: [SystemStep]
    let currentStepID: UUID?
    let isViewingLatest: Bool
    let onSelectStep: (UUID) -> Void
    let onReturnToLatest: () -> Void
    let onNextStep: () -> Void
    let onChangeSelected: (SystemChangeEntry) -> Void

    private var currentStep: SystemStep? {
        steps.first(where: { $0.id == currentStepID }) ?? steps.last
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 10)).foregroundStyle(AC.cyan.opacity(0.7))
                Text("STEP \((currentStep?.index ?? 0) + 1) / \(steps.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.cyan)
                    .kerning(1)

                if !isViewingLatest {
                    Text("VIEWING HISTORY")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(AC.gold)
                        .kerning(1)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AC.goldSoft))
                    Button("Return to Latest", action: onReturnToLatest)
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.gold.opacity(0.6)))
                }

                Spacer()

                Button(action: onNextStep) {
                    HStack(spacing: 5) {
                        Text("NEXT STEP").font(.system(size: 9, weight: .black, design: .monospaced)).kerning(1.2)
                        Image(systemName: "arrow.right.circle.fill").font(.system(size: 13))
                    }
                }
                .buttonStyle(ArenaButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(steps.sorted { $0.index < $1.index }) { step in
                        let isCurrent = step.id == (currentStepID ?? steps.last?.id)
                        Button(action: { onSelectStep(step.id) }) {
                            VStack(spacing: 2) {
                                Text("\(step.index + 1)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isCurrent ? AC.cyan : AC.textDim)
                                Circle()
                                    .fill(step.cardPlays.isEmpty ? Color.clear : (isCurrent ? AC.cyan : AC.textDim))
                                    .frame(width: 3, height: 3)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isCurrent ? AC.cyan.opacity(0.15) : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(isCurrent ? AC.cyan.opacity(0.55) : AC.borderDim, lineWidth: 0.75))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            if let step = currentStep, !step.changes.isEmpty {
                changesSummary(step)
            }
        }
        .background(AC.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(AC.borderDim).frame(height: 1) }
    }

    private func changesSummary(_ step: SystemStep) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("CHANGES:")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(0.5)
                ForEach(step.changes) { change in
                    Button(action: { onChangeSelected(change) }) {
                        HStack(spacing: 3) {
                            Image(systemName: change.kind.systemImage).font(.system(size: 8))
                            Text(change.label).font(.system(size: 9))
                        }
                        .foregroundStyle(AC.textSub)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(AC.surfaceHi))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}
