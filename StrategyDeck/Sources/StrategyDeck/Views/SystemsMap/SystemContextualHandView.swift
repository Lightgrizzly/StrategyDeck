import SwiftUI
import StrategyDeckCore

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

    /// "Unapplied" cards — the automatic engine landed on `.pending` (no
    /// rule strongly recommends this card and nothing marks it playable in
    /// a way that means anything yet) and nothing has ever set an explicit
    /// status for it. They deliberately don't appear here at all — the
    /// Contextual Hand only shows cards that either the rules actively flag
    /// (Recommended/Locked/Disabled) or the user has explicitly touched.
    /// The Full Library still lists them (collapsed by default, like
    /// Irrelevant) so there's always a way to find and apply one.
    private var visibleEntries: [ContextualHandEntry] {
        entries.filter { !($0.evaluation.effectiveStatus == .pending && !$0.evaluation.isOverridden) }
    }

    private var unappliedCount: Int { entries.count - visibleEntries.count }

    /// Which individual status (or custom status) a card group sorts
    /// into — mirrors `SystemCardLibraryView`'s grouping, but every status
    /// gets its own section here: unlike the Full Library, adjacent
    /// built-ins that share a `groupTitle` (Locked/Disabled,
    /// Exhausted/Resolved) are never merged, and there's no per-group cap.
    private enum StatusGroupKey: Hashable {
        case builtIn(SystemCardStatus)
        case custom(String)
    }

    private var groupedEntries: [(key: StatusGroupKey, title: String, color: Color, entries: [ContextualHandEntry])] {
        let groups = Dictionary(grouping: visibleEntries) { entry -> StatusGroupKey in
            if let customID = entry.evaluation.effectiveCustomStatusID { return .custom(customID) }
            return .builtIn(entry.evaluation.effectiveStatus)
        }
        var result: [(StatusGroupKey, String, Color, [ContextualHandEntry])] = []
        for status in SystemCardStatus.allCases.sorted(by: { $0.groupRank < $1.groupRank }) {
            let key = StatusGroupKey.builtIn(status)
            guard let inGroup = groups[key], !inGroup.isEmpty else { continue }
            let title = statusCatalog.labelOverrides[status.rawValue] ?? status.displayName
            result.append((key, title, status.arenaColor, inGroup))
        }
        for custom in statusCatalog.customStatuses.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            let key = StatusGroupKey.custom(custom.id)
            guard let inGroup = groups[key], !inGroup.isEmpty else { continue }
            result.append((key, custom.name, custom.colorToken.color, inGroup))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if visibleEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(groupedEntries, id: \.key) { entryGroup in
                            group("\(entryGroup.title) (\(entryGroup.entries.count))", color: entryGroup.color, entries: entryGroup.entries)
                        }
                        if unappliedCount > 0 {
                            unappliedHint
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
            if unappliedCount > 0 {
                Text("\(unappliedCount) unapplied card\(unappliedCount == 1 ? "" : "s") for \(selectionLabel) — not yet added to the game.")
                    .font(.system(size: 10)).foregroundStyle(AC.textDim)
            } else {
                Text("No cards in the selected deck currently target \(selectionLabel).")
                    .font(.system(size: 10)).foregroundStyle(AC.textDim)
            }
            Button("Browse Full Deck", action: onOpenFullLibrary).buttonStyle(ArenaOutlineButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private var unappliedHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.dashed").font(.system(size: 9)).foregroundStyle(AC.textGhost)
            Text("\(unappliedCount) unapplied card\(unappliedCount == 1 ? "" : "s") hidden — visible in the Full Library.")
                .font(.system(size: 9)).foregroundStyle(AC.textDim)
        }
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
