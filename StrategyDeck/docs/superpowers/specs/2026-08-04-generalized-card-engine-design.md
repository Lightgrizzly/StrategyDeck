# Generalized Card Engine + Software Engineering Deck Migration

Status: Approved for planning
Date: 2026-08-04
Slice: 1 of N (see "Follow-on slices" below)

## Context

StrategyDeck is a macOS floating-panel utility for browsing "strategy cards" —
today limited to a single hardcoded domain (programming/algorithmic
techniques): one flat list of six suites, one card struct
(`StrategyCard`) with programming-specific fields (`timeComplexity`,
`codeExample`, etc.) baked in as top-level properties, and one loadout
model for building ordered sequences of cards.

The long-term goal is to turn StrategyDeck into a domain-independent system
for organizing knowledge and actions as cards, usable for arbitrary domains
(the two initial built-in decks being Software Engineering and Japanese
Language, with Japanese requiring several specialized card types and views).

That end-to-end goal is too large for a single spec/plan/implementation
cycle. This document specs **only the first slice**: generalizing the data
model and rebuilding today's UI on top of it, with the Software Engineering
content migrated in as the (only) deck. No Japanese content, no
deck-specific specialized views, and no cross-deck features are in scope
here — this slice's job is to produce a working, generalized single-deck
app that later slices can build on without re-architecting the core.

This is a pre-release app with no installed users, so this is a clean
schema cutover — no migration code for old `cards.json`/`suites.json`/
`loadouts.json` files is needed or written.

## Goals

- Replace the single-deck, flat-suite, single-card-type model with a
  general `Library → Deck → Suit (→ Sub-suit) → Card` hierarchy, where
  cards can belong to multiple suits and form a relationship graph
  instead of embedded ID arrays.
- Introduce a two-level card typing scheme (a fixed domain-independent
  `CardKind` for symbol/behavior, plus a deck-specific `CardMetadata`
  payload for structured fields) so a future deck's card types are additive,
  not a rewrite.
- Migrate all existing Software Engineering content losslessly into the new
  model, with zero behavior regression in the existing app (browse, search,
  favorite, edit, create, delete, build/save/reopen a sequence, import/export).
- Replace the flat horizontal suite tabs with a real collapsible tree
  (Deck → Suit → Sub-suit), toggleable so the floating panel can stay compact.

## Non-goals (explicitly deferred to later slices)

- Japanese seed content and Japanese-specific card types/fields
- Verb-centered view, Japanese sentence composer
- Cross-deck relationships / cross-deck sequences (model allows
  `deckIDs: [String]` on `StrategySequence` and `KnowledgeCard`, but no UI
  in this slice constructs multi-deck data)
- Deck/suit creation UI (user-created decks)
- Prerequisite/conflict validation warnings in the sequence builder
- Card-game / scenario mode
- Compact-mode density rework beyond what already exists

## Architecture

```
KnowledgeLibrary (root document, replaces AppData)
├── decks: [KnowledgeDeck]
├── suits: [CardSuit]                  (deck-scoped, optional parentSuitID)
├── cards: [KnowledgeCard]             (polymorphic via kind + metadata)
├── relationships: [CardRelationship]  (graph edges between cards)
└── sequences: [StrategySequence]      (was StrategyLoadout)
```

The Deck → Suit → Sub-suit tree is a browsing structure only, derived by
filtering `suits` by `deckID`/`parentSuitID`. It is not the source of truth
for card-to-card relationships — those live in `CardRelationship` as a
graph, and a card can appear in multiple suits via `suitIDs`.

### Models (`Sources/StrategyDeckCore/Models`)

