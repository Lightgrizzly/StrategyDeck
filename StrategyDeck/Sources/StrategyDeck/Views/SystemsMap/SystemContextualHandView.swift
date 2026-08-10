import SwiftUI
import StrategyDeckCore

/// The three display levels the card area beneath the diagram can be in.
/// Selecting a node no longer renders the whole deck by default — the
/// Contextual Hand is the everyday view; the Full Library is opened
/// intentionally.
///
/// NOTE: still referenced by `SystemsMapTabView`'s `.collapsed` drawer case
/// until Task 10 deletes that whole `switch drawerState` block wholesale —
/// see plan Task 5 Step 4's note that `drawerState` remains
/// `SystemCardDrawerState`-typed at this point in the sequence.
enum SystemCardDrawerState: Equatable {
    case collapsed
    case contextualHand
    case fullLibrary
}

/// The always-cheap-to-compute summary shown when the drawer is collapsed.
/// Still used by `SystemsMapTabView`'s `.collapsed` case until Task 10.
struct SystemDrawerCollapsedSummaryView: View {
    let selectionLabel: String
    let statusCounts: [(status: SystemCardStatus, count: Int)]
    let statusCatalog: StatusCatalog
    let onOpenHand: () -> Void
    let onBrowseFullDeck: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ArenaSectionLabel(text: "Cards for \(selectionLabel)", icon: "square.stack.3d.up")
            HStack(spacing: 10) {
                ForEach(statusCounts.filter { $0.count > 0 }, id: \.status) { entry in
                    HStack(spacing: 3) {
                        Text("\(entry.count)").font(.system(size: 10, weight: .black, design: .monospaced))
                        Text(statusCatalog.labelOverrides[entry.status.rawValue] ?? entry.status.displayName)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(entry.status.arenaColor)
                }
            }
            Spacer()
            Button("Open Contextual Hand", action: onOpenHand)
                .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
            Button("Browse Full Deck", action: onBrowseFullDeck)
                .buttonStyle(ArenaOutlineButtonStyle())
        }
        .padding(10)
        .background(AC.surface)
    }
}

