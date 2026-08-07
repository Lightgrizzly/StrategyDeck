import SwiftUI
import StrategyDeckCore

extension IssueSeverity {
    var arenaColor: Color {
        switch self {
        case .informational: return AC.textDim
        case .low: return AC.cyan
        case .medium: return AC.gold
        case .high: return .orange
        case .critical: return AC.threat
        }
    }
}

/// Issue drags reuse the app's existing "drag a plain String" convention
/// (see card drag-and-drop) with a prefix so a drop target can tell an
/// issue payload apart from a card payload without a new Transferable type.
enum IssueDragPayload {
    static let prefix = "issue:"

    static func encode(_ issueID: UUID) -> String { prefix + issueID.uuidString }

    static func decode(_ payload: String) -> UUID? {
        guard payload.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(payload.dropFirst(prefix.count)))
    }
}

extension IssueStatus {
    var arenaColor: Color {
        switch self {
        case .open: return AC.threat
        case .investigating: return AC.gold
        case .confirmed: return .orange
        case .blocked: return AC.threat
        case .mitigated: return AC.cyan
        case .resolved: return AC.available
        case .dismissed: return AC.textGhost
        }
    }
}

/// Issues affecting the currently selected element (or the whole map when
/// nothing's selected) — what's wrong, distinct from the cards that can act
/// on it. Placed alongside the Contextual Hand so the workflow reads:
/// see what's affecting this node → see what can be done about it.
struct SystemIssuesPanelView: View {
    let issues: [SystemIssue]
    /// Issues elsewhere in the map, not yet attached to this selection —
    /// the non-drag alternative to dragging an issue onto a node.
    let attachableIssues: [SystemIssue]
    let selectionLabel: String
    let onCreateIssue: (String, IssueType, IssueSeverity) -> Void
    let onAttachExisting: (SystemIssue) -> Void
    let onEdit: (SystemIssue) -> Void
    let onSetStatus: (SystemIssue, IssueStatus) -> Void
    let onSetSeverity: (SystemIssue, IssueSeverity) -> Void
    let onDuplicate: (SystemIssue) -> Void
    let onRemoveFromElement: (SystemIssue) -> Void
    let onDelete: (SystemIssue) -> Void

    @State private var isExpanded = true
    @State private var newTitle = ""
    @State private var newType: IssueType = .issue
    @State private var newSeverity: IssueSeverity = .medium

    private var sortedIssues: [SystemIssue] {
        issues.sorted { $0.severity > $1.severity }
    }

    private var criticalCount: Int { issues.filter { $0.severity == .critical && $0.status.isActive }.count }
    private var blockerCount: Int { issues.filter { $0.type == .blocker && $0.status.isActive }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.system(size: 8, weight: .semibold))
                    ArenaSectionLabel(text: "Issues & Conditions — \(selectionLabel)", color: issues.isEmpty ? AC.textDim : AC.threat, icon: "exclamationmark.triangle")
                    if criticalCount > 0 {
                        Text("\(criticalCount) CRITICAL").font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.threat).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(AC.threatSoft))
                    }
                    if blockerCount > 0 {
                        Text("\(blockerCount) BLOCKER\(blockerCount == 1 ? "" : "S")").font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(AC.gold).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(AC.goldSoft))
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(10)

            if isExpanded {
                Rectangle().fill(AC.borderDim).frame(height: 1)
                if issues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No issues attached").font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.textSub)
                        Text("\(selectionLabel) currently has no issues, blockers, or risks in this scenario.")
                            .font(.system(size: 10)).foregroundStyle(AC.textDim)
                    }
                    .padding(10)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(sortedIssues) { issue in
                                IssueRow(
                                    issue: issue,
                                    onEdit: { onEdit(issue) },
                                    onSetStatus: { onSetStatus(issue, $0) },
                                    onSetSeverity: { onSetSeverity(issue, $0) },
                                    onDuplicate: { onDuplicate(issue) },
                                    onRemoveFromElement: { onRemoveFromElement(issue) },
                                    onDelete: { onDelete(issue) }
                                )
                            }
                        }
                        .padding(10)
                    }
                    .frame(maxHeight: 160)
                }

                Rectangle().fill(AC.borderDim).frame(height: 1)
                HStack(spacing: 6) {
                    TextField("New issue title…", text: $newTitle).arenaFieldStyle()
                    Picker("Type", selection: $newType) {
                        ForEach(IssueType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).tint(AC.cyan).frame(width: 110)
                    Picker("Severity", selection: $newSeverity) {
                        ForEach(IssueSeverity.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).tint(AC.cyan).frame(width: 110)
                    Button("Add Issue") {
                        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreateIssue(trimmed, newType, newSeverity)
                        newTitle = ""
                    }
                    .buttonStyle(ArenaButtonStyle(color: AC.threat, isDisabled: newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !attachableIssues.isEmpty {
                        Menu {
                            ForEach(attachableIssues) { issue in
                                Button(issue.title) { onAttachExisting(issue) }
                            }
                        } label: {
                            Label("Attach Existing", systemImage: "link")
                        }
                        .menuStyle(.button)
                        .buttonStyle(ArenaOutlineButtonStyle())
                    }
                }
                .padding(10)
            }
        }
        .background(AC.surface)
    }
}

private struct IssueRow: View {
    let issue: SystemIssue
    let onEdit: () -> Void
    let onSetStatus: (IssueStatus) -> Void
    let onSetSeverity: (IssueSeverity) -> Void
    let onDuplicate: () -> Void
    let onRemoveFromElement: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: issue.type.systemImage).font(.system(size: 9)).foregroundStyle(issue.severity.arenaColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(issue.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.text)
                HStack(spacing: 5) {
                    Text(issue.severity.displayName.uppercased()).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(issue.severity.arenaColor)
                    Text(issue.status.displayName.uppercased()).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(issue.status.arenaColor)
                    Text(issue.type.displayName).font(.system(size: 9)).foregroundStyle(AC.textDim)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Edit…", action: onEdit)
                Menu("Change Severity") {
                    ForEach(IssueSeverity.allCases, id: \.self) { s in Button(s.displayName) { onSetSeverity(s) } }
                }
                Menu("Change Status") {
                    ForEach(IssueStatus.allCases, id: \.self) { s in Button(s.displayName) { onSetStatus(s) } }
                }
                if issue.status != .resolved {
                    Button("Resolve") { onSetStatus(.resolved) }
                }
                Divider()
                Button("Duplicate", action: onDuplicate)
                Button("Remove from This Element", action: onRemoveFromElement)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AC.textDim)
            .menuStyle(.button)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(AC.surfaceHi))
        .opacity(issue.status.isActive ? 1.0 : 0.55)
        .draggable(IssueDragPayload.encode(issue.id)) {
            // Compact drag preview: title, type, severity — dropping always
            // *attaches* (an issue can affect multiple elements), never moves.
            HStack(spacing: 5) {
                Image(systemName: issue.type.systemImage).font(.system(size: 10)).foregroundStyle(issue.severity.arenaColor)
                Text(issue.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(AC.text)
                Text("ATTACH").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim)
            }
            .padding(8)
            .background(AngularCardShape(cornerRadius: 6, cornerCut: 9).fill(AC.surfaceHi))
            .colorScheme(.dark)
        }
    }
}