```swift
struct KnowledgeDeck: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var description: String
    var iconName: String
    var displayOrder: Int
}
// Root suits for a deck = suits.filter { $0.deckID == deck.id && $0.parentSuitID == nil }
// (computed, not stored — avoids a redundant list that can drift out of sync)

struct CardSuit: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var deckID: String
    var parentSuitID: String?      // nil = root suit; arbitrary nesting depth is allowed
    var name: String
    var description: String
    var iconName: String
    var displayOrder: Int
}

enum CardKind: String, Codable, Sendable, CaseIterable {
    case action        // ▶  Something that changes or processes reality
    case condition      // ◆  Something that must already be true
    case principle       // ✦  Something that guides or constrains a decision
    case observation      // ◎  Something used to inspect or diagnose reality
    case entity            // ●  A person, object, system, concept, participant
    case relation            // —  A connector between entities or actions
    case modifier             // △  Something that alters another card
    case chunk                 // ▣  A reusable combination treated as one unit
    case strategy                // ♜  An ordered/structured combination of cards

    var symbol: String { ... }   // the glyphs above, for grayscale identifiability
}

// Deck-specific structured fields live here, one case per specialized card
// type. Decks without specialized fields yet use `.generic`. Adding a new
// deck's card type later is an additive enum case, not an engine change.
enum CardMetadata: Codable, Hashable, Sendable {
    case softwareStrategy(SoftwareStrategyFields)
    case generic

    // Every case contributes its structured field values (not the field
    // names) as flat strings, so free-text search can reach into
    // deck-specific fields without the engine knowing their shape.
    var searchableText: [String] { ... }
}

struct SoftwareStrategyFields: Codable, Hashable, Sendable {
    var trigger: String
    var problemShape: String
    var desiredResult: String
    var mechanism: String
    var requirements: [String]
    var advantages: [String]
    var costs: [String]
    var failureModes: [String]
    var timeComplexity: String
    var spaceComplexity: String
    var flowDescription: String
    var codeExample: String
    var realWorldExample: String
}

struct KnowledgeCard: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var deckIDs: [String]     // usually one entry; array shape supports future cross-deck cards
    var suitIDs: [String]     // a card may belong to multiple suits
    var kind: CardKind
    var metadata: CardMetadata
    var title: String
    var subtitle: String
    var frontText: String
    var backText: String
    var tags: [String]
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum CardRelationshipType: String, Codable, Sendable {
    case requires
    case enables
    case modifies
    case contrasts
    case combinesWith
    case belongsTo
    case canFollow
    case canPrecede
    case equivalentExpression
    case relatedStrategy
    case translation
}

struct CardRelationship: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var sourceCardID: UUID
    var targetCardID: UUID
    var type: CardRelationshipType
    var note: String
}

struct StrategySequence: Codable, Identifiable, Hashable, Sendable {   // was StrategyLoadout
    var id: UUID
    var name: String
    var description: String
    var deckIDs: [String]         // computed from member cards' decks when saved
    var scenario: String          // free-text situation description; empty by default
    var orderedItems: [StrategySequenceItem]
    var createdAt: Date
    var updatedAt: Date
}

struct StrategySequenceItem: Codable, Identifiable, Hashable, Sendable {  // was LoadoutItem
    var id: UUID
    var cardID: UUID
    var order: Int
    var note: String
    var relationshipToPrevious: CardRelationshipType?   // nil = no explicit relation asserted
}

struct KnowledgeLibrary: Codable, Sendable {   // was AppData
    var version: Int
    var decks: [KnowledgeDeck]
    var suits: [CardSuit]
    var cards: [KnowledgeCard]
    var relationships: [CardRelationship]
    var sequences: [StrategySequence]
}
```

All model `Codable` implementations keep the existing project convention of
lenient custom `init(from:)` (every optional-with-default field falls back
via `decodeIfPresent`), so forward/backward-compatible field additions don't
break loading — this is how `StrategyCard` already behaves today and the
new models must preserve it.

`CardRelationship` is directional (`source → target`); the inverse label
(e.g. "Required by" as the inverse of "Requires") is computed for display,
not stored as a second row.

### Migration of existing content

`relatedStrategyIDs` and `combinesWellWithIDs` on the old `StrategyCard`
conceptually become `CardRelationship` rows (`.relatedStrategy` /
`.combinesWith` respectively) — in practice the bundled seed never
populates either array on any of its 46 cards, so the migration produces
zero relationship rows; the mechanism itself is covered directly by
`CardRelationship`'s own tests rather than by seed migration (see
Testing, below). Every existing card becomes `kind = .action`
(today's cards — "Linear Scan", "Retry with Backoff", etc. — are
techniques you apply, matching `CardKind.action`, not `.strategy`, which is
reserved for ordered combinations like a saved `StrategySequence`).
`metadata = .softwareStrategy(SoftwareStrategyFields(...))` carries every
field that used to live directly on `StrategyCard`. `StrategyCard.name`
becomes `KnowledgeCard.title`; `subtitle`/`frontText`/`backText` are left
empty for migrated cards (nothing in the old model maps to them). The old
computed helpers (`triggerSummary`, `primaryAdvantage`, `primaryCost`)
become computed properties scoped to `SoftwareStrategyFields` rather than
top-level `KnowledgeCard` properties. The six existing suites
port over unchanged as root-level `CardSuit` rows (`parentSuitID = nil`)
under one new deck, `id: "software-engineering"`. No sub-suits are
introduced for this deck in this slice.

### Persistence

Clean cutover — no reader for the old file layout. `JSONPersistenceService`
moves from `cards.json` / `suites.json` / `loadouts.json` to `decks.json` /
`suits.json` / `cards.json` / `relationships.json` / `sequences.json`.
`SeedCardProvider` is rewritten to emit a `KnowledgeLibrary` with the one
`software-engineering` deck described above. `KnowledgeLibrary.currentVersion`
(replacing `AppData.currentVersion`) bumps so any pre-existing on-disk file
(there should be none in practice) is simply treated as absent and reseeded
rather than partially decoded.

