# Systems Map Workspace UX Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Systems Map editor's permanently-stacked layout (header, toolbar, inspector, scenario strip, issues panel, card drawer all visible at once) with the composition described in `docs/superpowers/specs/2026-08-09-systems-map-ux-refactor-design.md`: a compact header, a diagram that gets the majority of space, a tabbed DETAILS|CARDS context panel, and an on-demand bottom Full Library drawer — with zero changes to `StrategyDeckCore`, the evaluator, or persistence.

**Architecture:** Existing subviews (`SystemElementInspectorView`, `SystemIssuesPanelView`, `SystemContextualHandView`, `SystemCardLibraryView`, `SystemScenarioSelectorView`, `SystemDiagramToolbar`, `SystemDiagramCanvasView`) are adapted in place with small, additive, independently-compiling changes. Three new container files then compose them: `SystemCardDrawerView`, `SystemContextPanelView`, `SystemsMapCompactHeaderView`. The final task rewires `SystemsMapEditorView.body` in `SystemsMapTabView.swift` to use the new pieces and deletes the now-dead old layout code.

**Tech Stack:** Swift 5.9 / SwiftUI / AppKit, Swift Package Manager. There is no test target for the `StrategyDeck` executable (only `StrategyDeckCore` has `Tests/StrategyDeckCoreTests`), so verification for every task in this plan is `swift build` (compiles clean) rather than XCTest — this matches how all prior SwiftUI-only work in this codebase has been verified. Prefix every build command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

**Spec:** `docs/superpowers/specs/2026-08-09-systems-map-ux-refactor-design.md`

---

## Before you start

Confirm the branch is `version.0.0.22` and the tree is clean:

```bash
git status
```

If `swift build` has never been run in this checkout, the first run will take longer while SwiftPM resolves and builds. That's expected.

---

## Task 1: Add tap targets to node badges

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemDiagramCanvasView.swift`

`SystemElementNodeView` (same file, starting at line 397) renders `activeCardBadge` and `issueBadge` as static (non-interactive) views. Add optional tap callbacks so the editor can later wire "tap the issue badge → open Details" and "tap the active-card badge → open Cards", per spec item 8.

- [ ] **Step 1: Add callback params to `SystemElementNodeView`**

In `Sources/StrategyDeck/Views/SystemsMap/SystemDiagramCanvasView.swift`, find the `SystemElementNodeView` struct (starts at line 397):

old_string:
```swift
struct SystemElementNodeView: View {
    let element: SystemElement
    let state: SystemElementState
    let isSelected: Bool
    let isConnectSource: Bool
    var isDropTargeted: Bool = false
    var activeCardCount: Int = 0
    var issueCount: Int = 0
    var criticalBlockerCount: Int = 0
```

new_string:
```swift
struct SystemElementNodeView: View {
    let element: SystemElement
    let state: SystemElementState
    let isSelected: Bool
    let isConnectSource: Bool
    var isDropTargeted: Bool = false
    var activeCardCount: Int = 0
    var issueCount: Int = 0
    var criticalBlockerCount: Int = 0
    /// Compact badges double as shortcuts into the context panel — tapping
    /// the active-card badge opens the CARDS tab, tapping the issue badge
    /// opens DETAILS (where issues live). `nil` disables the tap (badge
    /// stays purely informational).
    var onTapActiveCardBadge: (() -> Void)? = nil
    var onTapIssueBadge: (() -> Void)? = nil
```

- [ ] **Step 2: Make the badges tappable**

old_string:
```swift
    private var activeCardBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "bolt.fill").font(.system(size: 6))
            Text("\(activeCardCount)").font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(AC.bg)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(Capsule().fill(AC.cyan))
        .shadow(color: AC.cyanGlow, radius: 3)
        .offset(x: -4, y: -4)
        .help("\(activeCardCount) card\(activeCardCount == 1 ? "" : "s") active on this element")
    }

    private var issueBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: criticalBlockerCount > 0 ? "hand.raised.fill" : "exclamationmark.triangle.fill").font(.system(size: 6))
            Text("\(issueCount)").font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(AC.bg)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(Capsule().fill(criticalBlockerCount > 0 ? AC.threat : .orange))
        .shadow(color: criticalBlockerCount > 0 ? AC.threat.opacity(0.8) : .orange.opacity(0.5), radius: 3)
        .offset(x: 4, y: 4)
        .help("\(issueCount) issue\(issueCount == 1 ? "" : "s") affecting this element\(criticalBlockerCount > 0 ? ", \(criticalBlockerCount) critical/blocker" : "")")
    }
```

new_string:
```swift
    private var activeCardBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "bolt.fill").font(.system(size: 6))
            Text("\(activeCardCount)").font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(AC.bg)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(Capsule().fill(AC.cyan))
        .shadow(color: AC.cyanGlow, radius: 3)
        .offset(x: -4, y: -4)
        .help("\(activeCardCount) card\(activeCardCount == 1 ? "" : "s") active on this element")
        .onTapGesture { onTapActiveCardBadge?() }
    }

    private var issueBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: criticalBlockerCount > 0 ? "hand.raised.fill" : "exclamationmark.triangle.fill").font(.system(size: 6))
            Text("\(issueCount)").font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(AC.bg)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(Capsule().fill(criticalBlockerCount > 0 ? AC.threat : .orange))
        .shadow(color: criticalBlockerCount > 0 ? AC.threat.opacity(0.8) : .orange.opacity(0.5), radius: 3)
        .offset(x: 4, y: 4)
        .help("\(issueCount) issue\(issueCount == 1 ? "" : "s") affecting this element\(criticalBlockerCount > 0 ? ", \(criticalBlockerCount) critical/blocker" : "")")
        .onTapGesture { onTapIssueBadge?() }
    }
```

- [ ] **Step 3: Thread the callbacks through `SystemDiagramCanvasView`**

Add two new params to `SystemDiagramCanvasView` itself (find `var onDropIssue: (UUID, DiagramSelection?) -> Void = { _, _ in }` — this is the last stored property before `@State private var panOffset`):

old_string:
```swift
    let onDropCard: (UUID, DiagramSelection?) -> Void
    var onDropIssue: (UUID, DiagramSelection?) -> Void = { _, _ in }

    @State private var panOffset: CGSize = .zero
```

new_string:
```swift
    let onDropCard: (UUID, DiagramSelection?) -> Void
    var onDropIssue: (UUID, DiagramSelection?) -> Void = { _, _ in }
    /// Tapping a node's active-card or issue badge selects that element and
    /// asks the caller to switch the context panel to the relevant tab.
    var onTapActiveCardBadge: (UUID) -> Void = { _ in }
    var onTapIssueBadge: (UUID) -> Void = { _ in }

    @State private var panOffset: CGSize = .zero
```

Now pass them down in `elementNodesLayer`:

old_string:
```swift
            SystemElementNodeView(
                element: element,
                state: elementStates[element.id] ?? .normal,
                isSelected: selection == .element(element.id),
                isConnectSource: pendingConnectSourceID == element.id,
                isDropTargeted: dropTargetedSelection == .element(element.id),
                activeCardCount: elementActiveCardCounts[element.id] ?? 0,
                issueCount: elementIssueCounts[element.id] ?? 0,
                criticalBlockerCount: elementCriticalBlockerCounts[element.id] ?? 0
            )
```

new_string:
```swift
            SystemElementNodeView(
                element: element,
                state: elementStates[element.id] ?? .normal,
                isSelected: selection == .element(element.id),
                isConnectSource: pendingConnectSourceID == element.id,
                isDropTargeted: dropTargetedSelection == .element(element.id),
                activeCardCount: elementActiveCardCounts[element.id] ?? 0,
                issueCount: elementIssueCounts[element.id] ?? 0,
                criticalBlockerCount: elementCriticalBlockerCounts[element.id] ?? 0,
                onTapActiveCardBadge: { onTapActiveCardBadge(element.id) },
                onTapIssueBadge: { onTapIssueBadge(element.id) }
            )
```

- [ ] **Step 4: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean. The existing call site in `SystemsMapTabView.swift` doesn't pass the two new params, which is fine — they default to no-ops.

- [ ] **Step 5: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemDiagramCanvasView.swift
git commit -m "feat: add tap targets to node active-card and issue badges"
```

---

