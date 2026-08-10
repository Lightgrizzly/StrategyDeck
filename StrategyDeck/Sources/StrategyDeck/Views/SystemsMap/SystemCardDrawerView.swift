import SwiftUI
import StrategyDeckCore

/// The Full Library's three disclosure levels. Replaces the old
/// `SystemCardDrawerState` — Contextual Hand is no longer a drawer mode
/// (it's the context panel's permanent CARDS tab), so this only ever
/// concerns the Full Library.
enum LibraryDrawerState {
    case closed
    case peek
    case expanded
}

/// Bottom drawer for the complete card library. Closed by default so the
/// diagram keeps the majority of the screen; PEEK gives a compact
/// search/filter strip without paying for the full browsing UI; EXPANDED is
/// the existing `SystemCardLibraryView` unchanged.
struct SystemCardDrawerView: View {
    let state: LibraryDrawerState
    let onCycleState: () -> Void
    let onClose: () -> Void

    let deckName: String
    let statusCounts: [(status: SystemCardStatus, count: Int)]
    let statusCatalog: StatusCatalog

    // Forwarded straight through to SystemCardLibraryView when expanded.
    let cards: [KnowledgeCard]
    let suits: [CardSuit]
    let deckSuits: [CardSuit]
    let evaluations: [SystemCardEvaluation]
    let selectionLabel: String
    let isEditable: Bool
    let onViewDetails: (KnowledgeCard) -> Void
    let onEditCard: ((KnowledgeCard) -> Void)?
    let onApplyIntervention: (KnowledgeCard) -> Void
    let onChangeStatus: (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void
    let onResetToAutomatic: (KnowledgeCard) -> Void
    let onChooseAnotherDeck: (() -> Void)?
    let onCreateCard: (() -> Void)?
    let onAssignToSelectedElement: ((KnowledgeCard) -> Void)?
    let onDropCardToStatus: ((UUID, SystemCardStatus, String?) -> Void)?
    let onQuickCreateCard: ((String, String?, String) -> Void)?
    let onQuickCreateAndEdit: ((String, String?, String) -> Void)?
    let onCreateSuiteInline: ((String) -> CardSuit)?
    let onBulkCreateCards: (([(title: String, suitID: String?)]) -> Void)?
    let onManageStatuses: (() -> Void)?

    @State private var peekSearchText = ""
    @State private var pendingExpandSuitID: String?
    @State private var pendingExpandStatus: SystemCardStatus?

    private var totalCount: Int { cards.count }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AC.borderDim).frame(height: 1)
            switch state {
            case .closed:
                closedHandle
            case .peek:
                peekStrip
            case .expanded:
                expandedLibrary
            }
        }
        .background(AC.bg)
    }

    private var closedHandle: some View {
        Button(action: onCycleState) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up").font(.system(size: 10)).foregroundStyle(AC.textDim)
                Text("Cards · \(totalCount)").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(AC.textSub)
                Spacer()
                Image(systemName: "chevron.up").font(.system(size: 9)).foregroundStyle(AC.textDim)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(AC.surface)
    }

    private var peekStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onCycleState) {
                    HStack(spacing: 6) {
                        Text("Deck: \(deckName)").font(.system(size: 10, weight: .semibold)).foregroundStyle(AC.textSub)
                        ForEach(statusCounts.filter { $0.count > 0 }, id: \.status) { entry in
                            Text("\(entry.count) \(statusCatalog.labelOverrides[entry.status.rawValue] ?? entry.status.displayName)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(entry.status.arenaColor)
                        }
                        Spacer()
                        Image(systemName: "chevron.up").font(.system(size: 9)).foregroundStyle(AC.textDim)
                    }
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                TextField("Search…", text: $peekSearchText, onCommit: { onCycleState() })
                    .arenaFieldStyle()
                    .frame(maxWidth: 220)
                ForEach(statusCounts.filter { $0.count > 0 }.prefix(4), id: \.status) { entry in
                    Button(entry.status.displayName) {
                        pendingExpandStatus = entry.status
                        onCycleState()
                    }
                    .buttonStyle(ArenaOutlineButtonStyle(color: entry.status.arenaColor.opacity(0.55)))
                }
                Spacer()
                Button("Expand", action: onCycleState).buttonStyle(ArenaOutlineButtonStyle())
            }
        }
        .padding(10)
        .background(AC.surface)
    }

    @ViewBuilder
    private var expandedLibrary: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FULL LIBRARY").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
                Spacer()
                Button(action: onClose) { Image(systemName: "chevron.down.circle") }
                    .buttonStyle(.plain).foregroundStyle(AC.textDim).help("Close")
            }
            .padding(10)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            SystemCardLibraryView(
                cards: cards,
                suits: suits,
                deckSuits: deckSuits,
                evaluations: evaluations,
                statusCatalog: statusCatalog,
                selectionLabel: selectionLabel,
                isEditable: isEditable,
                initialSearchText: peekSearchText,
                initialStatusFilter: pendingExpandStatus,
                initialSuitIDs: pendingExpandSuitID.map { [$0] } ?? [],
                onViewDetails: onViewDetails,
                onEditCard: onEditCard,
                onApplyIntervention: onApplyIntervention,
                onChangeStatus: onChangeStatus,
                onResetToAutomatic: onResetToAutomatic,
                onChooseAnotherDeck: onChooseAnotherDeck,
                onCreateCard: onCreateCard,
                onAssignToSelectedElement: onAssignToSelectedElement,
                onDropCardToStatus: onDropCardToStatus,
                onQuickCreateCard: onQuickCreateCard,
                onQuickCreateAndEdit: onQuickCreateAndEdit,
                onCreateSuiteInline: onCreateSuiteInline,
                onBulkCreateCards: onBulkCreateCards,
                onManageStatuses: onManageStatuses,
                onCollapseDrawer: onClose
            )
        }
    }
}