### Store / service layer

- `StrategyStore` → `CardStore`: same shape (in-memory `@Published` array +
  persistence-backed mutations: add/update/delete/toggleFavorite/duplicate/
  resetToSeed/import/export), generalized to `KnowledgeCard`, plus new
  deck/suit lookup helpers (`decks`, `suits`, `rootSuits(for: deckID)`,
  `childSuits(of: suitID)`).
- `LoadoutStore` → `SequenceStore`: identical tray/save/open/delete/reorder
  API, renamed types (`StrategySequence`/`StrategySequenceItem`).
- `StrategyFilter` → `CardFilter`: adds a `deckID` scope; `suitID` matching
  expands to include descendant sub-suits of the selected suit; free-text
  search scans `title`, `subtitle`, `frontText`, `backText`, `tags`, and
  `metadata.searchableText` — so a search like "compare" still matches a
  card whose match is inside `SoftwareStrategyFields.mechanism`, exactly as
  it does against today's `StrategyCard.mechanism`. This is what keeps
  search behavior identical to today (acceptance criterion 2) without the
  generic engine needing to know the shape of any deck's metadata.
- `ImportExportService`: encodes/decodes `KnowledgeLibrary` instead of
  `AppData`; whole-library import/export only (per-deck import/export is a
  later slice).

### UI

- `SuiteSelectorView`'s horizontal scrolling tabs are replaced by a
  collapsible left-side tree view (Deck → Suit → Sub-suit). A header button
  toggles the sidebar so the floating panel isn't forced wider than today's
  default. Selecting a deck node shows all its cards; selecting a suit node
  shows cards in that suit and all descendant sub-suits.
- `StrategyCardView` → `KnowledgeCardView`, `StrategyCardDetailView` →
  `KnowledgeCardDetailView`, `CardEditorView` → `KnowledgeCardEditorView`.
  Each renders the `CardKind` symbol plus the common fields; the detail and
  editor views `switch` on `CardMetadata` to render deck-specific fields —
  only the `.softwareStrategy` case has a real form in this slice, `.generic`
  renders no extra fields.
- The detail view's relationship section is populated live from
  `CardRelationship` (matching either `sourceCardID` or `targetCardID`),
  replacing the old embedded `relatedStrategyIDs`/`combinesWellWithIDs`
  arrays, and labels each relationship with its type (using the inverse
  label when the current card is the target).
- `LoadoutTrayView` → `SequenceTrayView`, `LoadoutManagerView` →
  `SequenceManagerView`: same behavior as today (add to tray, reorder,
  per-item note, save/open/delete a named sequence), operating on the
  renamed types.

## Testing

Existing tests (`LoadoutTests`, `SearchFilterTests`, `PersistenceTests`,
`SeedDecodingTests`, `MalformedJSONTests`, `ResetTests`) are updated to the
new model/type names and continue to assert the same behavior. New tests
cover: suit-tree descendant expansion in `CardFilter`, `CardRelationship`
creation/round-trip, and `KnowledgeLibrary` round-trip encode/decode.

Note: the bundled seed never actually populates `relatedStrategyIDs` or
`combinesWellWithIDs` on any of the 46 existing cards (verified by
grepping the seed source — zero occurrences of either parameter name), so
there is no real "migrate populated relationship arrays from the seed"
path to exercise. The seed migration helper omits those two parameters
entirely rather than building an unused code path; `CardRelationship`'s
own creation/round-trip behavior is what's tested directly.

## Acceptance criteria for this slice

1. The app launches showing one deck ("Software Engineering") with its six
   suits, browsable via the new tree sidebar.
2. Search, favorites, create/edit/duplicate/delete, and reset-to-seed all
   work identically to today, against the new models.
3. Card detail view shows relationship data (requires/enables/modifies/
   contrasts/combines-with/related-strategy, as applicable) sourced from
   `CardRelationship` rather than embedded ID arrays.
4. The tray/sequence builder (add to hand, reorder, per-item note, save,
   reopen, delete) works identically to today, against the renamed types.
5. Whole-library import/export round-trips losslessly.
6. All existing tests pass (updated to new names); new tests cover suit
   descendant expansion, relationship migration, and library round-trip.
7. The project builds clean and the app runs as a floating panel exactly as
   before, with no behavior regression.

## Follow-on slices (not in this document)

1. Japanese seed deck (entity/particle/action/modifier/grammar-chunk/
   communication-strategy/complete-expression `CardMetadata` cases + seed
   content)
2. Japanese verb-centered role view
3. Japanese sentence composer
4. Cross-deck relationships and cross-deck sequences
5. Deck/suit/card creation UI ("user-created decks")
6. Prerequisite/conflict-aware strategy composer
7. Optional scenario/card-game mode