## Task 2: Rewrite the scenario selector as a compact header menu

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemScenarioSelectorView.swift`

Currently a full-width strip (horizontal-scrolling pill row + a separate ellipsis menu). Replace the body with a single compact `Menu` button — same struct name, same init signature, so the one existing call site in `SystemsMapTabView.swift` needs no changes yet. This makes the type ready to drop straight into the new compact header in Task 9.

- [ ] **Step 1: Replace the view body**

Replace the entire contents of `Sources/StrategyDeck/Views/SystemsMap/SystemScenarioSelectorView.swift` with:

```swift
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
```

This drops the `selectedElementLabel` display (it duplicated what the new context panel's SELECTED header shows — see spec's "Avoid repeating information elsewhere unless it serves a different purpose") but keeps the parameter so the call site doesn't need touching yet.

- [ ] **Step 2: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean — same public init, only the internal rendering changed.

- [ ] **Step 3: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemScenarioSelectorView.swift
git commit -m "refactor: collapse scenario selector strip into a compact menu"
```

---

## Task 3: Adapt the Issues panel for embedding under DETAILS

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemIssuesPanelView.swift`

Currently `SystemIssuesPanelView` is its own collapsible panel with a header row (chevron + title + critical/blocker chips) and an always-visible inline quick-add form. Once it's embedded inside the DETAILS tab (Task 8), the outer collapse chevron is redundant — the DETAILS tab itself is the disclosure. Per spec item 6, the quick-add form should be hidden behind a `+ Add Issue` action, not permanently shown.

- [ ] **Step 1: Remove the outer collapse header, always show content**

old_string:
```swift
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
```

new_string:
```swift
    @State private var showingQuickAdd = false
    @State private var newTitle = ""
    @State private var newType: IssueType = .issue
    @State private var newSeverity: IssueSeverity = .medium

    private var sortedIssues: [SystemIssue] {
        issues.sorted { $0.severity > $1.severity }
    }

    private var criticalCount: Int { issues.filter { $0.severity == .critical && $0.status.isActive }.count }
    private var blockerCount: Int { issues.filter { $0.type == .blocker && $0.status.isActive }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ArenaSectionLabel(text: "Issues", color: issues.isEmpty ? AC.textDim : AC.threat, icon: "exclamationmark.triangle")
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

            if issues.isEmpty {
                Text("No issues, blockers, or risks attached to \(selectionLabel) in this scenario.")
                    .font(.system(size: 10)).foregroundStyle(AC.textDim)
            } else {
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
            }

            if showingQuickAdd {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("New issue title…", text: $newTitle).arenaFieldStyle()
                    HStack(spacing: 6) {
                        Picker("Type", selection: $newType) {
                            ForEach(IssueType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                        Picker("Severity", selection: $newSeverity) {
                            ForEach(IssueSeverity.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                    }
                    HStack(spacing: 6) {
                        Button("Add") {
                            let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            onCreateIssue(trimmed, newType, newSeverity)
                            newTitle = ""
                            showingQuickAdd = false
                        }
                        .buttonStyle(ArenaButtonStyle(color: AC.threat, isDisabled: newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel") { showingQuickAdd = false; newTitle = "" }
                            .buttonStyle(ArenaOutlineButtonStyle())
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
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(AC.surfaceHi))
            } else {
                Button(action: { showingQuickAdd = true }) {
                    Label("Add Issue", systemImage: "plus")
                }
                .buttonStyle(ArenaOutlineButtonStyle())
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean — same public params (`issues`, `attachableIssues`, `selectionLabel`, callbacks), only the internal body changed.

- [ ] **Step 3: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemIssuesPanelView.swift
git commit -m "refactor: embed issues list inline, hide quick-add behind + Add Issue"
```

---

## Task 4: Strip the Inspector's own panel chrome

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemElementInspectorView.swift`

`SystemElementInspectorView` currently draws its own "Inspector" header, its own frame constraints, and its own background — all of which become the new context panel's job once it's embedded under a DETAILS tab (Task 8). Strip those so the view is just its content; also add a "connected elements" count line, computed from data already passed in (flows + relationships touching the selected element), matching the spec's DETAILS mockup ("Relationships — 3 connected elements").

- [ ] **Step 1: Remove the outer header/frame/background, expose content directly**

old_string:
```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArenaSectionLabel(text: "Inspector", icon: "sidebar.right")
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            ScrollView {
                content
                    .padding(12)
            }
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 420, maxHeight: .infinity)
        .background(AC.glassPanel)
    }
```

new_string:
```swift
    var body: some View {
        ScrollView {
            content
                .padding(12)
        }
    }
```

- [ ] **Step 2: Add a connected-elements count to the element/flow footer**

old_string:
```swift
    private func relatedCardsFooter(_ kind: SystemTargetKind) -> some View {
        let count = relatedCardCount(kind)
        return HStack(spacing: 5) {
            Image(systemName: "checkmark.circle").font(.system(size: 9)).foregroundStyle(AC.available)
            Text("\(count) card\(count == 1 ? "" : "s") can target this")
                .font(.system(size: 9))
                .foregroundStyle(AC.textDim)
        }
        .padding(.top, 8)
    }
```

new_string:
```swift
    private func relatedCardsFooter(_ kind: SystemTargetKind) -> some View {
        let count = relatedCardCount(kind)
        return HStack(spacing: 5) {
            Image(systemName: "checkmark.circle").font(.system(size: 9)).foregroundStyle(AC.available)
            Text("\(count) card\(count == 1 ? "" : "s") can target this")
                .font(.system(size: 9))
                .foregroundStyle(AC.textDim)
        }
        .padding(.top, 8)
    }

    /// Flows and relationships touching an element — the "N connected
    /// elements" line in the DETAILS tab. Pure count over data already
    /// passed to this view; no new model or store method.
    private func connectedElementCount(forElementID id: UUID) -> Int {
        let flowCount = flows.filter { $0.sourceElementID == id || $0.targetElementID == id }.count
        let relationshipCount = relationships.filter { $0.sourceElementID == id || $0.targetElementID == id }.count
        return flowCount + relationshipCount
    }
```

Now surface it in the element case. Find the `content` switch's `.element` branch:

old_string:
```swift
        case .element(let id):
            if let element = elements.first(where: { $0.id == id }) {
                ElementInspectorBody(
                    element: element,
                    override: scenario.elementOverrides[id] ?? SystemElementOverride(),
                    scenarioName: scenario.name,
                    onUpdate: onUpdateElement,
                    onUpdateOverride: { onUpdateElementOverride(id, $0) }
                )
                relatedCardsFooter(SystemMapEvaluator.targetKind(for: element.kind))
            } else {
                emptyState
            }
```

new_string:
```swift
        case .element(let id):
            if let element = elements.first(where: { $0.id == id }) {
                ElementInspectorBody(
                    element: element,
                    override: scenario.elementOverrides[id] ?? SystemElementOverride(),
                    scenarioName: scenario.name,
                    onUpdate: onUpdateElement,
                    onUpdateOverride: { onUpdateElementOverride(id, $0) }
                )
                HStack(spacing: 5) {
                    Image(systemName: "link").font(.system(size: 9)).foregroundStyle(AC.cyan)
                    let connected = connectedElementCount(forElementID: id)
                    Text("\(connected) connected element\(connected == 1 ? "" : "s")")
                        .font(.system(size: 9))
                        .foregroundStyle(AC.textDim)
                }
                .padding(.top, 4)
                relatedCardsFooter(SystemMapEvaluator.targetKind(for: element.kind))
            } else {
                emptyState
            }
```

- [ ] **Step 3: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean. The one call site in `SystemsMapTabView.swift` still works — it currently wraps this view in `if showingInspector { SystemElementInspectorView(...) }` inside an `HSplitView`, which will look visually different (no frame/background) until Task 10 rewires it, but nothing fails to compile.

- [ ] **Step 4: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemElementInspectorView.swift
git commit -m "refactor: strip Inspector's own panel chrome, add connected-elements count"
```

---

## Task 5: Remove the old three-way drawer state and collapse button from the Contextual Hand

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemContextualHandView.swift`
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift:568-589` (the one call site)

`SystemCardDrawerState` (`.collapsed` / `.contextualHand` / `.fullLibrary`) and `SystemDrawerCollapsedSummaryView` are being replaced by the new `LibraryDrawerState` (Task 7) and the CARDS tab (Task 8). Delete them now since nothing needs them once Contextual Hand becomes permanent tab content — it never gets "collapsed" itself anymore. `SystemDrawerCollapsedSummaryView` was verified via grep to be used only in `SystemsMapTabView.swift:558`; deleting it is safe as part of the same commit that removes that call site.

- [ ] **Step 1: Delete `SystemCardDrawerState` and `SystemDrawerCollapsedSummaryView`**

old_string:
```swift
/// The three display levels the card area beneath the diagram can be in.
/// Selecting a node no longer renders the whole deck by default — the
/// Contextual Hand is the everyday view; the Full Library is opened
/// intentionally.
enum SystemCardDrawerState: Equatable {
    case collapsed
    case contextualHand
    case fullLibrary
}

/// The always-cheap-to-compute summary shown when the drawer is collapsed.
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
/// acting on the current selection without the whole deck rendering.
struct SystemContextualHandView: View {
```

new_string:
```swift
/// The compact, ranked subset of the selected deck — the everyday view for
/// acting on the current selection without the whole deck rendering. Lives
/// permanently as the context panel's CARDS tab.
struct SystemContextualHandView: View {
```

- [ ] **Step 2: Remove the `onCollapse` callback and its button**

old_string:
```swift
    let onTogglePin: (KnowledgeCard) -> Void
    let onSetPinScope: ((KnowledgeCard, PinScope) -> Void)?
    let onAssignToSelectedElement: ((KnowledgeCard) -> Void)?
    let onCollapse: () -> Void
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
        onCollapse: @escaping () -> Void,
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
        self.onCollapse = onCollapse
        self.onOpenFullLibrary = onOpenFullLibrary
    }
```

new_string:
```swift
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
```

- [ ] **Step 3: Remove the header row's collapse button**

old_string:
```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ArenaSectionLabel(text: "Contextual Hand — \(selectionLabel)", icon: "hand.raised")
                Spacer()
                Button(action: onCollapse) { Image(systemName: "chevron.down.circle") }
                    .buttonStyle(.plain).foregroundStyle(AC.textDim).help("Collapse")
            }
            .padding(10)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            if entries.isEmpty {
```

new_string:
```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if entries.isEmpty {
```

- [ ] **Step 4: Update the one call site to drop `onCollapse:`**

In `Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift`, the `case .contextualHand:` branch (around line 567-589):

old_string:
```swift
                case .contextualHand:
                    SystemContextualHandView(
                        entries: contextualHandEntries,
                        totalRelevantCount: relevantEvaluations.count,
                        selectionLabel: selectionLabel,
                        statusCatalog: map.statusCatalog,
                        isEditable: true,
                        onViewDetails: { showingDetailsFor = $0 },
                        onEditCard: { editingCardFromTray = $0 },
                        onApplyIntervention: { showingInterventionSheetFor = $0 },
                        onChangeStatus: { card, status, customStatusID, scope in
                            systemMapStore.setCardStatusOverride(
                                cardID: card.id, targetElementID: selectedElementID,
                                scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                            )
                        },
                        onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
                        onTogglePin: { card in togglePin(for: card) },
                        onSetPinScope: { card, scope in setPinScope(for: card, scope: scope) },
                        onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
                        onCollapse: { drawerState = .collapsed },
                        onOpenFullLibrary: { drawerState = .fullLibrary }
                    )
```

new_string:
```swift
                case .contextualHand:
                    SystemContextualHandView(
                        entries: contextualHandEntries,
                        totalRelevantCount: relevantEvaluations.count,
                        selectionLabel: selectionLabel,
                        statusCatalog: map.statusCatalog,
                        isEditable: true,
                        onViewDetails: { showingDetailsFor = $0 },
                        onEditCard: { editingCardFromTray = $0 },
                        onApplyIntervention: { showingInterventionSheetFor = $0 },
                        onChangeStatus: { card, status, customStatusID, scope in
                            systemMapStore.setCardStatusOverride(
                                cardID: card.id, targetElementID: selectedElementID,
                                scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                            )
                        },
                        onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
                        onTogglePin: { card in togglePin(for: card) },
                        onSetPinScope: { card, scope in setPinScope(for: card, scope: scope) },
                        onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
                        onOpenFullLibrary: { drawerState = .fullLibrary }
                    )
```

This is a mechanical param removal — `drawerState` still exists as `SystemCardDrawerState` at this point in the plan (it's replaced wholesale in Task 10), so `.collapsed` and `.fullLibrary` still resolve fine here.

- [ ] **Step 5: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean.

- [ ] **Step 6: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemContextualHandView.swift Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift
git commit -m "refactor: drop collapsible drawer state from Contextual Hand"
```

---

## Task 6: Let the Full Library seed its filters and drop the redundant "Open Contextual Hand" shortcut

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemCardLibraryView.swift`

Two changes to prepare `SystemCardLibraryView` for living inside the new drawer (Task 7):

1. `onOpenContextualHand` no longer means anything — Contextual Hand is a permanent context-panel tab now, not a drawer mode to switch to. Remove the param and its button.
2. The drawer's PEEK state (Task 7) will have its own lightweight search field and suite/status quick-filters; when the user interacts with any of them, the drawer promotes to EXPANDED with that filter pre-applied. Add three optional init params that seed the view's existing private `@State` on creation — the same pattern `ElementInspectorBody` already uses elsewhere in this codebase.

- [ ] **Step 1: Remove `onOpenContextualHand`**

old_string:
```swift
    let onManageStatuses: (() -> Void)?
    let onCollapseDrawer: (() -> Void)?
    let onOpenContextualHand: (() -> Void)?

    init(
        cards: [KnowledgeCard],
        suits: [CardSuit],
        deckSuits: [CardSuit] = [],
        evaluations: [SystemCardEvaluation],
        statusCatalog: StatusCatalog = .empty,
        selectionLabel: String,
        isEditable: Bool,
        onViewDetails: @escaping (KnowledgeCard) -> Void,
        onEditCard: ((KnowledgeCard) -> Void)? = nil,
        onApplyIntervention: @escaping (KnowledgeCard) -> Void,
        onChangeStatus: @escaping (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void,
        onResetToAutomatic: @escaping (KnowledgeCard) -> Void,
        onChooseAnotherDeck: (() -> Void)? = nil,
        onCreateCard: (() -> Void)? = nil,
        onAssignToSelectedElement: ((KnowledgeCard) -> Void)? = nil,
        onDropCardToStatus: ((UUID, SystemCardStatus, String?) -> Void)? = nil,
        onQuickCreateCard: ((String, String?, String) -> Void)? = nil,
        onQuickCreateAndEdit: ((String, String?, String) -> Void)? = nil,
        onCreateSuiteInline: ((String) -> CardSuit)? = nil,
        onBulkCreateCards: (([(title: String, suitID: String?)]) -> Void)? = nil,
        onManageStatuses: (() -> Void)? = nil,
        onCollapseDrawer: (() -> Void)? = nil,
        onOpenContextualHand: (() -> Void)? = nil
    ) {
        self.cards = cards
        self.suits = suits
        self.deckSuits = deckSuits
        self.evaluations = evaluations
        self.statusCatalog = statusCatalog
        self.selectionLabel = selectionLabel
        self.isEditable = isEditable
        self.onViewDetails = onViewDetails
        self.onEditCard = onEditCard
        self.onApplyIntervention = onApplyIntervention
        self.onChangeStatus = onChangeStatus
        self.onResetToAutomatic = onResetToAutomatic
        self.onChooseAnotherDeck = onChooseAnotherDeck
        self.onCreateCard = onCreateCard
        self.onAssignToSelectedElement = onAssignToSelectedElement
        self.onDropCardToStatus = onDropCardToStatus
        self.onQuickCreateCard = onQuickCreateCard
        self.onQuickCreateAndEdit = onQuickCreateAndEdit
        self.onCreateSuiteInline = onCreateSuiteInline
        self.onBulkCreateCards = onBulkCreateCards
        self.onManageStatuses = onManageStatuses
        self.onCollapseDrawer = onCollapseDrawer
        self.onOpenContextualHand = onOpenContextualHand
    }

    @State private var searchText = ""
    @State private var statusFilter: SystemCardStatus?
    @State private var selectedSuitIDs: Set<String> = []
    @State private var favoritesOnly = false
    @State private var manualDisplayMode: CardDisplayMode?
```

new_string:
```swift
    let onManageStatuses: (() -> Void)?
    let onCollapseDrawer: (() -> Void)?

    init(
        cards: [KnowledgeCard],
        suits: [CardSuit],
        deckSuits: [CardSuit] = [],
        evaluations: [SystemCardEvaluation],
        statusCatalog: StatusCatalog = .empty,
        selectionLabel: String,
        isEditable: Bool,
        initialSearchText: String = "",
        initialStatusFilter: SystemCardStatus? = nil,
        initialSuitIDs: Set<String> = [],
        onViewDetails: @escaping (KnowledgeCard) -> Void,
        onEditCard: ((KnowledgeCard) -> Void)? = nil,
        onApplyIntervention: @escaping (KnowledgeCard) -> Void,
        onChangeStatus: @escaping (KnowledgeCard, SystemCardStatus, String?, SystemOverrideScope) -> Void,
        onResetToAutomatic: @escaping (KnowledgeCard) -> Void,
        onChooseAnotherDeck: (() -> Void)? = nil,
        onCreateCard: (() -> Void)? = nil,
        onAssignToSelectedElement: ((KnowledgeCard) -> Void)? = nil,
        onDropCardToStatus: ((UUID, SystemCardStatus, String?) -> Void)? = nil,
        onQuickCreateCard: ((String, String?, String) -> Void)? = nil,
        onQuickCreateAndEdit: ((String, String?, String) -> Void)? = nil,
        onCreateSuiteInline: ((String) -> CardSuit)? = nil,
        onBulkCreateCards: (([(title: String, suitID: String?)]) -> Void)? = nil,
        onManageStatuses: (() -> Void)? = nil,
        onCollapseDrawer: (() -> Void)? = nil
    ) {
        self.cards = cards
        self.suits = suits
        self.deckSuits = deckSuits
        self.evaluations = evaluations
        self.statusCatalog = statusCatalog
        self.selectionLabel = selectionLabel
        self.isEditable = isEditable
        self.onViewDetails = onViewDetails
        self.onEditCard = onEditCard
        self.onApplyIntervention = onApplyIntervention
        self.onChangeStatus = onChangeStatus
        self.onResetToAutomatic = onResetToAutomatic
        self.onChooseAnotherDeck = onChooseAnotherDeck
        self.onCreateCard = onCreateCard
        self.onAssignToSelectedElement = onAssignToSelectedElement
        self.onDropCardToStatus = onDropCardToStatus
        self.onQuickCreateCard = onQuickCreateCard
        self.onQuickCreateAndEdit = onQuickCreateAndEdit
        self.onCreateSuiteInline = onCreateSuiteInline
        self.onBulkCreateCards = onBulkCreateCards
        self.onManageStatuses = onManageStatuses
        self.onCollapseDrawer = onCollapseDrawer
        _searchText = State(initialValue: initialSearchText)
        _statusFilter = State(initialValue: initialStatusFilter)
        _selectedSuitIDs = State(initialValue: initialSuitIDs)
    }

    @State private var searchText: String
    @State private var statusFilter: SystemCardStatus?
    @State private var selectedSuitIDs: Set<String>
    @State private var favoritesOnly = false
    @State private var manualDisplayMode: CardDisplayMode?
```

- [ ] **Step 2: Remove the "Open Contextual Hand" button from the header**

old_string:
```swift
                if let onCollapseDrawer {
                    Button(action: onCollapseDrawer) { Image(systemName: "chevron.down.circle") }
                        .buttonStyle(.plain).foregroundStyle(AC.textDim).help("Collapse")
                }
                if let onOpenContextualHand {
                    Button(action: onOpenContextualHand) { Image(systemName: "hand.raised") }
                        .buttonStyle(.plain).foregroundStyle(AC.textDim).help("Back to Contextual Hand")
                }
                if onQuickCreateCard != nil {
```

new_string:
```swift
                if let onCollapseDrawer {
                    Button(action: onCollapseDrawer) { Image(systemName: "chevron.down.circle") }
                        .buttonStyle(.plain).foregroundStyle(AC.textDim).help("Collapse")
                }
                if onQuickCreateCard != nil {
```

- [ ] **Step 3: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: compile error at the one call site in `SystemsMapTabView.swift` (`case .fullLibrary:`) which still passes `onOpenContextualHand: { drawerState = .contextualHand }`. Remove that one argument:

old_string (in `Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift`):
```swift
                        onManageStatuses: { showingManageStatuses = true },
                        onCollapseDrawer: { drawerState = .collapsed },
                        onOpenContextualHand: { drawerState = .contextualHand }
                    )
```

new_string:
```swift
                        onManageStatuses: { showingManageStatuses = true },
                        onCollapseDrawer: { drawerState = .collapsed }
                    )
```

Rebuild:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemCardLibraryView.swift Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift
git commit -m "feat: let Full Library seed filters from an initial value; drop dead contextual-hand shortcut"
```

---

## Task 7: Create the Full Library bottom drawer container

**Files:**
- Create: `Sources/StrategyDeck/Views/SystemsMap/SystemCardDrawerView.swift`

New, purely additive file — no existing call site references it yet (that's Task 10). Defines `LibraryDrawerState` (the drawer's replacement for `SystemCardDrawerState`) and `SystemCardDrawerView`, which renders CLOSED/PEEK/EXPANDED and wraps `SystemCardLibraryView` for the EXPANDED case.

- [ ] **Step 1: Write the file**

```swift
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
```

- [ ] **Step 2: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean — new file, nothing references it yet.

- [ ] **Step 3: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemCardDrawerView.swift
git commit -m "feat: add SystemCardDrawerView, the on-demand Full Library drawer"
```

---

## Task 8: Create the tabbed context panel

**Files:**
- Create: `Sources/StrategyDeck/Views/SystemsMap/SystemContextPanelView.swift`

New, purely additive file. Defines `ContextPanelTab` and `SystemContextPanelView`, which wraps the (now-adapted) `SystemElementInspectorView`, `SystemIssuesPanelView`, and `SystemContextualHandView` behind a `SELECTED` header and a `DETAILS | CARDS` tab bar.

- [ ] **Step 1: Write the file**

```swift
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
```

- [ ] **Step 2: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean — new file, nothing references it yet.

- [ ] **Step 3: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemContextPanelView.swift
git commit -m "feat: add SystemContextPanelView, the tabbed DETAILS/CARDS side panel"
```

---

## Task 9: Create the compact workspace header

**Files:**
- Create: `Sources/StrategyDeck/Views/SystemsMap/SystemsMapCompactHeaderView.swift`

New, purely additive file. Consolidates breadcrumb, title, Export, Focus toggle, deck menu, scenario menu (reusing the Task 2 `SystemScenarioSelectorView`), and goal into two rows.

- [ ] **Step 1: Write the file**

```swift
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
```

- [ ] **Step 2: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean — new file, nothing references it yet. (`SystemMapBreadcrumbView` is the existing type already used by the old `headerBar` — confirm it's `internal`/not `private` to this file by checking its declaration if this fails.)

- [ ] **Step 3: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemsMapCompactHeaderView.swift
git commit -m "feat: add SystemsMapCompactHeaderView, the two-row workspace header"
```

---

## Task 10: The cutover — rewire `SystemsMapEditorView`

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift`

Everything needed now exists and compiles independently. This task swaps `SystemsMapEditorView.body` over to the new pieces, adds the new `@State`, wires node-badge taps and keyboard shortcuts, and deletes the dead old layout code (`headerBar`, `showingInspector`, the old `SystemCardDrawerState`-based `Group { switch drawerState { ... } }`, the standalone `SystemScenarioSelectorView`/`SystemIssuesPanelView` call sites).

- [ ] **Step 1: Replace state declarations**

old_string:
```swift
    @State private var tool: DiagramTool = .select
    @State private var selection: DiagramSelection?
    @State private var pendingConnectSourceID: UUID?
    @State private var showingInspector = true
    @State private var showingInterventionSheetFor: KnowledgeCard?
    @State private var showingDetailsFor: KnowledgeCard?
    @State private var showingRenameMapSheet = false
    @State private var renameMapText = ""
    @State private var showingNewScenarioSheet = false
    @State private var newScenarioName = ""
    @State private var newScenarioDescription = ""
    @State private var showingRenameScenarioSheet = false
    @State private var renameScenarioText = ""
    @State private var showingCompareSheet = false
    @State private var showingDeckPicker = false
    @State private var editingDeckID: String?
    @State private var showingCreateCardSheet = false
    @State private var newCard = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, metadata: .softwareStrategy(SoftwareStrategyFields()), title: "")
    @State private var editingCardFromTray: KnowledgeCard?
    @State private var showingManageStatuses = false
    @State private var drawerState: SystemCardDrawerState = .contextualHand
    @State private var editingIssue: SystemIssue?
    @State private var showingCommandPalette = false
    @State private var alertState: AlertState?
    @State private var undoStack: [EditorSnapshot] = []
    @State private var redoStack: [EditorSnapshot] = []
    @State private var pendingDrop: PendingCardDrop?
```

new_string:
```swift
    @State private var tool: DiagramTool = .select
    @State private var selection: DiagramSelection?
    @State private var pendingConnectSourceID: UUID?
    @State private var contextPanelTab: ContextPanelTab = .details
    @State private var libraryDrawerState: LibraryDrawerState = .closed
    @State private var isFocusMode = false
    @State private var showingInterventionSheetFor: KnowledgeCard?
    @State private var showingDetailsFor: KnowledgeCard?
    @State private var showingRenameMapSheet = false
    @State private var renameMapText = ""
    @State private var showingNewScenarioSheet = false
    @State private var newScenarioName = ""
    @State private var newScenarioDescription = ""
    @State private var showingRenameScenarioSheet = false
    @State private var renameScenarioText = ""
    @State private var showingCompareSheet = false
    @State private var showingDeckPicker = false
    @State private var editingDeckID: String?
    @State private var showingCreateCardSheet = false
    @State private var newCard = KnowledgeCard(deckIDs: [], suitIDs: [], kind: .action, metadata: .softwareStrategy(SoftwareStrategyFields()), title: "")
    @State private var editingCardFromTray: KnowledgeCard?
    @State private var showingManageStatuses = false
    @State private var editingIssue: SystemIssue?
    @State private var showingCommandPalette = false
    @State private var alertState: AlertState?
    @State private var undoStack: [EditorSnapshot] = []
    @State private var redoStack: [EditorSnapshot] = []
    @State private var pendingDrop: PendingCardDrop?
```

`drawerState` (of type `SystemCardDrawerState`) is renamed to `libraryDrawerState` (of type `LibraryDrawerState`) — every remaining reference to `drawerState` in this file gets updated in the steps below.

- [ ] **Step 2: Add the counts the new context panel header needs**

Find `private var elementIssueCounts: [UUID: Int] { ... }` and add two new computed properties right after `activeIssuesInScenario`:

old_string:
```swift
    private var activeIssuesInScenario: [SystemIssue] {
        map.issues.filter { $0.status.isActive && $0.appliesTo(scenarioID: scenario.id) }
    }

    private var elementIssueCounts: [UUID: Int] {
```

new_string:
```swift
    private var activeIssuesInScenario: [SystemIssue] {
        map.issues.filter { $0.status.isActive && $0.appliesTo(scenarioID: scenario.id) }
    }

    /// Issue/blocker counts for the SELECTED header — scoped to the current
    /// selection when something's selected, otherwise map-wide (matches
    /// `issuesForSelection`'s own nil-selection fallback below).
    private var selectionIssueCount: Int { issuesForSelection.filter { $0.status.isActive }.count }
    private var selectionBlockerCount: Int { issuesForSelection.filter { $0.status.isActive && ($0.severity == .critical || $0.type == .blocker) }.count }
    private var selectionActiveCardCount: Int { relevantEvaluations.filter { $0.effectiveStatus == .active }.count }
    private var selectionAvailableCardCount: Int { relevantEvaluations.filter { $0.isPlayable }.count }

    private var elementIssueCounts: [UUID: Int] {
```

`isPlayable` is a real, existing property on `SystemCardEvaluation` — the same check `SystemContextualHandView.availableEntries` already uses (`Sources/StrategyDeck/Views/SystemsMap/SystemContextualHandView.swift:101`), so this is consistent with existing code, not new logic.

- [ ] **Step 3: Wire node badge taps**

In the `SystemDiagramCanvasView(...)` call inside `body`, add the two new callbacks:

old_string:
```swift
                    onDropIssue: { issueID, targetSelection in
                        guard let targetID = elementID(for: targetSelection) else { return }
                        pushOverrideUndo()
                        systemMapStore.attachIssue(id: issueID, toElementID: targetID)
                    }
                )
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                if showingInspector {
                    SystemElementInspectorView(
                        elements: map.elements,
                        flows: map.flows,
                        relationships: map.relationships,
                        scenario: scenario,
                        selection: selection,
                        onUpdateElement: { el in pushUndo(); systemMapStore.updateElement(el) },
                        onUpdateFlow: { flow in pushUndo(); systemMapStore.updateFlow(flow) },
                        onUpdateRelationship: { rel in
                            pushUndo()
                            systemMapStore.deleteRelationship(id: rel.id)
                            systemMapStore.addRelationship(rel)
                        },
                        onUpdateElementOverride: { id, override in
                            systemMapStore.setElementOverride(
                                elementID: id, currentValue: override.currentValue,
                                state: override.state, notes: override.notes, inScenario: scenario.id
                            )
                        },
                        onUpdateFlowOverride: { id, override in
                            systemMapStore.setFlowOverride(
                                flowID: id, rate: override.rate,
                                isEnabled: override.isEnabled, state: override.state, inScenario: scenario.id
                            )
                        },
                        relatedCardCount: { kind in
                            cardStore.cards.filter { $0.playabilityRules.systemTargetTypes.isEmpty || $0.playabilityRules.systemTargetTypes.contains(kind) }.count
                        }
                    )
                }
            }
            .frame(minHeight: 180, maxHeight: .infinity)
```

new_string:
```swift
                    onDropIssue: { issueID, targetSelection in
                        guard let targetID = elementID(for: targetSelection) else { return }
                        pushOverrideUndo()
                        systemMapStore.attachIssue(id: issueID, toElementID: targetID)
                    },
                    onTapActiveCardBadge: { elementID in
                        selection = .element(elementID)
                        contextPanelTab = .cards
                    },
                    onTapIssueBadge: { elementID in
                        selection = .element(elementID)
                        contextPanelTab = .details
                    }
                )
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                if !isFocusMode {
                    contextPanel
                }
            }
            .frame(minHeight: 180, maxHeight: .infinity)
```

- [ ] **Step 4: Replace the `VSplitView` bottom section**

old_string:
```swift
            VStack(spacing: 0) {
            SystemScenarioSelectorView(
                scenarios: map.scenarios,
                selectedScenarioID: map.selectedScenarioID,
                selectedElementLabel: selection == nil ? nil : selectionLabel,
                onSelectScenario: { systemMapStore.selectScenario(id: $0); selection = nil },
                onNewScenario: {
                    newScenarioName = ""
                    newScenarioDescription = ""
                    showingNewScenarioSheet = true
                },
                onDuplicateCurrentScenario: { systemMapStore.duplicateScenario(id: scenario.id) },
                onRenameCurrentScenario: {
                    renameScenarioText = scenario.name
                    showingRenameScenarioSheet = true
                },
                onSetCurrentScenarioDefault: { systemMapStore.setDefaultScenario(id: scenario.id) },
                onResetCurrentScenario: {
                    alertState = .destructive(
                        title: "Reset “\(scenario.name)”?",
                        message: "Every override in this scenario will be cleared, returning it to the shared base workflow.",
                        confirmLabel: "Reset"
                    ) { systemMapStore.resetScenario(id: scenario.id) }
                },
                onDeleteCurrentScenario: {
                    alertState = .destructive(
                        title: "Delete “\(scenario.name)”?",
                        message: "This scenario and its overrides will be removed permanently.",
                        confirmLabel: "Delete"
                    ) { systemMapStore.deleteScenario(id: scenario.id) }
                },
                onCompareScenarios: { showingCompareSheet = true }
            )

            Rectangle().fill(AC.borderDim).frame(height: 1)
            SystemIssuesPanelView(
                issues: issuesForSelection,
                attachableIssues: selectedAnyID == nil ? [] : activeIssuesInScenario.filter { !$0.affects(elementID: selectedAnyID!) },
                selectionLabel: selectionLabel,
                onCreateIssue: { title, type, severity in
                    systemMapStore.createIssue(
                        title: title, type: type, severity: severity,
                        affectedElementIDs: selectedAnyID.map { [$0] } ?? [],
                        scenarioIDs: [scenario.id]
                    )
                },
                onAttachExisting: { issue in
                    if let selectedAnyID { systemMapStore.attachIssue(id: issue.id, toElementID: selectedAnyID) }
                },
                onEdit: { editingIssue = $0 },
                onSetStatus: { issue, status in systemMapStore.setIssueStatus(id: issue.id, status: status) },
                onSetSeverity: { issue, severity in systemMapStore.setIssueSeverity(id: issue.id, severity: severity) },
                onDuplicate: { systemMapStore.duplicateIssue(id: $0.id) },
                onRemoveFromElement: { issue in
                    if let selectedAnyID { systemMapStore.detachIssue(id: issue.id, fromElementID: selectedAnyID) }
                },
                onDelete: { issue in
                    alertState = .destructive(
                        title: "Delete “\(issue.title)”?",
                        message: "This issue will be removed permanently from the map.",
                        confirmLabel: "Delete"
                    ) { systemMapStore.deleteIssue(id: issue.id) }
                }
            )

            Group {
                switch drawerState {
                case .collapsed:
                    SystemDrawerCollapsedSummaryView(
                        selectionLabel: selectionLabel,
                        statusCounts: SystemCardStatus.allCases.map { status in
                            (status, evaluations.filter { $0.effectiveStatus == status }.count)
                        },
                        statusCatalog: map.statusCatalog,
                        onOpenHand: { drawerState = .contextualHand },
                        onBrowseFullDeck: { drawerState = .fullLibrary }
                    )
                case .contextualHand:
                    SystemContextualHandView(
                        entries: contextualHandEntries,
                        totalRelevantCount: relevantEvaluations.count,
                        selectionLabel: selectionLabel,
                        statusCatalog: map.statusCatalog,
                        isEditable: true,
                        onViewDetails: { showingDetailsFor = $0 },
                        onEditCard: { editingCardFromTray = $0 },
                        onApplyIntervention: { showingInterventionSheetFor = $0 },
                        onChangeStatus: { card, status, customStatusID, scope in
                            systemMapStore.setCardStatusOverride(
                                cardID: card.id, targetElementID: selectedElementID,
                                scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                            )
                        },
                        onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
                        onTogglePin: { card in togglePin(for: card) },
                        onSetPinScope: { card, scope in setPinScope(for: card, scope: scope) },
                        onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
                        onOpenFullLibrary: { drawerState = .fullLibrary }
                    )
                case .fullLibrary:
                    SystemCardLibraryView(
                        cards: deckScopedCards,
                        suits: cardStore.suits,
                        deckSuits: suitsForSelectedDeck(),
                        evaluations: evaluations,
                        statusCatalog: map.statusCatalog,
                        selectionLabel: selectionLabel,
                        isEditable: true,
                        onViewDetails: { showingDetailsFor = $0 },
                        onEditCard: { editingCardFromTray = $0 },
                        onApplyIntervention: { showingInterventionSheetFor = $0 },
                        onChangeStatus: { card, status, customStatusID, scope in
                            systemMapStore.setCardStatusOverride(
                                cardID: card.id, targetElementID: selectedElementID,
                                scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                            )
                        },
                        onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
                        onChooseAnotherDeck: { showingDeckPicker = true },
                        onCreateCard: {
                            newCard = blankCard()
                            showingCreateCardSheet = true
                        },
                        onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
                        onDropCardToStatus: { cardID, status, customStatusID in
                            guard let card = cardStore.cards.first(where: { $0.id == cardID }) else { return }
                            pushOverrideUndo()
                            systemMapStore.setCardStatusOverride(
                                cardID: card.id, targetElementID: selectedElementID,
                                scope: .thisElementOnly, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                            )
                        },
                        onQuickCreateCard: { title, suitID, description in
                            cardStore.quickCreateCard(title: title, deckID: effectiveDeckID, suitID: suitID, shortDescription: description)
                        },
                        onQuickCreateAndEdit: { title, suitID, description in
                            editingCardFromTray = cardStore.quickCreateCard(title: title, deckID: effectiveDeckID, suitID: suitID, shortDescription: description)
                        },
                        onCreateSuiteInline: effectiveDeckID.map { deckID in
                            { name in cardStore.createSuit(deckID: deckID, name: name) }
                        },
                        onBulkCreateCards: { entries in
                            cardStore.bulkCreateCards(entries, deckID: effectiveDeckID)
                        },
                        onManageStatuses: { showingManageStatuses = true },
                        onCollapseDrawer: { drawerState = .collapsed }
                    )
                }
            }
            .frame(maxHeight: .infinity)
            }
            .frame(minHeight: 150, maxHeight: .infinity)
            }
        }
```

new_string:
```swift
            if !isFocusMode {
                libraryDrawer
                    .frame(
                        minHeight: libraryDrawerState == .expanded ? 150 : nil,
                        maxHeight: libraryDrawerState == .expanded ? .infinity : nil
                    )
            }
            }
        }
```

`libraryDrawer` is a new computed property added in the next step — Swift resolves same-type member references regardless of their textual order in the file, so this compiles once Step 5 adds it, with no intermediate placeholder needed. Now add the two new computed properties (`contextPanel` and `libraryDrawer`) near `headerBar` — find `private struct EditingDeckTarget` (just above `private var headerBar`) and insert before it:

old_string:
```swift
    private struct EditingDeckTarget: Identifiable { let id: String }

    private var headerBar: some View {
```

new_string:
```swift
    private struct EditingDeckTarget: Identifiable { let id: String }

    private var contextPanel: some View {
        SystemContextPanelView(
            selectionLabel: selectionLabel,
            selectionKindLabel: selectedTargetKind?.displayName,
            scenarioName: scenario.name,
            issueCount: selectionIssueCount,
            blockerCount: selectionBlockerCount,
            activeCardCount: selectionActiveCardCount,
            availableCardCount: selectionAvailableCardCount,
            tab: $contextPanelTab,
            hasSelection: selection != nil,
            inspector: SystemElementInspectorView(
                elements: map.elements,
                flows: map.flows,
                relationships: map.relationships,
                scenario: scenario,
                selection: selection,
                onUpdateElement: { el in pushUndo(); systemMapStore.updateElement(el) },
                onUpdateFlow: { flow in pushUndo(); systemMapStore.updateFlow(flow) },
                onUpdateRelationship: { rel in
                    pushUndo()
                    systemMapStore.deleteRelationship(id: rel.id)
                    systemMapStore.addRelationship(rel)
                },
                onUpdateElementOverride: { id, override in
                    systemMapStore.setElementOverride(
                        elementID: id, currentValue: override.currentValue,
                        state: override.state, notes: override.notes, inScenario: scenario.id
                    )
                },
                onUpdateFlowOverride: { id, override in
                    systemMapStore.setFlowOverride(
                        flowID: id, rate: override.rate,
                        isEnabled: override.isEnabled, state: override.state, inScenario: scenario.id
                    )
                },
                relatedCardCount: { kind in
                    cardStore.cards.filter { $0.playabilityRules.systemTargetTypes.isEmpty || $0.playabilityRules.systemTargetTypes.contains(kind) }.count
                }
            ),
            issuesPanel: SystemIssuesPanelView(
                issues: issuesForSelection,
                attachableIssues: selectedAnyID == nil ? [] : activeIssuesInScenario.filter { !$0.affects(elementID: selectedAnyID!) },
                selectionLabel: selectionLabel,
                onCreateIssue: { title, type, severity in
                    systemMapStore.createIssue(
                        title: title, type: type, severity: severity,
                        affectedElementIDs: selectedAnyID.map { [$0] } ?? [],
                        scenarioIDs: [scenario.id]
                    )
                },
                onAttachExisting: { issue in
                    if let selectedAnyID { systemMapStore.attachIssue(id: issue.id, toElementID: selectedAnyID) }
                },
                onEdit: { editingIssue = $0 },
                onSetStatus: { issue, status in systemMapStore.setIssueStatus(id: issue.id, status: status) },
                onSetSeverity: { issue, severity in systemMapStore.setIssueSeverity(id: issue.id, severity: severity) },
                onDuplicate: { systemMapStore.duplicateIssue(id: $0.id) },
                onRemoveFromElement: { issue in
                    if let selectedAnyID { systemMapStore.detachIssue(id: issue.id, fromElementID: selectedAnyID) }
                },
                onDelete: { issue in
                    alertState = .destructive(
                        title: "Delete “\(issue.title)”?",
                        message: "This issue will be removed permanently from the map.",
                        confirmLabel: "Delete"
                    ) { systemMapStore.deleteIssue(id: issue.id) }
                }
            ),
            systemOverview: SystemOverviewContent(
                stockCount: map.elements.filter { $0.kind == .stock }.count,
                flowCount: map.flows.count,
                constraintCount: map.elements.filter { $0.kind == .constraint }.count,
                activeIssueCount: activeIssuesInScenario.count,
                onViewCards: { contextPanelTab = .cards }
            ),
            contextualHand: SystemContextualHandView(
                entries: contextualHandEntries,
                totalRelevantCount: relevantEvaluations.count,
                selectionLabel: selectionLabel,
                statusCatalog: map.statusCatalog,
                isEditable: true,
                onViewDetails: { showingDetailsFor = $0 },
                onEditCard: { editingCardFromTray = $0 },
                onApplyIntervention: { showingInterventionSheetFor = $0 },
                onChangeStatus: { card, status, customStatusID, scope in
                    systemMapStore.setCardStatusOverride(
                        cardID: card.id, targetElementID: selectedElementID,
                        scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                    )
                },
                onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
                onTogglePin: { card in togglePin(for: card) },
                onSetPinScope: { card, scope in setPinScope(for: card, scope: scope) },
                onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
                onOpenFullLibrary: { libraryDrawerState = .expanded }
            )
        )
    }

    private var libraryDrawer: some View {
        SystemCardDrawerView(
            state: libraryDrawerState,
            onCycleState: {
                switch libraryDrawerState {
                case .closed: libraryDrawerState = .peek
                case .peek: libraryDrawerState = .expanded
                case .expanded: libraryDrawerState = .expanded
                }
            },
            onClose: { libraryDrawerState = .closed },
            deckName: deckName,
            statusCounts: SystemCardStatus.allCases.map { status in
                (status, evaluations.filter { $0.effectiveStatus == status }.count)
            },
            statusCatalog: map.statusCatalog,
            cards: deckScopedCards,
            suits: cardStore.suits,
            deckSuits: suitsForSelectedDeck(),
            evaluations: evaluations,
            selectionLabel: selectionLabel,
            isEditable: true,
            onViewDetails: { showingDetailsFor = $0 },
            onEditCard: { editingCardFromTray = $0 },
            onApplyIntervention: { showingInterventionSheetFor = $0 },
            onChangeStatus: { card, status, customStatusID, scope in
                systemMapStore.setCardStatusOverride(
                    cardID: card.id, targetElementID: selectedElementID,
                    scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                )
            },
            onResetToAutomatic: { card in clearOverrideMatchingSelection(for: card) },
            onChooseAnotherDeck: { showingDeckPicker = true },
            onCreateCard: {
                newCard = blankCard()
                showingCreateCardSheet = true
            },
            onAssignToSelectedElement: { card in handleCardDrop(cardID: card.id, onto: selection) },
            onDropCardToStatus: { cardID, status, customStatusID in
                guard let card = cardStore.cards.first(where: { $0.id == cardID }) else { return }
                pushOverrideUndo()
                systemMapStore.setCardStatusOverride(
                    cardID: card.id, targetElementID: selectedElementID,
                    scope: .thisElementOnly, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                )
            },
            onQuickCreateCard: { title, suitID, description in
                cardStore.quickCreateCard(title: title, deckID: effectiveDeckID, suitID: suitID, shortDescription: description)
            },
            onQuickCreateAndEdit: { title, suitID, description in
                editingCardFromTray = cardStore.quickCreateCard(title: title, deckID: effectiveDeckID, suitID: suitID, shortDescription: description)
            },
            onCreateSuiteInline: effectiveDeckID.map { deckID in
                { name in cardStore.createSuit(deckID: deckID, name: name) }
            },
            onBulkCreateCards: { entries in
                cardStore.bulkCreateCards(entries, deckID: effectiveDeckID)
            },
            onManageStatuses: { showingManageStatuses = true }
        )
    }

    private var headerBar: some View {
```

- [ ] **Step 5: Replace `VSplitView`'s opening wrapper and the old `headerBar` call**

The overall `body` currently opens with `VSplitView { HSplitView { ... } ... }` right after the toolbar, and calls `headerBar` at the very top. Update both:

old_string:
```swift
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)
```

new_string:
```swift
    var body: some View {
        VStack(spacing: 0) {
            SystemsMapCompactHeaderView(
                mapTitle: map.title,
                folderID: map.folderID,
                primaryGoal: map.primaryGoal,
                deckName: deckName,
                isUsingScenarioDeckOverride: isUsingScenarioDeckOverride,
                isFocusMode: isFocusMode,
                scenarios: map.scenarios,
                selectedScenarioID: map.selectedScenarioID,
                onNavigateFolder: { folderID in
                    selectedFolderID = folderID
                    systemMapStore.closeCurrentSystemMap()
                },
                onClose: { systemMapStore.closeCurrentSystemMap() },
                onRenameMap: { renameMapText = map.title; showingRenameMapSheet = true },
                onToggleFocusMode: { isFocusMode.toggle() },
                onExport: exportJSON,
                onOpenDeckPicker: { showingDeckPicker = true },
                onOverrideDeckForScenario: {
                    systemMapStore.setScenarioDeckOverride(scenarioID: scenario.id, deckID: map.defaultDeckID)
                    showingDeckPicker = true
                },
                onResetDeckOverride: { systemMapStore.setScenarioDeckOverride(scenarioID: scenario.id, deckID: nil) },
                onSelectScenario: { systemMapStore.selectScenario(id: $0); selection = nil },
                onNewScenario: {
                    newScenarioName = ""
                    newScenarioDescription = ""
                    showingNewScenarioSheet = true
                },
                onDuplicateCurrentScenario: { systemMapStore.duplicateScenario(id: scenario.id) },
                onRenameCurrentScenario: {
                    renameScenarioText = scenario.name
                    showingRenameScenarioSheet = true
                },
                onSetCurrentScenarioDefault: { systemMapStore.setDefaultScenario(id: scenario.id) },
                onResetCurrentScenario: {
                    alertState = .destructive(
                        title: "Reset “\(scenario.name)”?",
                        message: "Every override in this scenario will be cleared, returning it to the shared base workflow.",
                        confirmLabel: "Reset"
                    ) { systemMapStore.resetScenario(id: scenario.id) }
                },
                onDeleteCurrentScenario: {
                    alertState = .destructive(
                        title: "Delete “\(scenario.name)”?",
                        message: "This scenario and its overrides will be removed permanently.",
                        confirmLabel: "Delete"
                    ) { systemMapStore.deleteScenario(id: scenario.id) }
                },
                onCompareScenarios: { showingCompareSheet = true }
            )
            Rectangle().fill(AC.cyan.opacity(0.2)).frame(height: 1)
```

- [ ] **Step 6: Delete the now-dead `headerBar` computed property**

Find `private var headerBar: some View { ... }` (its full body, ending right before `// MARK: - Actions`) and delete it entirely — every piece of it moved into `SystemsMapCompactHeaderView` in Step 5.

- [ ] **Step 7: Add the Focus Mode toggle to the toolbar and add keyboard shortcuts**

old_string:
```swift
            SystemDiagramToolbar(
                tool: $tool,
                isEditable: true,
                hasSelection: selection != nil,
                canUndo: !undoStack.isEmpty,
                canRedo: !redoStack.isEmpty,
                onDelete: deleteSelection,
                onUndo: undo,
                onRedo: redo,
                onZoomIn: {}, onZoomOut: {}, onFit: {}, onCenterSelection: {}
            )
            Rectangle().fill(AC.borderDim).frame(height: 1)
```

new_string:
```swift
            HStack(spacing: 0) {
                SystemDiagramToolbar(
                    tool: $tool,
                    isEditable: true,
                    hasSelection: selection != nil,
                    canUndo: !undoStack.isEmpty,
                    canRedo: !redoStack.isEmpty,
                    onDelete: deleteSelection,
                    onUndo: undo,
                    onRedo: redo,
                    onZoomIn: {}, onZoomOut: {}, onFit: {}, onCenterSelection: {}
                )
                Button(action: { isFocusMode.toggle() }) {
                    Image(systemName: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isFocusMode ? AC.cyan : AC.textSub)
                .help(isFocusMode ? "Exit Focus Mode (⌘⇧F)" : "Focus Mode (⌘⇧F)")
                .padding(.trailing, 10)
            }
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            Button("") { isFocusMode.toggle() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .hidden().frame(width: 0, height: 0)
            Button("") { contextPanelTab = .details }
                .keyboardShortcut("1", modifiers: .command)
                .hidden().frame(width: 0, height: 0)
            Button("") { contextPanelTab = .cards }
                .keyboardShortcut("2", modifiers: .command)
                .hidden().frame(width: 0, height: 0)
            Button("") {
                switch libraryDrawerState {
                case .closed: libraryDrawerState = .expanded
                case .peek, .expanded: libraryDrawerState = .closed
                }
            }
            .keyboardShortcut("l", modifiers: .command)
            .hidden().frame(width: 0, height: 0)
            Button("") {
                if libraryDrawerState != .closed { libraryDrawerState = .closed }
                else if showingCommandPalette { showingCommandPalette = false }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .hidden().frame(width: 0, height: 0)
```

These follow the exact same "hidden zero-size `Button` with `.keyboardShortcut`" pattern already used a few lines above for the existing Space-bar command-palette shortcut, so they compose safely with it (that Space binding is untouched — verify by reading the few lines above this edit before applying it, since the old `Button("") { if selection != nil { showingCommandPalette = true } }.keyboardShortcut(.space, ...)` block stays exactly as-is, just now followed by these new ones).

- [ ] **Step 8: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```

Work through any remaining compile errors by re-reading the exact current file content at the error location (line numbers will have shifted from every prior task's edits) — the most likely issues are leftover references to `showingInspector` (delete them — grep confirmed zero uses outside this file) or leftover references to `drawerState` that should now be `libraryDrawerState`.

Expected once clean: `swift build` succeeds with zero errors.

- [ ] **Step 9: Run the existing Core test suite to confirm no regression**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected: all existing tests in `Tests/StrategyDeckCoreTests` still pass — this plan never touches `StrategyDeckCore`, so this is a smoke check, not new coverage.

- [ ] **Step 10: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift
git commit -m "feat: cut over Systems Map editor to compact header + tabbed panel + drawer"
```

---

## Task 11: Responsive width tiers

**Files:**
- Modify: `Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift`

Per the spec: side-by-side context panel above ~900pt of content width, overlay below it, per the two-tier simplification the spec calls out explicitly (this is a resizable floating `NSPanel`, not a phone — no third breakpoint).

- [ ] **Step 1: Wrap the body in a `GeometryReader` and branch the context panel's placement**

Find the `HSplitView { SystemDiagramCanvasView(...) ... if !isFocusMode { contextPanel } }` block from Task 10 Step 3 and wrap the whole `VStack(spacing: 0) { ... }` that makes up `body` in a `GeometryReader`:

old_string:
```swift
    var body: some View {
        VStack(spacing: 0) {
            SystemsMapCompactHeaderView(
```

new_string:
```swift
    var body: some View {
        GeometryReader { geo in
        let isCompactWidth = geo.size.width < 900
        VStack(spacing: 0) {
            SystemsMapCompactHeaderView(
```

Then close the `GeometryReader` — find the final closing of `body` (search for the last `.sheet(isPresented: $showingCommandPalette) { ... }` block, which is the last modifier chained onto `body`'s outermost view before the function's closing `}`) and add one more closing brace for the `GeometryReader`:

old_string:
```swift
        .sheet(isPresented: $showingCommandPalette) {
            NodeCommandPaletteView(
                selectionLabel: selectionLabel,
                cards: deckScopedCards.filter { relevantEvaluations.map(\.cardID).contains($0.id) },
                evaluationByID: evaluationByID,
                statusCatalog: map.statusCatalog,
                suits: cardStore.suits,
                onViewDetails: { showingDetailsFor = $0; showingCommandPalette = false },
                onChangeStatus: { card, status, customStatusID, scope in
                    systemMapStore.setCardStatusOverride(
                        cardID: card.id, targetElementID: selectedElementID,
                        scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                    )
                },
                onApplyIntervention: { showingInterventionSheetFor = $0; showingCommandPalette = false },
                onTogglePin: { card in togglePin(for: card) },
                onAssignToSelectedElement: { card in
                    handleCardDrop(cardID: card.id, onto: selection)
                    showingCommandPalette = false
                },
                onClose: { showingCommandPalette = false }
            )
        }
    }
```

new_string:
```swift
        .sheet(isPresented: $showingCommandPalette) {
            NodeCommandPaletteView(
                selectionLabel: selectionLabel,
                cards: deckScopedCards.filter { relevantEvaluations.map(\.cardID).contains($0.id) },
                evaluationByID: evaluationByID,
                statusCatalog: map.statusCatalog,
                suits: cardStore.suits,
                onViewDetails: { showingDetailsFor = $0; showingCommandPalette = false },
                onChangeStatus: { card, status, customStatusID, scope in
                    systemMapStore.setCardStatusOverride(
                        cardID: card.id, targetElementID: selectedElementID,
                        scope: scope, status: status, customStatusID: customStatusID, reason: "", scenarioID: scenario.id
                    )
                },
                onApplyIntervention: { showingInterventionSheetFor = $0; showingCommandPalette = false },
                onTogglePin: { card in togglePin(for: card) },
                onAssignToSelectedElement: { card in
                    handleCardDrop(cardID: card.id, onto: selection)
                    showingCommandPalette = false
                },
                onClose: { showingCommandPalette = false }
            )
        }
        }
    }
```

Note the `let isCompactWidth = geo.size.width < 900` introduced above isn't used yet — that's the next step, to avoid an "unused variable" warning turning into a build break on a strict setting.

- [ ] **Step 2: Use `isCompactWidth` to switch the context panel between column and overlay**

old_string:
```swift
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                if !isFocusMode {
                    contextPanel
                }
            }
            .frame(minHeight: 180, maxHeight: .infinity)
```

new_string:
```swift
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .overlay(alignment: .trailing) {
                    if !isFocusMode && isCompactWidth {
                        contextPanel
                            .transition(.move(edge: .trailing))
                    }
                }
                if !isFocusMode && !isCompactWidth {
                    contextPanel
                }
            }
            .frame(minHeight: 180, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.15), value: isCompactWidth)
```

In compact width, the context panel becomes a trailing overlay on top of the diagram (per spec item 25 — "context panel becomes an overlay/drawer rather than compressing the diagram excessively") instead of a permanent `HSplitView` column.

- [ ] **Step 3: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift
git commit -m "feat: overlay the context panel instead of compressing the diagram at narrow widths"
```

---

## Task 12: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full clean build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```
Expected: zero errors, zero new warnings introduced by this plan's files (pre-existing warnings elsewhere in the codebase, if any, are out of scope).

- [ ] **Step 2: Full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected: all `StrategyDeckCoreTests` pass — unchanged from before this plan, confirming no `StrategyDeckCore` regression.

- [ ] **Step 3: Manual visual check**

Launch the app and open (or create) a Systems Map:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run StrategyDeck
```

Confirm, against the spec's acceptance criteria:
- The diagram occupies the majority of the window on open.
- The header is two compact rows.
- Selecting a stock/flow/relationship shows DETAILS with its fields and any attached issues below them; switching to CARDS shows the Contextual Hand.
- The Full Library only appears after clicking the bottom handle, cycling CLOSED → PEEK → EXPANDED.
- Cmd+1/Cmd+2 switch tabs, Cmd+L toggles the drawer, Cmd+Shift+F toggles Focus Mode, Escape closes an open drawer.
- Tapping a node's issue or active-card badge opens the right tab.
- Existing saved Systems Maps (if any exist in the app's persisted data) still open without errors.

Quit the app (Cmd+Q or Ctrl+C in the terminal running `swift run`) when done — don't leave it running in the background.

- [ ] **Step 4: No commit** — this task is verification-only. If Step 3 surfaces a bug, fix it as a new, separately-committed change before considering the plan complete.
