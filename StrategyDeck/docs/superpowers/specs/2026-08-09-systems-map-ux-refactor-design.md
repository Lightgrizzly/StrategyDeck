# Systems Map Workspace UX Refactor — Design

**Goal:** Fix the Systems Map editor's visual clutter through an information-architecture and interaction redesign — not a rebuild. Every store method, model, and evaluator call keeps its current signature; only how existing views are composed and shown changes.

**Guiding principle:** Map first. Context second. Library on demand.

**Scope:** `Sources/StrategyDeck/Views/SystemsMap/SystemsMapTabView.swift`'s `SystemsMapEditorView` (the open-map editor) and its immediate subviews. The empty-state/map-list screen (`SystemsMapEmptyStateView`, `SystemMapExplorerView`) is unaffected. All touched subviews (`SystemElementInspectorView`, `SystemIssuesPanelView`, `SystemContextualHandView`, `SystemCardLibraryView`, `SystemScenarioSelectorView`, `SystemDiagramToolbar`) are instantiated only from this one file, so no other screen is affected by restructuring them.

## Current state (why it's cluttered)

`SystemsMapEditorView.body` (`SystemsMapTabView.swift:404-645`) stacks, permanently and simultaneously:

1. A 4-row header (breadcrumb, title+export, deck controls, goal)
2. A diagram toolbar
3. `HSplitView { diagram, SystemElementInspectorView }` — inspector always occupies a fixed right column
4. `VSplitView` containing, stacked and all always visible: `SystemScenarioSelectorView` (full-width scenario pill strip), `SystemIssuesPanelView` (issues list + inline quick-add form), and a drawer that itself defaults to showing the full Contextual Hand

Much of the *content* here is already in good shape — the fix is composition, not rebuilding:

- `SystemDiagramToolbar` is already one compact row.
- `SystemDiagramCanvasView` already renders active-card-count, issue-count, and critical-blocker badges on the selected node.
- `SystemCardLibraryView` already has Compact List / Compact Grid / Card View display modes and already defaults every status group past the first two (`rank <= 1`) to collapsed.
- `SystemContextualHandView` already groups cards into Active / Available / Blocked with pinning.
- `SystemElementInspectorView` is already reasonably compact (Structure vs. This-Scenario sections, no genuinely "advanced" fields to hide) — no artificial collapsible sections are added here; that part of the original mockup doesn't map onto real fields in this codebase.

## Architecture

Three new container views compose the existing pieces. No existing store method, model, or the evaluator changes.

### 1. `SystemsMapCompactHeaderView`

Two rows, replacing the current 4-row header and the standalone scenario strip:

- **Row 1:** back chevron + breadcrumb, map title (unchanged tap-to-rename), Focus Mode toggle icon, Export.
- **Row 2:** `Deck: [name ▾]` menu and `Scenario: [name ▾]` menu side by side, with the goal (if set) truncated to one line after them.

The Deck menu keeps its current items (Use Map Default / Override for This Scenario / Choose Deck / Manage Decks → reuses the existing deck-picker sheet unchanged) plus a small "SCENARIO OVERRIDE" indicator when active, matching current behavior — just relocated from a dedicated header row into the menu.

The Scenario menu folds together what's currently split between `SystemScenarioSelectorView`'s pill strip and its ellipsis menu: the scenario list (tap to switch), then New / Duplicate / Compare / Rename / Set Default / Reset / Delete acting on the current scenario. No new "Scenario Manager" screen — this was confirmed as the preferred approach over building one.

### 2. `SystemContextPanelView`

Replaces the permanent inspector column and the issues panel. Two tabs: **DETAILS | CARDS** — no separate ISSUES tab; issue information folds into DETAILS instead of getting its own top-level slot.