/// The compact, ranked subset of the selected deck — the everyday view for
/// acting on the current selection without the whole deck rendering. Lives
/// permanently as the context panel's CARDS tab.
struct SystemContextualHandView: View {
    let entries: [ContextualHandEntry]
    let totalRelevantCount: Int
    let selectionLabel: String
    let statusCatalog: StatusCatalog
    let isEditable: Bool
    let onViewDetails: (KnowledgeCard) -> Void
    let onEditCard: ((KnowledgeCard) -> Void)?
    let onApplyIntervention: (KnowledgeCard) -> Void
    let onChangeStatus: (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void
    let onResetToAutomatic: (KnowledgeCard) -> Void
    let onTogglePin: (KnowledgeCard) -> Void
    let onSetPinScope: ((KnowledgeCard, PinScope) -> Void)?
    let onAssignToSelectedElement: ((KnowledgeCard) -> Void)?
    let onOpenFullLibrary: () -> Void

    init(
        entries: [ContextualHandEntry],
        totalRelevantCount: Int,
        selectionLabel: String,
        statusCatalog: StatusCatalog,
        isEditable: Bool,
        onViewDetails: @escaping (KnowledgeCard) -> Void,
        onEditCard: ((KnowledgeCard) -> Void)? = nil,
        onApplyIntervention: @escaping (KnowledgeCard) -> Void,
        onChangeStatus: @escaping (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void,
        onResetToAutomatic: @escaping (KnowledgeCard) -> Void,
        onTogglePin: @escaping (KnowledgeCard) -> Void,
        onSetPinScope: ((KnowledgeCard, PinScope) -> Void)? = nil,
        onAssignToSelectedElement: ((KnowledgeCard) -> Void)? = nil,
        onOpenFullLibrary: @escaping () -> Void
    ) {
        self.entries = entries
        self.totalRelevantCount = totalRelevantCount
        self.selectionLabel = selectionLabel
        self.statusCatalog = statusCatalog
        self.isEditable = isEditable
        self.onViewDetails = onViewDetails
        self.onEditCard = onEditCard
        self.onApplyIntervention = onApplyIntervention
        self.onChangeStatus = onChangeStatus
        self.onResetToAutomatic = onResetToAutomatic
        self.onTogglePin = onTogglePin
        self.onSetPinScope = onSetPinScope
        self.onAssignToSelectedElement = onAssignToSelectedElement
        self.onOpenFullLibrary = onOpenFullLibrary
    }

    private var activeEntries: [ContextualHandEntry] { entries.filter { $0.evaluation.effectiveStatus == .active } }
    private var availableEntries: [ContextualHandEntry] {
        Array(entries.filter { $0.evaluation.isPlayable }.prefix(10))
    }
    private var blockedEntries: [ContextualHandEntry] {
        Array(entries.filter { [.locked, .disabled].contains($0.evaluation.effectiveStatus) }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !activeEntries.isEmpty {
                            group("Active", color: AC.cyan, entries: activeEntries)
                        }
                        if !availableEntries.isEmpty {
                            group("Available", color: AC.available, entries: availableEntries)
                        }
                        if !blockedEntries.isEmpty {
                            group("Blocked", color: AC.threat, entries: blockedEntries)
                        }
                    }
                    .padding(10)
                }
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)
            HStack {
                Button("View All \(totalRelevantCount) Relevant Cards", action: onOpenFullLibrary)
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                Button("Browse Full Deck", action: onOpenFullLibrary)
                    .buttonStyle(ArenaOutlineButtonStyle())
                Spacer()
            }
            .padding(10)
            .background(AC.surface)
        }
        .background(AC.bg)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised").font(.system(size: 22)).foregroundStyle(AC.textGhost)
            Text("No contextual cards found").font(.system(size: 12, weight: .semibold)).foregroundStyle(AC.textSub)
            Text("No cards in the selected deck currently target \(selectionLabel).")
                .font(.system(size: 10)).foregroundStyle(AC.textDim)
            Button("Browse Full Deck", action: onOpenFullLibrary).buttonStyle(ArenaOutlineButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private func group(_ title: String, color: Color, entries: [ContextualHandEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ArenaSectionLabel(text: title, color: color)
            ForEach(entries) { entry in
                ContextualHandRow(
                    entry: entry,
                    statusCatalog: statusCatalog,
                    isEditable: isEditable,
                    onViewDetails: { onViewDetails(entry.card) },
                    onEdit: onEditCard.map { edit in { edit(entry.card) } },
                    onApplyIntervention: { onApplyIntervention(entry.card) },
                    onChangeStatus: { status, customID, scope in onChangeStatus(entry.card, status, customID, scope) },
                    onResetToAutomatic: { onResetToAutomatic(entry.card) },
                    onTogglePin: { onTogglePin(entry.card) },
                    onSetPinScope: onSetPinScope.map { setScope in { scope in setScope(entry.card, scope) } },
                    onAssignToSelectedElement: onAssignToSelectedElement.map { assign in { assign(entry.card) } }
                )
            }
        }
    }
}

/// One compact, scannable row — "[Card Name] — reason" — not a full card
/// view, matching the product spec's "compact and easy to scan" ask.
private struct ContextualHandRow: View {
    let entry: ContextualHandEntry
    let statusCatalog: StatusCatalog
    let isEditable: Bool
    let onViewDetails: () -> Void
    let onEdit: (() -> Void)?
    let onApplyIntervention: () -> Void
    let onChangeStatus: (SystemCardStatus, String?, SystemOverrideScope) -> Void
    let onResetToAutomatic: () -> Void
    let onTogglePin: () -> Void
    let onSetPinScope: ((PinScope) -> Void)?
    let onAssignToSelectedElement: (() -> Void)?

    private var display: StatusDisplayInfo { entry.evaluation.displayInfo(catalog: statusCatalog) }

    var body: some View {
        HStack(spacing: 6) {
            if entry.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(AC.gold)
            }
            Image(systemName: display.icon).font(.system(size: 9)).foregroundStyle(display.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.card.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.text)
                if let reason = entry.reasons.first {
                    Text(reason).font(.system(size: 9)).foregroundStyle(AC.textDim)
                }
            }
            Spacer(minLength: 0)
            if isEditable, entry.evaluation.isPlayable {
                Button("Apply", action: onApplyIntervention).buttonStyle(ArenaOutlineButtonStyle(color: AC.available.opacity(0.6)))
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(AC.surface))
        .contextMenu {
            if let onAssignToSelectedElement {
                Button("Assign to Selected Element", action: onAssignToSelectedElement)
                Divider()
            }
            Button("View Details", action: onViewDetails)
            if isEditable, let onEdit {
                Button("Edit", action: onEdit)
            }
            if isEditable, entry.evaluation.isPlayable {
                Button("Apply Intervention", action: onApplyIntervention)
            }
            Divider()
            Button(entry.isPinned ? "Unpin from Contextual Hand" : "Pin to Contextual Hand", action: onTogglePin)
            if entry.isPinned, let onSetPinScope {
                Menu("Change Pin Scope") {
                    ForEach(PinScope.allCases, id: \.self) { scope in
                        Button(scope.displayName) { onSetPinScope(scope) }
                    }
                }
            }
            if entry.evaluation.isOverridden {
                Button("Reset to Automatic", action: onResetToAutomatic)
            }
        }
    }
}
