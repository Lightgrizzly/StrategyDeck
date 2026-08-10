import SwiftUI
import StrategyDeckCore

/// The two contextual categories the right-hand panel switches between.
/// There is deliberately no separate ISSUES tab — issue information lives
/// inside DETAILS, next to the element it's attached to.
enum ContextPanelTab: String, CaseIterable {
    case details = "DETAILS"
    case cards = "CARDS"
}

/// Replaces the permanent inspector column + always-visible issues panel.
/// Shows exactly one contextual category at a time behind a `SELECTED`
/// header; when nothing is selected, DETAILS becomes a system-wide
/// overview instead of an empty form.
struct SystemContextPanelView: View {
    let selectionLabel: String
    let selectionKindLabel: String?
    let scenarioName: String
    let issueCount: Int
    let blockerCount: Int
    let activeCardCount: Int
    let availableCardCount: Int
    @Binding var tab: ContextPanelTab

    // DETAILS
    let hasSelection: Bool
    let inspector: SystemElementInspectorView
    let issuesPanel: SystemIssuesPanelView
    let systemOverview: SystemOverviewContent

    // CARDS
    let contextualHand: SystemContextualHandView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            selectedHeader
            Rectangle().fill(AC.borderDim).frame(height: 1)
            tabBar
            Rectangle().fill(AC.borderDim).frame(height: 1)

            switch tab {
            case .details:
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if hasSelection {
                            inspector
                            Rectangle().fill(AC.borderDim).frame(height: 1)
                            issuesPanel
                        } else {
                            systemOverview
                        }
                    }
                    .padding(12)
                }
            case .cards:
                contextualHand
            }
        }
        .frame(minWidth: 260, idealWidth: 320, maxWidth: 420, maxHeight: .infinity)
        .background(AC.glassPanel)
    }

    private var selectedHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(hasSelection ? "SELECTED" : "SYSTEM OVERVIEW")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
                .kerning(1)
            Text(selectionLabel).font(.system(size: 13, weight: .bold)).foregroundStyle(AC.text)
            if let selectionKindLabel {
                Text(selectionKindLabel).font(.system(size: 9)).foregroundStyle(AC.textSub)
            }
            HStack(spacing: 10) {
                Text("Scenario: \(scenarioName)").font(.system(size: 9)).foregroundStyle(AC.textDim)
                if issueCount > 0 {
                    Text("\(issueCount) Issue\(issueCount == 1 ? "" : "s")").font(.system(size: 9, weight: .semibold)).foregroundStyle(AC.threat)
                }
                if blockerCount > 0 {
                    Text("\(blockerCount) Blocker\(blockerCount == 1 ? "" : "s")").font(.system(size: 9, weight: .semibold)).foregroundStyle(AC.gold)
                }
            }
            HStack(spacing: 10) {
                Text("\(activeCardCount) Active").font(.system(size: 9, weight: .semibold)).foregroundStyle(AC.cyan)
                Text("\(availableCardCount) Available").font(.system(size: 9, weight: .semibold)).foregroundStyle(AC.available)
            }
        }
        .padding(10)
        .background(AC.surface)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ContextPanelTab.allCases, id: \.self) { candidate in
                Button(action: { tab = candidate }) {
                    Text(candidate.rawValue)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .kerning(0.5)
                        .foregroundStyle(tab == candidate ? AC.cyan : AC.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) {
                            if tab == candidate {
                                Rectangle().fill(AC.cyan).frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .background(AC.surface)
    }
}

/// The lightweight state shown in DETAILS when nothing on the diagram is
/// selected — map-level counts instead of an empty property form.
struct SystemOverviewContent: View {
    let stockCount: Int
    let flowCount: Int
    let constraintCount: Int
    let activeIssueCount: Int
    let onViewCards: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a stock, flow, relationship, or condition to inspect it.")
                .font(.system(size: 11))
                .foregroundStyle(AC.textSub)
            VStack(alignment: .leading, spacing: 4) {
                Text("SYSTEM").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                Text("\(stockCount) Stock\(stockCount == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(AC.text)
                Text("\(flowCount) Flow\(flowCount == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(AC.text)
                Text("\(constraintCount) Constraint\(constraintCount == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(AC.text)
                Text("\(activeIssueCount) Active Issue\(activeIssueCount == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(activeIssueCount > 0 ? AC.threat : AC.text)
            }
            Button("View System Cards", action: onViewCards).buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
        }
    }
}