- **Header:** "SELECTED" + element name/kind (or "System Overview" when nothing's selected), current scenario name, and compact counts (issues/blockers, active cards, available cards) — cheap to compute from arrays already in scope (`elementIssueCounts`, `elementCriticalBlockerCounts`, `relevantEvaluations`), no new model fields.
- **DETAILS tab:** the existing `SystemElementInspectorView` body (element/flow/relationship fields, unchanged), followed by a compact issues sub-section reusing `SystemIssuesPanelView`'s existing `IssueRow` rendering and quick-add fields — same create/edit/attach/severity/status functionality, just embedded under Details instead of living in its own tab or a permanent strip. When nothing is selected, this tab shows a System Overview instead: element/flow/constraint counts, active issue count, and a "View Cards" shortcut into the CARDS tab.
- **CARDS tab:** the existing `SystemContextualHandView` content unchanged (Active/Available/Blocked groups, pinning), with "Browse Full Deck" now opening the bottom drawer's Expanded state instead of swapping the drawer's internal mode.

Node badges on the canvas get tap targets: the issue/blocker badge opens DETAILS (scrolled to the issues sub-section), the active/available-card badge opens CARDS. `contextPanelTab` is sticky across selection changes — switching nodes doesn't reset which tab is showing.

### 3. `SystemCardDrawerView`

Full Library only — Contextual Hand no longer lives in the drawer at all, it's the CARDS tab now. Three states:

- **CLOSED** (default): a slim handle — `Cards · 46 ⌃`.
- **PEEK:** compact strip — deck name, status counts, search field, suite/status filter chips, and an Expand control.
- **EXPANDED:** the existing `SystemCardLibraryView` unchanged (search, deck/suite/status filters, grouped results, display-mode switcher), drag-resizable from its top edge using the same `VSplitView` mechanism already present in the file.

Clicking the handle cycles CLOSED → PEEK → EXPANDED.

### Layout

```
VStack(spacing: 0) {
    SystemsMapCompactHeaderView(...)
    Divider
    SystemDiagramToolbar(...)          // + new Focus Mode icon
    HSplitView {
        SystemDiagramCanvasView(...).layoutPriority(1)   // gets majority of width by construction
        if !isFocusMode { SystemContextPanelView(...) }  // fixed ideal width (~320), min/max clamped
    }
    if !isFocusMode { SystemCardDrawerView(...) }        // pinned handle even when closed
}
```

Giving the context panel a fixed ideal width (rather than a 50/50 split) means the diagram gets the majority of space by construction, without hardcoding a percentage; the native `HSplitView` divider stays user-draggable.

### Focus Mode

Toggled via a toolbar icon (next to zoom controls) and `Cmd+Shift+F`. Hides the context panel and drawer; diagram and toolbar remain. Toggling again (same shortcut or icon) restores the prior panel/drawer state exactly as it was.

### New view-local state

Only additive `@State` in `SystemsMapEditorView`, nothing existing changes shape:

```swift
enum ContextPanelTab { case details, cards }
enum LibraryDrawerState { case closed, peek, expanded }

@State private var contextPanelTab: ContextPanelTab = .details
@State private var drawerState: LibraryDrawerState = .closed   // replaces SystemCardDrawerState
@State private var isFocusMode = false
```

`SystemCardDrawerState`'s `.contextualHand` case goes away entirely (that content is now always the CARDS tab, not a drawer mode).

### Keyboard

| Shortcut | Action |
|---|---|
| `Cmd+1` | Show DETAILS tab |
| `Cmd+2` | Show CARDS tab |
| `Cmd+L` | Toggle library drawer (closed ↔ last open state) |
| `Cmd+Shift+F` | Toggle Focus Mode |
| `Escape` | Close drawer / popover / command palette, in that priority order |
| `Space` | Unchanged — opens node command palette for the current selection |

Checked: no existing shortcut conflicts with `Cmd+1/2`, `Cmd+L`, or `Cmd+Shift+F` anywhere in `Sources/StrategyDeck`.

### Responsive behavior

Two tiers rather than three, since this is a resizable floating `NSPanel` with no OS-imposed width class, not a phone:

- **Regular** (current default, roughly ≥900pt content width): context panel as a permanent `HSplitView` column, as described above.
- **Compact** (narrower): context panel becomes a trailing overlay instead of compressing the diagram; the drawer, when open, takes proportionally more height. Threshold measured via `GeometryReader` on the outer stack.

### State preservation

Selection, scenario, deck, suite filter, search text, and diagram viewport are already owned by `SystemsMapEditorView` state or the store (not by the panel/drawer subviews), so opening/closing the context panel or drawer doesn't touch them — this falls out of the architecture rather than needing explicit save/restore logic. `SystemElementInspectorView`'s local `@State` already re-syncs from its `element`/`override` parameters via `onChange(of: element.id)`, so it re-initializes safely if the DETAILS tab remounts.

## Explicitly out of scope

- No changes to `SystemMapStore`, `SystemMapEvaluator`, or any model in `StrategyDeckCore`.
- No new "Scenario Manager" or "Advanced/Metadata" collapsible sections — neither has real content to justify a new surface right now.
- Issue tracking functionality (create/edit/attach/severity/status/delete) is fully preserved, just relocated under DETAILS instead of a standalone tab or permanent strip.
