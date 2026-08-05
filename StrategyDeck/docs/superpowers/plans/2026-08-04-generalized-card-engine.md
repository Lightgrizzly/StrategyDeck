# Generalized Card Engine + Software Engineering Deck Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace StrategyDeck's single-domain, flat-suite, single-card-type model with a domain-independent `Library → Deck → Suit (→ Sub-suit) → Card` engine, and migrate all existing Software Engineering content into it losslessly, with zero behavior regression.

**Architecture:** New models (`KnowledgeDeck`, `CardSuit`, `KnowledgeCard`, `CardMetadata`, `CardRelationship`, `StrategySequence`, `KnowledgeLibrary`) are built additively in `StrategyDeckCore` alongside the existing models, each with full unit test coverage. Once the full model surface exists, one atomic cutover task swaps every consumer (persistence, stores, seed data, all SwiftUI views) over to the new types in a single commit, because Swift Package Manager compiles `Sources/StrategyDeck` and `Sources/StrategyDeckCore` as part of one dependency graph — `swift test` cannot succeed while either target has a type error, so the cutover cannot be split across multiple partially-compiling commits.

**Tech Stack:** Swift 5.9 / SwiftUI / AppKit (`NSPanel`), Swift Package Manager, XCTest.

**Important environment note:** `swift test` on this machine requires the full Xcode toolchain (not just Command Line Tools) for `XCTest.framework` to resolve. Prefix every `swift build` / `swift test` command in this plan with:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

e.g. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

**Spec:** `docs/superpowers/specs/2026-08-04-generalized-card-engine-design.md`

---

## Before you start: pre-existing state

Two things were discovered while planning this work, both predating this plan:

1. **The project currently does not compile.** Three files have a string-interpolation bug (a bare `"` sitting directly next to `\(...)` instead of being escaped or part of one literal, e.g. `"Delete "\(card.name)"?"`), and one file calls `.accentColor` in a context where Swift can't infer it's a `Color`. Task 1 below fixes this — every other task depends on the project actually building.
2. **`Sources/StrategyDeck/Views/Cards/CardGridView.swift` is dead code.** It is never instantiated anywhere (verified via `grep -rn "CardGridView(" Sources/` — zero matches); the real card grid lives inline in `PanelRootView.swift` as `InternalGrid`. Task 1 deletes it rather than fixing its (also broken) code.

---

## Task 1: Fix pre-existing build errors and remove dead code

**Files:**
- Modify: `Sources/StrategyDeck/Views/Panel/PanelRootView.swift:135`, `:202`
- Modify: `Sources/StrategyDeck/Views/Loadouts/LoadoutManagerView.swift:51`
- Modify: `Sources/StrategyDeck/Views/Panel/HeaderView.swift:42`
- Delete: `Sources/StrategyDeck/Views/Cards/CardGridView.swift`

- [ ] **Step 1: Delete the dead file**

```bash
git rm Sources/StrategyDeck/Views/Cards/CardGridView.swift
```

- [ ] **Step 2: Fix the quote bug in `PanelRootView.swift`**

Using Edit on `Sources/StrategyDeck/Views/Panel/PanelRootView.swift`:

old_string:
```
                                    title: "Delete "\(card.name)"?",
```
new_string:
```
                                    title: "Delete \"\(card.name)\"?",
```

Then a second Edit on the same file:

old_string:
```
            Text(filter.query.isEmpty ? "No cards." : "No matches for "\(filter.query)".")
```
new_string:
```
            Text(filter.query.isEmpty ? "No cards." : "No matches for \"\(filter.query)\".")
```

- [ ] **Step 3: Fix the quote bug in `LoadoutManagerView.swift`**

Using Edit on `Sources/StrategyDeck/Views/Loadouts/LoadoutManagerView.swift`:

old_string:
```
                                    title: "Delete "\(loadout.name)"?",
```
new_string:
```
                                    title: "Delete \"\(loadout.name)\"?",
```

- [ ] **Step 4: Fix the `accentColor` type-inference bug in `HeaderView.swift`**

Using Edit on `Sources/StrategyDeck/Views/Panel/HeaderView.swift`:

old_string:
```
                .foregroundStyle(isPinned ? .accentColor : .secondary)
```
new_string:
```
                .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
```

- [ ] **Step 5: Verify the whole package builds and all existing tests pass**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected: both succeed with zero errors (existing test suite passes). This is the first time this project has had a genuinely green baseline — every later task depends on it.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix: repair pre-existing build errors and remove dead CardGridView

Three files had a string-interpolation bug (unescaped quotes butted
against \(...)) and one used .accentColor in a context Swift couldn't
resolve to Color. CardGridView.swift was dead code (never
instantiated; the real grid lives inline in PanelRootView) with the
same bug, so it's deleted rather than fixed.
EOF
)"
```

---

## Task 2: `CardKind`

**Files:**
- Create: `Sources/StrategyDeckCore/Models/CardKind.swift`
- Test: `Tests/StrategyDeckCoreTests/CardKindTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class CardKindTests: XCTestCase {
    func testEverySymbolIsNonEmpty() {
        for kind in CardKind.allCases {
            XCTAssertFalse(kind.symbol.isEmpty, "\(kind) has no symbol")
        }
    }

    func testEveryDisplayNameIsNonEmpty() {
        for kind in CardKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty, "\(kind) has no display name")
        }
    }

    func testSpecificSymbols() {
        XCTAssertEqual(CardKind.action.symbol, "▶")
        XCTAssertEqual(CardKind.strategy.symbol, "♜")
    }

    func testRoundTripsJSON() throws {
        let encoded = try JSONCoding.encoder.encode(CardKind.observation)
        let decoded = try JSONCoding.decoder.decode(CardKind.self, from: encoded)
        XCTAssertEqual(decoded, .observation)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardKindTests
```
Expected: FAIL — `no such module` / `cannot find type 'CardKind' in scope`.

- [ ] **Step 3: Implement `CardKind`**

```swift
import Foundation

/// The domain-independent role a ``KnowledgeCard`` plays. Every deck's cards
/// map onto one of these nine kinds; deck-specific structure lives in
/// ``CardMetadata`` instead. Symbols are used in the UI so cards stay
/// identifiable in grayscale / without relying on color.
public enum CardKind: String, Codable, Hashable, Sendable, CaseIterable {
    case action
    case condition
    case principle
    case observation
    case entity
    case relation
    case modifier
    case chunk
    case strategy

    public var symbol: String {
        switch self {
        case .action: return "▶"
        case .condition: return "◆"
        case .principle: return "✦"
        case .observation: return "◎"
        case .entity: return "●"
        case .relation: return "—"
        case .modifier: return "△"
        case .chunk: return "▣"
        case .strategy: return "♜"
        }
    }

    public var displayName: String {
        switch self {
        case .action: return "Action"
        case .condition: return "Condition"
        case .principle: return "Principle"
        case .observation: return "Observation"
        case .entity: return "Entity"
        case .relation: return "Relation"
        case .modifier: return "Modifier"
        case .chunk: return "Chunk"
        case .strategy: return "Strategy"
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardKindTests
```
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add Sources/StrategyDeckCore/Models/CardKind.swift Tests/StrategyDeckCoreTests/CardKindTests.swift
git commit -m "feat: add CardKind, the domain-independent card role enum"
```

---

## Task 3: `CardRelationshipType` + `CardRelationship`

**Files:**
- Create: `Sources/StrategyDeckCore/Models/CardRelationship.swift`
- Test: `Tests/StrategyDeckCoreTests/CardRelationshipTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class CardRelationshipTests: XCTestCase {
    func testInverseLabelsAreDistinctFromLabels() {
        for type in CardRelationshipType.allCases {
            XCTAssertFalse(type.label.isEmpty)
            XCTAssertFalse(type.inverseLabel.isEmpty)
        }
    }

    func testRequiresInverseIsRequiredBy() {
        XCTAssertEqual(CardRelationshipType.requires.label, "Requires")
        XCTAssertEqual(CardRelationshipType.requires.inverseLabel, "Required by")
    }

    func testDefaultIDIsGenerated() {
        let rel = CardRelationship(sourceCardID: UUID(), targetCardID: UUID(), type: .enables)
        XCTAssertNotNil(rel.id)
    }

    func testLenientDecodeDefaultsNoteToEmpty() throws {
        let json = """
        {"sourceCardID":"\(UUID().uuidString)","targetCardID":"\(UUID().uuidString)","type":"combinesWith"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(CardRelationship.self, from: json)
        XCTAssertEqual(decoded.note, "")
    }

    func testRoundTripsJSON() throws {
        let rel = CardRelationship(sourceCardID: UUID(), targetCardID: UUID(), type: .requires, note: "needs setup")
        let encoded = try JSONCoding.encoder.encode(rel)
        let decoded = try JSONCoding.decoder.decode(CardRelationship.self, from: encoded)
        XCTAssertEqual(decoded, rel)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardRelationshipTests
```
Expected: FAIL — types don't exist yet.

- [ ] **Step 3: Implement `CardRelationshipType` and `CardRelationship`**

```swift
import Foundation

/// The kind of graph edge between two ``KnowledgeCard``s. Directional:
/// stored as `source → target`; ``inverseLabel`` is what to show when
/// looking at the edge from the target's side.
public enum CardRelationshipType: String, Codable, Hashable, Sendable, CaseIterable {
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

    public var label: String {
        switch self {
        case .requires: return "Requires"
        case .enables: return "Enables"
        case .modifies: return "Modifies"
        case .contrasts: return "Contrasts with"
        case .combinesWith: return "Combines with"
        case .belongsTo: return "Belongs to"
        case .canFollow: return "Can follow"
        case .canPrecede: return "Can precede"
        case .equivalentExpression: return "Equivalent expression"
        case .relatedStrategy: return "Related strategy"
        case .translation: return "Translation"
        }
    }

    public var inverseLabel: String {
        switch self {
        case .requires: return "Required by"
        case .enables: return "Enabled by"
        case .modifies: return "Modified by"
        case .contrasts: return "Contrasts with"
        case .combinesWith: return "Combines with"
        case .belongsTo: return "Contains"
        case .canFollow: return "Can precede"
        case .canPrecede: return "Can follow"
        case .equivalentExpression: return "Equivalent expression"
        case .relatedStrategy: return "Related strategy"
        case .translation: return "Translation"
        }
    }
}

/// A directed graph edge between two cards, replacing the old embedded
/// `relatedStrategyIDs` / `combinesWellWithIDs` arrays. A card's
/// relationships are looked up by scanning for its id as either
/// `sourceCardID` or `targetCardID` — see ``CardRelationshipType/inverseLabel``.
public struct CardRelationship: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var sourceCardID: UUID
    public var targetCardID: UUID
    public var type: CardRelationshipType
    public var note: String

    public init(
        id: UUID = UUID(),
        sourceCardID: UUID,
        targetCardID: UUID,
        type: CardRelationshipType,
        note: String = ""
    ) {
        self.id = id
        self.sourceCardID = sourceCardID
        self.targetCardID = targetCardID
        self.type = type
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceCardID = try c.decode(UUID.self, forKey: .sourceCardID)
        targetCardID = try c.decode(UUID.self, forKey: .targetCardID)
        type = try c.decode(CardRelationshipType.self, forKey: .type)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardRelationshipTests
```
Expected: PASS (5/5).

- [ ] **Step 5: Commit**

```bash
git add Sources/StrategyDeckCore/Models/CardRelationship.swift Tests/StrategyDeckCoreTests/CardRelationshipTests.swift
git commit -m "feat: add CardRelationship, a directed graph edge between cards"
```

---

## Task 4: `KnowledgeDeck` + `CardSuit` + suit-tree helpers

**Files:**
- Create: `Sources/StrategyDeckCore/Models/KnowledgeDeck.swift`
- Create: `Sources/StrategyDeckCore/Models/CardSuit.swift`
- Test: `Tests/StrategyDeckCoreTests/CardSuitTreeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class CardSuitTreeTests: XCTestCase {
    // Deck "d" has root suits A and B. A has children A1, A2. A1 has child A1a.
    private func fixture() -> [CardSuit] {
        [
            CardSuit(id: "A", deckID: "d", parentSuitID: nil, name: "A", iconName: "a", displayOrder: 0),
            CardSuit(id: "B", deckID: "d", parentSuitID: nil, name: "B", iconName: "b", displayOrder: 1),
            CardSuit(id: "A1", deckID: "d", parentSuitID: "A", name: "A1", iconName: "a1", displayOrder: 0),
            CardSuit(id: "A2", deckID: "d", parentSuitID: "A", name: "A2", iconName: "a2", displayOrder: 1),
            CardSuit(id: "A1a", deckID: "d", parentSuitID: "A1", name: "A1a", iconName: "a1a", displayOrder: 0),
            CardSuit(id: "OTHER-DECK-ROOT", deckID: "other", parentSuitID: nil, name: "X", iconName: "x", displayOrder: 0)
        ]
    }

    func testRootSuitsAreScopedToDeckAndSortedByDisplayOrder() {
        let roots = fixture().rootSuits(deckID: "d")
        XCTAssertEqual(roots.map(\.id), ["A", "B"])
    }

    func testChildrenAreSortedByDisplayOrder() {
        let children = fixture().children(of: "A")
        XCTAssertEqual(children.map(\.id), ["A1", "A2"])
    }

    func testChildrenOfLeafSuitIsEmpty() {
        XCTAssertTrue(fixture().children(of: "B").isEmpty)
    }

    func testDescendantIDsIncludesSelfAndAllNestedLevels() {
        let ids = fixture().descendantIDs(of: "A")
        XCTAssertEqual(ids, Set(["A", "A1", "A2", "A1a"]))
    }

    func testDescendantIDsOfLeafIsJustItself() {
        XCTAssertEqual(fixture().descendantIDs(of: "B"), Set(["B"]))
    }

    func testKnowledgeDeckDecodesLeniently() throws {
        let json = """
        {"id":"d","name":"Deck"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(KnowledgeDeck.self, from: json)
        XCTAssertEqual(decoded.id, "d")
        XCTAssertEqual(decoded.description, "")
        XCTAssertEqual(decoded.displayOrder, 0)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardSuitTreeTests
```
Expected: FAIL — types don't exist yet.

- [ ] **Step 3: Implement `KnowledgeDeck`**

```swift
import Foundation

/// A top-level domain (e.g. "Software Engineering", "Japanese Language").
/// A deck's root suits are computed by filtering ``CardSuit`` — not stored
/// here — so the two can never drift out of sync.
public struct KnowledgeDeck: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var iconName: String
    public var displayOrder: Int

    public init(
        id: String,
        name: String,
        description: String = "",
        iconName: String = "square.stack.3d.up",
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.displayOrder = displayOrder
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id.capitalized
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "square.stack.3d.up"
        displayOrder = try c.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    }
}
```

- [ ] **Step 4: Implement `CardSuit` and the array helpers**

```swift
import Foundation

/// A grouping of cards within a deck. `parentSuitID == nil` means this is a
/// root suit; any suit may have children, at arbitrary nesting depth. The
/// Deck → Suit → Sub-suit tree is purely a browsing structure derived from
/// this — it is not the source of truth for how cards relate to each other
/// (see ``CardRelationship``), and a card may appear in multiple suits via
/// `KnowledgeCard.suitIDs`.
public struct CardSuit: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var deckID: String
    public var parentSuitID: String?
    public var name: String
    public var description: String
    public var iconName: String
    public var displayOrder: Int

    public init(
        id: String,
        deckID: String,
        parentSuitID: String? = nil,
        name: String,
        description: String = "",
        iconName: String = "square.stack.3d.up",
        displayOrder: Int = 0
    ) {
        self.id = id
        self.deckID = deckID
        self.parentSuitID = parentSuitID
        self.name = name
        self.description = description
        self.iconName = iconName
        self.displayOrder = displayOrder
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        deckID = try c.decode(String.self, forKey: .deckID)
        parentSuitID = try c.decodeIfPresent(String.self, forKey: .parentSuitID)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id.capitalized
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "square.stack.3d.up"
        displayOrder = try c.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    }
}

public extension Array where Element == CardSuit {
    /// Root suits (`parentSuitID == nil`) belonging to one deck, sorted for display.
    func rootSuits(deckID: String) -> [CardSuit] {
        filter { $0.deckID == deckID && $0.parentSuitID == nil }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Direct children of a suit, sorted for display.
    func children(of suitID: String) -> [CardSuit] {
        filter { $0.parentSuitID == suitID }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    /// `suitID` plus every suit nested underneath it, at any depth. Used to
    /// expand "selected this suit" into "matches this suit or any sub-suit".
    func descendantIDs(of suitID: String) -> Set<String> {
        var result: Set<String> = [suitID]
        for child in children(of: suitID) {
            result.formUnion(descendantIDs(of: child.id))
        }
        return result
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardSuitTreeTests
```
Expected: PASS (6/6).

- [ ] **Step 6: Commit**

```bash
git add Sources/StrategyDeckCore/Models/KnowledgeDeck.swift Sources/StrategyDeckCore/Models/CardSuit.swift Tests/StrategyDeckCoreTests/CardSuitTreeTests.swift
git commit -m "feat: add KnowledgeDeck, CardSuit, and suit-tree helpers"
```

---

## Task 5: `SoftwareStrategyFields` + `CardMetadata`

**Files:**
- Create: `Sources/StrategyDeckCore/Models/SoftwareStrategyFields.swift`
- Create: `Sources/StrategyDeckCore/Models/CardMetadata.swift`
- Test: `Tests/StrategyDeckCoreTests/CardMetadataTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class CardMetadataTests: XCTestCase {
    func testGenericHasNoSearchableText() {
        XCTAssertTrue(CardMetadata.generic.searchableText.isEmpty)
    }

    func testSoftwareStrategySearchableTextIncludesMechanismAndAdvantages() {
        let fields = SoftwareStrategyFields(
            mechanism: "Halve the search space",
            advantages: ["No preprocessing"]
        )
        let text = CardMetadata.softwareStrategy(fields).searchableText
        XCTAssertTrue(text.contains("Halve the search space"))
        XCTAssertTrue(text.contains("No preprocessing"))
    }

    func testSoftwareStrategyFieldsDefaultsAreAllEmpty() {
        let fields = SoftwareStrategyFields()
        XCTAssertEqual(fields.trigger, "")
        XCTAssertTrue(fields.requirements.isEmpty)
    }

    func testCardMetadataRoundTripsJSON() throws {
        let original = CardMetadata.softwareStrategy(SoftwareStrategyFields(trigger: "Find target"))
        let encoded = try JSONCoding.encoder.encode(original)
        let decoded = try JSONCoding.decoder.decode(CardMetadata.self, from: encoded)
        guard case .softwareStrategy(let fields) = decoded else {
            return XCTFail("Expected softwareStrategy case")
        }
        XCTAssertEqual(fields.trigger, "Find target")
    }

    func testGenericRoundTripsJSON() throws {
        let encoded = try JSONCoding.encoder.encode(CardMetadata.generic)
        let decoded = try JSONCoding.decoder.decode(CardMetadata.self, from: encoded)
        guard case .generic = decoded else { return XCTFail("Expected generic case") }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardMetadataTests
```
Expected: FAIL — types don't exist yet.

- [ ] **Step 3: Implement `SoftwareStrategyFields`**

```swift
import Foundation

/// Structured fields for a Software Engineering deck card — everything that
/// used to live directly on `StrategyCard`. Lives inside
/// ``CardMetadata/softwareStrategy(_:)``.
public struct SoftwareStrategyFields: Codable, Hashable, Sendable {
    public var trigger: String
    public var problemShape: String
    public var desiredResult: String
    public var mechanism: String
    public var requirements: [String]
    public var advantages: [String]
    public var costs: [String]
    public var failureModes: [String]
    public var timeComplexity: String
    public var spaceComplexity: String
    public var flowDescription: String
    public var codeExample: String
    public var realWorldExample: String

    public init(
        trigger: String = "",
        problemShape: String = "",
        desiredResult: String = "",
        mechanism: String = "",
        requirements: [String] = [],
        advantages: [String] = [],
        costs: [String] = [],
        failureModes: [String] = [],
        timeComplexity: String = "",
        spaceComplexity: String = "",
        flowDescription: String = "",
        codeExample: String = "",
        realWorldExample: String = ""
    ) {
        self.trigger = trigger
        self.problemShape = problemShape
        self.desiredResult = desiredResult
        self.mechanism = mechanism
        self.requirements = requirements
        self.advantages = advantages
        self.costs = costs
        self.failureModes = failureModes
        self.timeComplexity = timeComplexity
        self.spaceComplexity = spaceComplexity
        self.flowDescription = flowDescription
        self.codeExample = codeExample
        self.realWorldExample = realWorldExample
    }
}
```

- [ ] **Step 4: Implement `CardMetadata`**

Swift synthesizes `Codable` automatically for enums with associated values (since Swift 5.5), so no manual `init(from:)`/`encode(to:)` is needed here.

```swift
import Foundation

/// Deck-specific structured fields for a ``KnowledgeCard``. Every case
/// contributes its field values (not field names) to ``searchableText`` so
/// free-text search can reach into deck-specific content without the
/// generic engine knowing any deck's field shape. Adding a new deck's card
/// type later is one additive case here, not an engine change.
public enum CardMetadata: Codable, Hashable, Sendable {
    case softwareStrategy(SoftwareStrategyFields)
    /// Decks (or cards) with no specialized fields yet.
    case generic

    public var searchableText: [String] {
        switch self {
        case .softwareStrategy(let f):
            return [f.trigger, f.problemShape, f.desiredResult, f.mechanism,
                    f.flowDescription, f.codeExample, f.realWorldExample]
                + f.requirements + f.advantages + f.costs + f.failureModes
        case .generic:
            return []
        }
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardMetadataTests
```
Expected: PASS (5/5).

- [ ] **Step 6: Commit**

```bash
git add Sources/StrategyDeckCore/Models/SoftwareStrategyFields.swift Sources/StrategyDeckCore/Models/CardMetadata.swift Tests/StrategyDeckCoreTests/CardMetadataTests.swift
git commit -m "feat: add SoftwareStrategyFields and CardMetadata"
```

---

## Task 6: `KnowledgeCard`

**Files:**
- Create: `Sources/StrategyDeckCore/Models/KnowledgeCard.swift`
- Test: `Tests/StrategyDeckCoreTests/KnowledgeCardTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class KnowledgeCardTests: XCTestCase {
    func testDefaultsAreSensible() {
        let card = KnowledgeCard(deckIDs: ["d"], suitIDs: ["s"], kind: .action, title: "Test")
        XCTAssertFalse(card.isFavorite)
        XCTAssertTrue(card.tags.isEmpty)
        XCTAssertEqual(card.subtitle, "")
        XCTAssertEqual(card.metadata, .generic)
    }

    func testSearchableTextCombinesCommonFieldsAndMetadata() {
        let card = KnowledgeCard(
            deckIDs: ["d"], suitIDs: ["s"], kind: .action,
            metadata: .softwareStrategy(SoftwareStrategyFields(mechanism: "Halve the space")),
            title: "Binary Search",
            tags: ["logarithmic"]
        )
        XCTAssertTrue(card.searchableText.contains("Binary Search"))
        XCTAssertTrue(card.searchableText.contains("logarithmic"))
        XCTAssertTrue(card.searchableText.contains("Halve the space"))
    }

    func testLenientDecodeRequiresOnlyTitle() throws {
        let json = """
        {"title":"Minimal Card"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(KnowledgeCard.self, from: json)
        XCTAssertEqual(decoded.title, "Minimal Card")
        XCTAssertEqual(decoded.kind, .action)
        XCTAssertTrue(decoded.deckIDs.isEmpty)
        XCTAssertTrue(decoded.suitIDs.isEmpty)
    }

    func testRoundTripsJSON() throws {
        let card = KnowledgeCard(
            deckIDs: ["d"], suitIDs: ["s"], kind: .entity,
            metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "t")),
            title: "Card", subtitle: "Sub", tags: ["a", "b"], isFavorite: true
        )
        let encoded = try JSONCoding.encoder.encode(card)
        let decoded = try JSONCoding.decoder.decode(KnowledgeCard.self, from: encoded)
        XCTAssertEqual(decoded, card)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter KnowledgeCardTests
```
Expected: FAIL — type doesn't exist yet.

- [ ] **Step 3: Implement `KnowledgeCard`**

```swift
import Foundation

/// A single card in the library. `kind` is the domain-independent role
/// (drives symbol + generic behavior); `metadata` is the deck-specific
/// structured payload (drives specialized fields and detail/editor views).
/// `deckIDs`/`suitIDs` are arrays so a card can belong to more than one
/// deck or suit without duplication.
public struct KnowledgeCard: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var deckIDs: [String]
    public var suitIDs: [String]
    public var kind: CardKind
    public var metadata: CardMetadata
    public var title: String
    public var subtitle: String
    public var frontText: String
    public var backText: String
    public var tags: [String]
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        deckIDs: [String],
        suitIDs: [String],
        kind: CardKind,
        metadata: CardMetadata = .generic,
        title: String,
        subtitle: String = "",
        frontText: String = "",
        backText: String = "",
        tags: [String] = [],
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.deckIDs = deckIDs
        self.suitIDs = suitIDs
        self.kind = kind
        self.metadata = metadata
        self.title = title
        self.subtitle = subtitle
        self.frontText = frontText
        self.backText = backText
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        deckIDs = try c.decodeIfPresent([String].self, forKey: .deckIDs) ?? []
        suitIDs = try c.decodeIfPresent([String].self, forKey: .suitIDs) ?? []
        kind = try c.decodeIfPresent(CardKind.self, forKey: .kind) ?? .action
        metadata = try c.decodeIfPresent(CardMetadata.self, forKey: .metadata) ?? .generic
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        frontText = try c.decodeIfPresent(String.self, forKey: .frontText) ?? ""
        backText = try c.decodeIfPresent(String.self, forKey: .backText) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Every string a free-text search should be able to match against.
    public var searchableText: [String] {
        [title, subtitle, frontText, backText] + tags + metadata.searchableText
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter KnowledgeCardTests
```
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add Sources/StrategyDeckCore/Models/KnowledgeCard.swift Tests/StrategyDeckCoreTests/KnowledgeCardTests.swift
git commit -m "feat: add KnowledgeCard, the polymorphic card model"
```

---

## Task 7: `StrategySequenceItem` + `StrategySequence`

**Files:**
- Create: `Sources/StrategyDeckCore/Models/StrategySequenceItem.swift`
- Create: `Sources/StrategyDeckCore/Models/StrategySequence.swift`
- Test: `Tests/StrategyDeckCoreTests/StrategySequenceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class StrategySequenceTests: XCTestCase {
    func testNormalizedItemsAreSortedAndReindexedFromZero() {
        let sequence = StrategySequence(
            name: "Test",
            orderedItems: [
                StrategySequenceItem(cardID: UUID(), order: 5),
                StrategySequenceItem(cardID: UUID(), order: 2),
                StrategySequenceItem(cardID: UUID(), order: 9)
            ]
        )
        let normalized = sequence.normalizedItems
        XCTAssertEqual(normalized.map(\.order), [0, 1, 2])
    }

    func testDefaultsAreSensible() {
        let sequence = StrategySequence(name: "Test")
        XCTAssertEqual(sequence.description, "")
        XCTAssertEqual(sequence.scenario, "")
        XCTAssertTrue(sequence.deckIDs.isEmpty)
        XCTAssertTrue(sequence.orderedItems.isEmpty)
    }

    func testItemLenientDecodeRequiresOnlyCardID() throws {
        let json = """
        {"cardID":"\(UUID().uuidString)"}
        """.data(using: .utf8)!
        let decoded = try JSONCoding.decoder.decode(StrategySequenceItem.self, from: json)
        XCTAssertEqual(decoded.order, 0)
        XCTAssertEqual(decoded.note, "")
        XCTAssertNil(decoded.relationshipToPrevious)
    }

    func testRoundTripsJSON() throws {
        // Date.wholeSecondForTesting() (Tests/StrategyDeckCoreTests/TestSupport/
        // DateTestSupport.swift, added during Task 6) exists because
        // JSONCoding's .iso8601 date strategy has whole-second resolution — a
        // sub-second Date() never compares equal after round-tripping.
        let wholeSecond = Date.wholeSecondForTesting()
        let sequence = StrategySequence(
            name: "Reliable API Integration",
            description: "desc",
            scenario: "A production file is missing data.",
            orderedItems: [
                StrategySequenceItem(cardID: UUID(), order: 0, note: "start here", relationshipToPrevious: nil),
                StrategySequenceItem(cardID: UUID(), order: 1, relationshipToPrevious: .canFollow)
            ],
            createdAt: wholeSecond,
            updatedAt: wholeSecond
        )
        let encoded = try JSONCoding.encoder.encode(sequence)
        let decoded = try JSONCoding.decoder.decode(StrategySequence.self, from: encoded)
        XCTAssertEqual(decoded, sequence)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter StrategySequenceTests
```
Expected: FAIL — types don't exist yet.

- [ ] **Step 3: Implement `StrategySequenceItem`**

```swift
import Foundation

/// One ordered entry inside a ``StrategySequence`` — a reference to a card
/// plus an optional inline note and an optional explicit relationship to
/// the item before it (e.g. "then", or a specific ``CardRelationshipType``).
public struct StrategySequenceItem: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var order: Int
    public var note: String
    public var relationshipToPrevious: CardRelationshipType?

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        order: Int,
        note: String = "",
        relationshipToPrevious: CardRelationshipType? = nil
    ) {
        self.id = id
        self.cardID = cardID
        self.order = order
        self.note = note
        self.relationshipToPrevious = relationshipToPrevious
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        relationshipToPrevious = try c.decodeIfPresent(CardRelationshipType.self, forKey: .relationshipToPrevious)
    }
}
```

- [ ] **Step 4: Implement `StrategySequence`**

```swift
import Foundation

/// A named, ordered sequence of cards — the user's proposed flow (e.g.
/// "Estimate-to-Invoice Matching", or a Japanese communication strategy).
/// `deckIDs` and `scenario` exist for a later slice (cross-deck sequences);
/// nothing in this slice's UI populates `deckIDs` with more than one deck.
public struct StrategySequence: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var deckIDs: [String]
    public var scenario: String
    public var orderedItems: [StrategySequenceItem]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        deckIDs: [String] = [],
        scenario: String = "",
        orderedItems: [StrategySequenceItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.deckIDs = deckIDs
        self.scenario = scenario
        self.orderedItems = orderedItems
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        deckIDs = try c.decodeIfPresent([String].self, forKey: .deckIDs) ?? []
        scenario = try c.decodeIfPresent(String.self, forKey: .scenario) ?? ""
        orderedItems = try c.decodeIfPresent([StrategySequenceItem].self, forKey: .orderedItems) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Items sorted by `order`, with `order` re-normalized to 0..<n.
    public var normalizedItems: [StrategySequenceItem] {
        orderedItems
            .sorted { $0.order < $1.order }
            .enumerated()
            .map { index, item in
                var copy = item
                copy.order = index
                return copy
            }
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter StrategySequenceTests
```
Expected: PASS (4/4).

- [ ] **Step 6: Commit**

```bash
git add Sources/StrategyDeckCore/Models/StrategySequenceItem.swift Sources/StrategyDeckCore/Models/StrategySequence.swift Tests/StrategyDeckCoreTests/StrategySequenceTests.swift
git commit -m "feat: add StrategySequenceItem and StrategySequence"
```

---

## Task 8: `KnowledgeLibrary`

**Files:**
- Create: `Sources/StrategyDeckCore/Models/KnowledgeLibrary.swift`
- Test: `Tests/StrategyDeckCoreTests/KnowledgeLibraryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class KnowledgeLibraryTests: XCTestCase {
    func testDefaultsAreEmpty() {
        let library = KnowledgeLibrary()
        XCTAssertEqual(library.version, KnowledgeLibrary.currentVersion)
        XCTAssertTrue(library.decks.isEmpty)
        XCTAssertTrue(library.suits.isEmpty)
        XCTAssertTrue(library.cards.isEmpty)
        XCTAssertTrue(library.relationships.isEmpty)
        XCTAssertTrue(library.sequences.isEmpty)
    }

    func testRoundTripsJSON() throws {
        // See Date.wholeSecondForTesting()'s doc comment (TestSupport/DateTestSupport.swift).
        let wholeSecond = Date.wholeSecondForTesting()
        let library = KnowledgeLibrary(
            decks: [KnowledgeDeck(id: "d", name: "Deck")],
            suits: [CardSuit(id: "s", deckID: "d", name: "Suit")],
            cards: [KnowledgeCard(deckIDs: ["d"], suitIDs: ["s"], kind: .action, title: "Card", createdAt: wholeSecond, updatedAt: wholeSecond)],
            relationships: [CardRelationship(sourceCardID: UUID(), targetCardID: UUID(), type: .enables)],
            sequences: [StrategySequence(name: "Seq")]
        )
        let encoded = try JSONCoding.encoder.encode(library)
        let decoded = try JSONCoding.decoder.decode(KnowledgeLibrary.self, from: encoded)
        XCTAssertEqual(decoded.decks, library.decks)
        XCTAssertEqual(decoded.suits, library.suits)
        XCTAssertEqual(decoded.cards, library.cards)
        XCTAssertEqual(decoded.relationships, library.relationships)
        XCTAssertEqual(decoded.sequences.map(\.name), library.sequences.map(\.name))
    }

    func testLenientDecodeOfEmptyObjectUsesDefaults() throws {
        let decoded = try JSONCoding.decoder.decode(KnowledgeLibrary.self, from: "{}".data(using: .utf8)!)
        XCTAssertEqual(decoded.version, KnowledgeLibrary.currentVersion)
        XCTAssertTrue(decoded.cards.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter KnowledgeLibraryTests
```
Expected: FAIL — type doesn't exist yet.

- [ ] **Step 3: Implement `KnowledgeLibrary`**

```swift
import Foundation

/// The complete portable payload for import/export and the bundled seed —
/// replaces `AppData`. A single value round-trips the whole library.
public struct KnowledgeLibrary: Codable, Sendable {
    /// Schema version, so future migrations can detect old files.
    public var version: Int
    public var decks: [KnowledgeDeck]
    public var suits: [CardSuit]
    public var cards: [KnowledgeCard]
    public var relationships: [CardRelationship]
    public var sequences: [StrategySequence]

    public static let currentVersion = 1

    public init(
        version: Int = KnowledgeLibrary.currentVersion,
        decks: [KnowledgeDeck] = [],
        suits: [CardSuit] = [],
        cards: [KnowledgeCard] = [],
        relationships: [CardRelationship] = [],
        sequences: [StrategySequence] = []
    ) {
        self.version = version
        self.decks = decks
        self.suits = suits
        self.cards = cards
        self.relationships = relationships
        self.sequences = sequences
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? KnowledgeLibrary.currentVersion
        decks = try c.decodeIfPresent([KnowledgeDeck].self, forKey: .decks) ?? []
        suits = try c.decodeIfPresent([CardSuit].self, forKey: .suits) ?? []
        cards = try c.decodeIfPresent([KnowledgeCard].self, forKey: .cards) ?? []
        relationships = try c.decodeIfPresent([CardRelationship].self, forKey: .relationships) ?? []
        sequences = try c.decodeIfPresent([StrategySequence].self, forKey: .sequences) ?? []
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter KnowledgeLibraryTests
```
Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```bash
git add Sources/StrategyDeckCore/Models/KnowledgeLibrary.swift Tests/StrategyDeckCoreTests/KnowledgeLibraryTests.swift
git commit -m "feat: add KnowledgeLibrary, the root import/export/seed document"
```

---

## Task 9: `CardFilter`

**Files:**
- Create: `Sources/StrategyDeckCore/Services/CardFilter.swift`
- Test: `Tests/StrategyDeckCoreTests/CardFilterTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import StrategyDeckCore

final class CardFilterTests: XCTestCase {
    private func suits() -> [CardSuit] {
        [
            CardSuit(id: "search", deckID: "d", name: "Search"),
            CardSuit(id: "transformation", deckID: "d", name: "Transformation"),
            CardSuit(id: "search-sub", deckID: "d", parentSuitID: "search", name: "Search Sub")
        ]
    }

    private func cards() -> [KnowledgeCard] {
        [
            KnowledgeCard(deckIDs: ["d"], suitIDs: ["search"], kind: .action,
                          metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "Find target in sorted collection", mechanism: "Halve the search space")),
                          title: "Binary Search", tags: ["sorted", "logarithmic"]),
            KnowledgeCard(deckIDs: ["d"], suitIDs: ["search-sub"], kind: .action,
                          metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "Repeatedly checking whether values exist", mechanism: "Insert into hash map")),
                          title: "Hash-Based Lookup", tags: ["hash", "dictionary"]),
            KnowledgeCard(deckIDs: ["d"], suitIDs: ["transformation"], kind: .action,
                          metadata: .softwareStrategy(SoftwareStrategyFields(trigger: "Transform every element", mechanism: "Apply function to each")),
                          title: "Map", tags: ["transform"]),
            KnowledgeCard(deckIDs: ["other-deck"], suitIDs: ["search"], kind: .action, title: "Different Deck Card")
        ]
    }

    func testEmptyFilterReturnsAll() {
        XCTAssertEqual(CardFilter().apply(to: cards()).count, 4)
    }

    func testQueryMatchesTitle() {
        let result = CardFilter(query: "binary").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testQueryMatchesMetadataMechanism() {
        let result = CardFilter(query: "halve").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testQueryMatchesTag() {
        let result = CardFilter(query: "logarithmic").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testDeckIDScopesToOneDeck() {
        let result = CardFilter(deckID: "other-deck").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Different Deck Card"])
    }

    func testSuiteFilterMatchesExactSuite() {
        let result = CardFilter(suitID: "transformation").apply(to: cards(), suits: suits())
        XCTAssertEqual(result.map(\.title), ["Map"])
    }

    func testSuiteFilterExpandsToDescendantSuits() {
        let result = CardFilter(suitID: "search").apply(to: cards(), suits: suits())
        XCTAssertEqual(Set(result.map(\.title)), Set(["Binary Search", "Hash-Based Lookup", "Different Deck Card"]))
    }

    func testFavoritesFilter() {
        var c = cards()
        c[0].isFavorite = true
        let result = CardFilter(favoritesOnly: true).apply(to: c)
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }

    func testFavoritesFirstInSort() {
        var c = cards()
        c[2].isFavorite = true
        let result = CardFilter().apply(to: c)
        XCTAssertEqual(result.first?.title, "Map")
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(CardFilter(query: "xyzzy_no_match").apply(to: cards()).isEmpty)
    }

    func testMultiWordQueryRequiresAllTermsSomewhere() {
        let result = CardFilter(query: "binary sorted").apply(to: cards())
        XCTAssertEqual(result.map(\.title), ["Binary Search"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardFilterTests
```
Expected: FAIL — type doesn't exist yet.

- [ ] **Step 3: Implement `CardFilter`**

```swift
import Foundation

/// Pure, testable search + filtering over a set of cards. Free of any UI
/// type so it's directly unit-testable and reusable from any surface.
public struct CardFilter: Equatable, Sendable {
    /// Free-text query matched against every card's `searchableText`.
    public var query: String
    /// When set, only cards belonging to this deck are returned.
    public var deckID: String?
    /// When set, only cards in this suit (or one of its descendant
    /// sub-suits) are returned.
    public var suitID: String?
    /// When true, only favorited cards are returned.
    public var favoritesOnly: Bool

    public init(query: String = "", deckID: String? = nil, suitID: String? = nil, favoritesOnly: Bool = false) {
        self.query = query
        self.deckID = deckID
        self.suitID = suitID
        self.favoritesOnly = favoritesOnly
    }

    public var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || deckID != nil
            || suitID != nil
            || favoritesOnly
    }

    /// Applies the filter and returns cards sorted favorites-first, then by
    /// title. `suits` is only needed when `suitID` is set — it's used to
    /// expand the selected suit to include its descendant sub-suits.
    public func apply(to cards: [KnowledgeCard], suits: [CardSuit] = []) -> [KnowledgeCard] {
        let terms = query
            .lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map(String.init)

        let allowedSuitIDs: Set<String>? = suitID.map { suits.descendantIDs(of: $0) }

        let filtered = cards.filter { card in
            if let deckID, !card.deckIDs.contains(deckID) { return false }
            if let allowedSuitIDs, !card.suitIDs.contains(where: allowedSuitIDs.contains) { return false }
            if favoritesOnly, !card.isFavorite { return false }
            guard !terms.isEmpty else { return true }
            let haystack = card.searchableText.map { $0.lowercased() }
            return terms.allSatisfy { term in haystack.contains { $0.contains(term) } }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CardFilterTests
```
Expected: PASS (11/11).

- [ ] **Step 5: Commit**

```bash
git add Sources/StrategyDeckCore/Services/CardFilter.swift Tests/StrategyDeckCoreTests/CardFilterTests.swift
git commit -m "feat: add CardFilter, generalized search/filter over KnowledgeCard"
```

---

## Task 10: Full cutover — Core + UI

This is one atomic task. `Sources/StrategyDeck` and `Sources/StrategyDeckCore` compile as part of one package graph, and `swift test` builds both — there is no way to swap `StrategyStore` for `CardStore` (for example) without every UI file that touches it changing in the same commit, so this task does the whole cutover and verifies once at the end, per the rationale in this plan's header.

**Files:**
- Modify: `Sources/StrategyDeckCore/Persistence/SeedCardProvider.swift`
- Modify: `Sources/StrategyDeckCore/Persistence/JSONPersistenceService.swift`
- Modify: `Sources/StrategyDeckCore/Services/ImportExportService.swift`
- Create: `Sources/StrategyDeckCore/Persistence/CardStore.swift`
- Delete: `Sources/StrategyDeckCore/Persistence/StrategyStore.swift`
- Create: `Sources/StrategyDeckCore/Persistence/SequenceStore.swift`
- Delete: `Sources/StrategyDeckCore/Persistence/LoadoutStore.swift`
- Delete: `Sources/StrategyDeckCore/Services/StrategyFilter.swift`
- Delete: `Sources/StrategyDeckCore/Models/AppData.swift`, `StrategyCard.swift`, `StrategySuite.swift`, `StrategyLoadout.swift`, `LoadoutItem.swift`
- Create: `Tests/StrategyDeckCoreTests/TestSupport/InMemoryPersistence.swift`
- Delete: `Tests/StrategyDeckCoreTests/LoadoutTests.swift`; Create: `Tests/StrategyDeckCoreTests/SequenceStoreTests.swift`
- Modify: `Tests/StrategyDeckCoreTests/MalformedJSONTests.swift`, `PersistenceTests.swift`, `ResetTests.swift`, `SeedDecodingTests.swift`
- Delete: `Tests/StrategyDeckCoreTests/SearchFilterTests.swift`
- Modify: `Sources/StrategyDeck/App/AppEnvironment.swift`
- Modify: `Sources/StrategyDeck/WindowManagement/FloatingPanelController.swift`
- Modify: `Sources/StrategyDeck/Views/MenuBar/MenuBarContentView.swift`
- Modify: `Sources/StrategyDeck/Views/Settings/SettingsView.swift`
- Modify: `Sources/StrategyDeck/Components/SuiteBadge.swift`
- Modify: `Sources/StrategyDeck/Views/Cards/StrategyCardView.swift` → rewritten in place as `KnowledgeCardView.swift`
- Modify: `Sources/StrategyDeck/Views/Cards/StrategyCardDetailView.swift` → rewritten in place as `KnowledgeCardDetailView.swift`
- Modify: `Sources/StrategyDeck/Views/Cards/CardEditorView.swift` → rewritten in place as `KnowledgeCardEditorView.swift`
- Delete: `Sources/StrategyDeck/Views/Suites/SuiteSelectorView.swift`; Create: `Sources/StrategyDeck/Views/Suites/DeckSuitTreeView.swift`
- Modify: `Sources/StrategyDeck/Views/Panel/HeaderView.swift`
- Modify: `Sources/StrategyDeck/Views/Panel/PanelRootView.swift`
- Modify: `Sources/StrategyDeck/Views/Loadouts/LoadoutTrayView.swift` → rewritten in place as `Sources/StrategyDeck/Views/Sequences/SequenceTrayView.swift`
- Modify: `Sources/StrategyDeck/Views/Loadouts/LoadoutManagerView.swift` → rewritten in place as `Sources/StrategyDeck/Views/Sequences/SequenceManagerView.swift`

### Part A — Core: seed data, persistence, stores

- [ ] **Step 1: Rewrite `SeedCardProvider` to build a `KnowledgeLibrary`**

The 46 existing card literals (`StrategyCard(name: ..., suite: ..., ...)`) never set `id`, `isFavorite`, `createdAt`, `updatedAt`, `personalNotes`, `relatedStrategyIDs`, or `combinesWellWithIDs` (verified: `grep -c` for each of those parameter names across the file returns 0 except one false-positive substring match inside a code example string). So the migration only needs to reroute the fields they *do* set into the new shape — no per-card content is lost or needs individual editing.

First, add a private helper with the same parameter list as the old `StrategyCard.init`, so the 46 call sites can be repointed with a single mechanical rename in the next step. Add this near the top of the `SeedCardProvider` enum, right after the `makeAppData()`/`allCards()` declarations:

```swift
    private static let softwareEngineeringDeckID = "software-engineering"

    /// Builds a `KnowledgeCard` from the same parameter shape the old
    /// `StrategyCard` literals use, so the 46 existing card definitions
    /// below only need `StrategyCard(` renamed to `card(`, not rewritten.
    /// `iconName` is accepted but unused — no view ever read `card.iconName`
    /// (verified via grep), and `KnowledgeCard` has no such field; it's kept
    /// here purely so none of the 46 call sites need editing.
    private static func card(
        name: String,
        suite: String,
        iconName: String = "square.stack.3d.up",
        tags: [String] = [],
        trigger: String = "",
        problemShape: String = "",
        desiredResult: String = "",
        mechanism: String = "",
        requirements: [String] = [],
        advantages: [String] = [],
        costs: [String] = [],
        failureModes: [String] = [],
        timeComplexity: String = "",
        spaceComplexity: String = "",
        flowDescription: String = "",
        codeExample: String = "",
        realWorldExample: String = ""
    ) -> KnowledgeCard {
        KnowledgeCard(
            deckIDs: [softwareEngineeringDeckID],
            suitIDs: [suite],
            kind: .action,
            metadata: .softwareStrategy(SoftwareStrategyFields(
                trigger: trigger,
                problemShape: problemShape,
                desiredResult: desiredResult,
                mechanism: mechanism,
                requirements: requirements,
                advantages: advantages,
                costs: costs,
                failureModes: failureModes,
                timeComplexity: timeComplexity,
                spaceComplexity: spaceComplexity,
                flowDescription: flowDescription,
                codeExample: codeExample,
                realWorldExample: realWorldExample
            )),
            title: name,
            tags: tags
        )
    }
```

Then, using Edit with `replace_all: true` on `Sources/StrategyDeckCore/Persistence/SeedCardProvider.swift`:

old_string: `StrategyCard(`
new_string: `card(`
(46 occurrences — every card literal call site)

Then, using Edit with `replace_all: true` on the same file:

old_string: `-> [StrategyCard] {`
new_string: `-> [KnowledgeCard] {`
(7 occurrences — `allCards()` and the six `*Cards()` functions)

Finally, replace the `makeAppData()` function with `makeLibrary()`. Using Edit:

old_string:
```
    public static func makeAppData() -> AppData {
        AppData(
            version: AppData.currentVersion,
            suites: StrategySuite.defaults,
            cards: allCards(),
            loadouts: []
        )
    }
```
new_string:
```
    public static func makeLibrary() -> KnowledgeLibrary {
        let deck = KnowledgeDeck(
            id: softwareEngineeringDeckID,
            name: "Software Engineering",
            description: "Programming and algorithmic problem-solving techniques.",
            iconName: "square.stack.3d.up",
            displayOrder: 0
        )
        let suits: [CardSuit] = [
            CardSuit(id: "search",         deckID: softwareEngineeringDeckID, name: "Search",         iconName: "magnifyingglass",             displayOrder: 0),
            CardSuit(id: "transformation", deckID: softwareEngineeringDeckID, name: "Transformation", iconName: "arrow.triangle.2.circlepath", displayOrder: 1),
            CardSuit(id: "structure",      deckID: softwareEngineeringDeckID, name: "Structure",      iconName: "square.grid.2x2",             displayOrder: 2),
            CardSuit(id: "state",          deckID: softwareEngineeringDeckID, name: "State",          iconName: "circle.hexagongrid",          displayOrder: 3),
            CardSuit(id: "reliability",    deckID: softwareEngineeringDeckID, name: "Reliability",    iconName: "shield.lefthalf.filled",      displayOrder: 4),
            CardSuit(id: "debugging",      deckID: softwareEngineeringDeckID, name: "Debugging",      iconName: "ladybug",                     displayOrder: 5)
        ]
        return KnowledgeLibrary(decks: [deck], suits: suits, cards: allCards(), relationships: [], sequences: [])
    }
```

- [ ] **Step 2: Update `PersistenceService` and `JSONPersistenceService`**

Using Edit on `Sources/StrategyDeckCore/Persistence/JSONPersistenceService.swift`:

old_string:
```
    /// The bundled read-only seed shipped inside the app.
    func loadBundledSeed() throws -> AppData
```
new_string:
```
    /// The bundled read-only seed shipped inside the app.
    func loadBundledLibrary() throws -> KnowledgeLibrary
```

old_string:
```
    public func loadBundledSeed() throws -> AppData {
        // Seed is defined as Swift code in SeedCardProvider so there is no
        // JSON resource file to decode — the seed always matches the model.
        return SeedCardProvider.makeAppData()
    }
```
new_string:
```
    public func loadBundledLibrary() throws -> KnowledgeLibrary {
        // Seed is defined as Swift code in SeedCardProvider so there is no
        // JSON resource file to decode — the seed always matches the model.
        return SeedCardProvider.makeLibrary()
    }
```

- [ ] **Step 3: Update `ImportExportService`**

Using Edit with `replace_all: true` on `Sources/StrategyDeckCore/Services/ImportExportService.swift`:

old_string: `AppData`
new_string: `KnowledgeLibrary`
(3 occurrences: the `export`, `import`, and `importFile` signatures)

- [ ] **Step 4: Create `CardStore`, delete `StrategyStore`**

```bash
git rm Sources/StrategyDeckCore/Persistence/StrategyStore.swift
```

Create `Sources/StrategyDeckCore/Persistence/CardStore.swift`:

```swift
import Foundation

/// Manages the in-memory + persisted library: cards, decks, suits, and the
/// relationship graph between cards. All mutations go through this store;
/// UI reads via `@Published` properties. Persistence errors are surfaced
/// through `lastError` so the UI can alert.
@MainActor
public final class CardStore: ObservableObject {
    @Published public private(set) var cards: [KnowledgeCard] = []
    @Published public private(set) var decks: [KnowledgeDeck] = []
    @Published public private(set) var suits: [CardSuit] = []
    @Published public private(set) var relationships: [CardRelationship] = []
    @Published public var lastError: Error?

    private let persistence: PersistenceService
    private static let cardsFilename = "cards.json"
    private static let decksFilename = "decks.json"
    private static let suitsFilename = "suits.json"
    private static let relationshipsFilename = "relationships.json"

    public init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    // MARK: - Boot

    /// Call once on launch. Copies seed data on first run, then loads from disk.
    public func loadOrSeed() {
        let needsSeed = !persistence.fileExists(Self.cardsFilename)
        if needsSeed {
            do {
                let seed = try persistence.loadBundledLibrary()
                try persistence.save(seed.cards, to: Self.cardsFilename)
                try persistence.save(seed.decks, to: Self.decksFilename)
                try persistence.save(seed.suits, to: Self.suitsFilename)
                try persistence.save(seed.relationships, to: Self.relationshipsFilename)
                cards = seed.cards
                decks = seed.decks
                suits = seed.suits
                relationships = seed.relationships
            } catch {
                lastError = error
            }
            return
        }
        do {
            cards = try persistence.load([KnowledgeCard].self, from: Self.cardsFilename)
            decks = (try? persistence.load([KnowledgeDeck].self, from: Self.decksFilename)) ?? []
            suits = (try? persistence.load([CardSuit].self, from: Self.suitsFilename)) ?? []
            relationships = (try? persistence.load([CardRelationship].self, from: Self.relationshipsFilename)) ?? []
        } catch {
            lastError = error
        }
    }

    // MARK: - Mutations

    public func add(_ card: KnowledgeCard) {
        cards.append(card)
        save()
    }

    public func update(_ card: KnowledgeCard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.updatedAt = Date()
        cards[idx] = updated
        save()
    }

    public func delete(id: UUID) {
        cards.removeAll { $0.id == id }
        save()
    }

    public func toggleFavorite(id: UUID) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[idx].isFavorite.toggle()
        cards[idx].updatedAt = Date()
        save()
    }

    public func duplicate(_ card: KnowledgeCard) {
        var copy = card
        copy.id = UUID()
        copy.title = card.title + " (copy)"
        copy.isFavorite = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        cards.append(copy)
        save()
    }

    // MARK: - Suit tree lookups

    public func rootSuits(forDeck deckID: String) -> [CardSuit] {
        suits.rootSuits(deckID: deckID)
    }

    public func childSuits(of suitID: String) -> [CardSuit] {
        suits.children(of: suitID)
    }

    // MARK: - Reset

    /// Replaces all cards with the bundled seed, discarding user edits to cards.
    public func resetToSeed() {
        do {
            let seed = try persistence.loadBundledLibrary()
            cards = seed.cards
            try persistence.save(cards, to: Self.cardsFilename)
        } catch {
            lastError = error
        }
    }

    // MARK: - Import / Export

    public func importLibrary(_ library: KnowledgeLibrary, merging: Bool = false) {
        if merging {
            let existingCardIDs = Set(cards.map(\.id))
            cards.append(contentsOf: library.cards.filter { !existingCardIDs.contains($0.id) })
            let existingSuitIDs = Set(suits.map(\.id))
            suits.append(contentsOf: library.suits.filter { !existingSuitIDs.contains($0.id) })
            let existingDeckIDs = Set(decks.map(\.id))
            decks.append(contentsOf: library.decks.filter { !existingDeckIDs.contains($0.id) })
            let existingRelationshipIDs = Set(relationships.map(\.id))
            relationships.append(contentsOf: library.relationships.filter { !existingRelationshipIDs.contains($0.id) })
        } else {
            cards = library.cards
            if !library.decks.isEmpty { decks = library.decks }
            if !library.suits.isEmpty { suits = library.suits }
            relationships = library.relationships
        }
        save()
    }

    public func exportLibrary(sequences: [StrategySequence]) -> KnowledgeLibrary {
        KnowledgeLibrary(decks: decks, suits: suits, cards: cards, relationships: relationships, sequences: sequences)
    }

    // MARK: - Private

    private func save() {
        do {
            try persistence.save(cards, to: Self.cardsFilename)
        } catch {
            lastError = error
        }
    }
}
```

- [ ] **Step 5: Create `SequenceStore`, delete `LoadoutStore`**

```bash
git rm Sources/StrategyDeckCore/Persistence/LoadoutStore.swift
```

Create `Sources/StrategyDeckCore/Persistence/SequenceStore.swift`:

```swift
import Foundation

/// Manages saved sequences and the current (unsaved) working tray.
@MainActor
public final class SequenceStore: ObservableObject {
    /// The current unsaved tray — items the user has placed during this session.
    @Published public var trayItems: [StrategySequenceItem] = []
    /// All saved, named sequences.
    @Published public private(set) var savedSequences: [StrategySequence] = []
    @Published public var lastError: Error?

    private let persistence: PersistenceService
    private static let filename = "sequences.json"

    public init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    // MARK: - Boot

    public func load() {
        guard persistence.fileExists(Self.filename) else { return }
        do {
            savedSequences = try persistence.load([StrategySequence].self, from: Self.filename)
        } catch {
            lastError = error
        }
    }

    // MARK: - Tray

    public func addToTray(cardID: UUID) {
        let order = (trayItems.map(\.order).max() ?? -1) + 1
        trayItems.append(StrategySequenceItem(cardID: cardID, order: order))
    }

    public func removeFromTray(id: UUID) {
        trayItems.removeAll { $0.id == id }
        renormalizeOrder()
    }

    public func moveTrayItem(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let item = trayItems.remove(at: sourceIndex)
        let adjusted = destination > sourceIndex ? destination - 1 : destination
        trayItems.insert(item, at: min(adjusted, trayItems.count))
        renormalizeOrder()
    }

    public func updateNote(for itemID: UUID, note: String) {
        guard let idx = trayItems.firstIndex(where: { $0.id == itemID }) else { return }
        trayItems[idx].note = note
    }

    public func clearTray() {
        trayItems = []
    }

    private func renormalizeOrder() {
        for idx in trayItems.indices {
            trayItems[idx].order = idx
        }
    }

    // MARK: - Saved Sequences

    public func saveSequence(name: String, description: String, scenario: String = "") {
        let sorted = trayItems.sorted { $0.order < $1.order }
        let sequence = StrategySequence(name: name, description: description, scenario: scenario, orderedItems: sorted)
        savedSequences.append(sequence)
        persist()
    }

    public func openSequence(_ sequence: StrategySequence) {
        trayItems = sequence.normalizedItems
    }

    public func deleteSequence(id: UUID) {
        savedSequences.removeAll { $0.id == id }
        persist()
    }

    public func updateSequence(_ sequence: StrategySequence) {
        guard let idx = savedSequences.firstIndex(where: { $0.id == sequence.id }) else { return }
        var updated = sequence
        updated.updatedAt = Date()
        savedSequences[idx] = updated
        persist()
    }

    public func importSequences(_ sequences: [StrategySequence], merging: Bool = false) {
        if merging {
            let existingIDs = Set(savedSequences.map(\.id))
            savedSequences.append(contentsOf: sequences.filter { !existingIDs.contains($0.id) })
        } else {
            savedSequences = sequences
        }
        persist()
    }

    // MARK: - Private

    private func persist() {
        do {
            try persistence.save(savedSequences, to: Self.filename)
        } catch {
            lastError = error
        }
    }
}
```

- [ ] **Step 6: Delete `StrategyFilter` (superseded by `CardFilter`)**

```bash
git rm Sources/StrategyDeckCore/Services/StrategyFilter.swift
```

- [ ] **Step 7: Delete the old models**

```bash
git rm Sources/StrategyDeckCore/Models/AppData.swift Sources/StrategyDeckCore/Models/StrategyCard.swift Sources/StrategyDeckCore/Models/StrategySuite.swift Sources/StrategyDeckCore/Models/StrategyLoadout.swift Sources/StrategyDeckCore/Models/LoadoutItem.swift
```

### Part B — Core tests

- [ ] **Step 8: Extract `InMemoryPersistence` into shared test support**

Create `Tests/StrategyDeckCoreTests/TestSupport/InMemoryPersistence.swift`:

```swift
import Foundation
@testable import StrategyDeckCore

/// In-memory persistence for tests — holds data in a dictionary, never touches disk.
final class InMemoryPersistence: PersistenceService {
    var storage: [String: Data] = [:]
    let containerDirectory = URL(fileURLWithPath: "/tmp/test-\(UUID().uuidString)")

    func url(for filename: String) -> URL { containerDirectory.appendingPathComponent(filename) }
    func fileExists(_ filename: String) -> Bool { storage[filename] != nil }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        guard let data = storage[filename] else {
            throw PersistenceError.decodeFailed(path: filename, underlying: NSError(domain: "test", code: 0))
        }
        return try JSONCoding.decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        storage[filename] = try JSONCoding.encoder.encode(value)
    }

    func delete(_ filename: String) throws { storage.removeValue(forKey: filename) }

    func loadBundledLibrary() throws -> KnowledgeLibrary { SeedCardProvider.makeLibrary() }
}
```

- [ ] **Step 9: Replace `LoadoutTests.swift` with `SequenceStoreTests.swift`**

```bash
git rm Tests/StrategyDeckCoreTests/LoadoutTests.swift
```

Create `Tests/StrategyDeckCoreTests/SequenceStoreTests.swift`:

```swift
import XCTest
@testable import StrategyDeckCore

@MainActor
final class SequenceStoreTests: XCTestCase {

    private func makeStore() -> SequenceStore {
        SequenceStore(persistence: InMemoryPersistence())
    }

    func testAddToTray() {
        let store = makeStore()
        let id = UUID()
        store.addToTray(cardID: id)
        XCTAssertEqual(store.trayItems.count, 1)
        XCTAssertEqual(store.trayItems.first?.cardID, id)
    }

    func testRemoveFromTray() {
        let store = makeStore()
        let id = UUID()
        store.addToTray(cardID: id)
        guard let itemID = store.trayItems.first?.id else { return XCTFail() }
        store.removeFromTray(id: itemID)
        XCTAssertTrue(store.trayItems.isEmpty)
    }

    func testClearTray() {
        let store = makeStore()
        store.addToTray(cardID: UUID())
        store.addToTray(cardID: UUID())
        store.clearTray()
        XCTAssertTrue(store.trayItems.isEmpty)
    }

    func testReorderTray() {
        let store = makeStore()
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        store.addToTray(cardID: id1)
        store.addToTray(cardID: id2)
        store.addToTray(cardID: id3)

        store.moveTrayItem(from: IndexSet(integer: 0), to: 2)

        let ordered = store.trayItems.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.map(\.order), Array(0..<3))
    }

    func testSaveAndOpenSequence() {
        let store = makeStore()
        let id = UUID()
        store.addToTray(cardID: id)
        store.saveSequence(name: "My Sequence", description: "Test")

        XCTAssertEqual(store.savedSequences.count, 1)
        XCTAssertEqual(store.savedSequences.first?.name, "My Sequence")

        store.clearTray()
        XCTAssertTrue(store.trayItems.isEmpty)

        store.openSequence(store.savedSequences[0])
        XCTAssertEqual(store.trayItems.count, 1)
        XCTAssertEqual(store.trayItems.first?.cardID, id)
    }

    func testDeleteSequence() {
        let store = makeStore()
        store.addToTray(cardID: UUID())
        store.saveSequence(name: "To Delete", description: "")
        guard let id = store.savedSequences.first?.id else { return XCTFail() }
        store.deleteSequence(id: id)
        XCTAssertTrue(store.savedSequences.isEmpty)
    }
}
```

- [ ] **Step 10: Rewrite `MalformedJSONTests.swift`**

```swift
import XCTest
@testable import StrategyDeckCore

final class MalformedJSONTests: XCTestCase {
    private var tempDir: URL!
    private var persistence: JSONPersistenceService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        persistence = JSONPersistenceService(containerDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testMalformedJSONThrowsDecodeFailed() {
        let bad = "{ not valid json !!!".data(using: .utf8)!
        try! bad.write(to: persistence.url(for: "cards.json"))
        XCTAssertThrowsError(try persistence.load([KnowledgeCard].self, from: "cards.json")) { error in
            if case PersistenceError.decodeFailed = error { /* expected */ }
            else { XCTFail("Expected decodeFailed, got \(error)") }
        }
    }

    func testWrongTypeThrowsDecodeFailed() throws {
        let encoded = try JSONCoding.encoder.encode([1, 2, 3])
        try encoded.write(to: persistence.url(for: "cards.json"))
        XCTAssertThrowsError(try persistence.load(KnowledgeCard.self, from: "cards.json")) { error in
            if case PersistenceError.decodeFailed = error { /* expected */ }
            else { XCTFail("Unexpected error type: \(error)") }
        }
    }

    func testMissingFileThrowsDecodeFailed() {
        XCTAssertThrowsError(try persistence.load([KnowledgeCard].self, from: "nonexistent.json"))
    }

    func testCardWithMissingOptionalFieldsDecodes() throws {
        let json = """
        [{"title":"Minimal Card"}]
        """.data(using: .utf8)!
        try json.write(to: persistence.url(for: "cards.json"))
        let loaded = try persistence.load([KnowledgeCard].self, from: "cards.json")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Minimal Card")
        XCTAssertEqual(loaded.first?.kind, .action)
        XCTAssertTrue(loaded.first?.suitIDs.isEmpty ?? false)
        XCTAssertTrue(loaded.first?.tags.isEmpty ?? false)
    }

    func testImportExportRoundTrip() throws {
        let service = ImportExportService()
        let original = SeedCardProvider.makeLibrary()
        let exported = try service.export(original)
        let imported = try service.import(from: exported)
        XCTAssertEqual(original.cards.count, imported.cards.count)
    }

    func testImportInvalidJSONThrows() {
        let service = ImportExportService()
        let bad = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try service.import(from: bad))
    }
}
```

- [ ] **Step 11: Rewrite `PersistenceTests.swift`**

```swift
import XCTest
@testable import StrategyDeckCore

final class PersistenceTests: XCTestCase {
    private var tempDir: URL!
    private var persistence: JSONPersistenceService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        persistence = JSONPersistenceService(containerDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoadCards() throws {
        let card = KnowledgeCard(deckIDs: ["software-engineering"], suitIDs: ["search"], kind: .action, title: "Test Card")
        let cards = [card]
        try persistence.save(cards, to: "cards.json")
        let loaded = try persistence.load([KnowledgeCard].self, from: "cards.json")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Test Card")
    }

    func testFileExistsAfterSave() throws {
        try persistence.save([KnowledgeCard](), to: "cards.json")
        XCTAssertTrue(persistence.fileExists("cards.json"))
    }

    func testDeleteRemovesFile() throws {
        try persistence.save([KnowledgeCard](), to: "cards.json")
        try persistence.delete("cards.json")
        XCTAssertFalse(persistence.fileExists("cards.json"))
    }

    func testSeedLoadsCards() throws {
        let seed = try persistence.loadBundledLibrary()
        XCTAssertFalse(seed.cards.isEmpty)
    }

    func testURLForFilename() {
        let url = persistence.url(for: "test.json")
        XCTAssertEqual(url.lastPathComponent, "test.json")
        XCTAssertTrue(url.path.hasPrefix(tempDir.path))
    }
}
```

- [ ] **Step 12: Rewrite `ResetTests.swift`**

```swift
import XCTest
@testable import StrategyDeckCore

@MainActor
final class ResetTests: XCTestCase {

    func testResetRestoresDefaultCards() {
        let mem = InMemoryPersistence()
        let store = CardStore(persistence: mem)
        store.loadOrSeed()

        let seedCount = store.cards.count

        store.add(KnowledgeCard(deckIDs: ["software-engineering"], suitIDs: ["debugging"], kind: .action, title: "My Custom Card"))
        XCTAssertEqual(store.cards.count, seedCount + 1)

        store.resetToSeed()
        XCTAssertEqual(store.cards.count, seedCount)
        XCTAssertFalse(store.cards.contains { $0.title == "My Custom Card" })
    }

    func testResetDoesNotAffectSequences() {
        let mem = InMemoryPersistence()
        let cardStore = CardStore(persistence: mem)
        let sequenceStore = SequenceStore(persistence: mem)
        cardStore.loadOrSeed()
        sequenceStore.load()

        let cardID = cardStore.cards.first!.id
        sequenceStore.addToTray(cardID: cardID)
        sequenceStore.saveSequence(name: "Keep Me", description: "")

        cardStore.resetToSeed()

        XCTAssertEqual(sequenceStore.savedSequences.count, 1)
        XCTAssertEqual(sequenceStore.savedSequences.first?.name, "Keep Me")
    }

    func testFirstLaunchSeedsFromProvider() {
        let mem = InMemoryPersistence()
        XCTAssertFalse(mem.fileExists("cards.json"))

        let store = CardStore(persistence: mem)
        store.loadOrSeed()

        XCTAssertFalse(store.cards.isEmpty, "Should have seeded cards on first launch")
        XCTAssertTrue(mem.fileExists("cards.json"), "Should have persisted seeded cards")
    }
}
```

- [ ] **Step 13: Rewrite `SeedDecodingTests.swift`**

```swift
import XCTest
@testable import StrategyDeckCore

final class SeedDecodingTests: XCTestCase {

    func testSeedLoads() {
        let library = SeedCardProvider.makeLibrary()
        XCTAssertFalse(library.cards.isEmpty, "Seed must contain at least one card")
    }

    func testSeedHasOneDeckWithSixSuites() {
        let library = SeedCardProvider.makeLibrary()
        XCTAssertEqual(library.decks.count, 1)
        XCTAssertEqual(library.decks.first?.id, "software-engineering")

        let suiteIDs = Set(library.suits.map(\.id))
        for expectedID in ["search", "transformation", "structure", "state", "reliability", "debugging"] {
            XCTAssertTrue(suiteIDs.contains(expectedID), "Missing suite: \(expectedID)")
        }
    }

    func testSeedCardCount() {
        let library = SeedCardProvider.makeLibrary()
        // At least 44 cards (8+7+8+6+9+8 = 46 in the current seed)
        XCTAssertGreaterThanOrEqual(library.cards.count, 44)
    }

    func testAllSeedCardsHaveTitles() {
        let library = SeedCardProvider.makeLibrary()
        for card in library.cards {
            XCTAssertFalse(card.title.isEmpty, "Card with id \(card.id) has no title")
        }
    }

    func testAllSeedCardsAreActionKindWithSoftwareStrategyMetadata() {
        let library = SeedCardProvider.makeLibrary()
        for card in library.cards {
            XCTAssertEqual(card.kind, .action)
            guard case .softwareStrategy(let fields) = card.metadata else {
                XCTFail("\(card.title) is missing softwareStrategy metadata")
                continue
            }
            XCTAssertFalse(fields.trigger.isEmpty, "\(card.title) has an empty trigger")
        }
    }

    func testSeedRoundTripsJSON() throws {
        let original = SeedCardProvider.makeLibrary()
        let encoded = try JSONCoding.encoder.encode(original)
        let decoded = try JSONCoding.decoder.decode(KnowledgeLibrary.self, from: encoded)
        XCTAssertEqual(original.cards.count, decoded.cards.count)
        XCTAssertEqual(original.cards.first?.title, decoded.cards.first?.title)
    }
}
```

- [ ] **Step 14: Delete `SearchFilterTests.swift` (superseded by `CardFilterTests` from Task 9)**

```bash
git rm Tests/StrategyDeckCoreTests/SearchFilterTests.swift
```

### Part C — UI

- [ ] **Step 15: `AppEnvironment`**

Replace the full contents of `Sources/StrategyDeck/App/AppEnvironment.swift`:

```swift
import Foundation
import StrategyDeckCore

/// Shared application state injected throughout the view hierarchy.
///
/// Owns the two stores and the service objects. Created once in AppDelegate.
@MainActor
final class AppEnvironment: ObservableObject {
    let cardStore: CardStore
    let sequenceStore: SequenceStore
    let importExport: ImportExportService

    init() {
        let persistence = JSONPersistenceService()
        cardStore = CardStore(persistence: persistence)
        sequenceStore = SequenceStore(persistence: persistence)
        importExport = ImportExportService()
    }

    func boot() {
        cardStore.loadOrSeed()
        sequenceStore.load()
    }
}
```

- [ ] **Step 16: `FloatingPanelController`**

Using Edit on `Sources/StrategyDeck/WindowManagement/FloatingPanelController.swift`:

old_string:
```
            .environmentObject(environment.strategyStore)
            .environmentObject(environment.loadoutStore)
```
new_string:
```
            .environmentObject(environment.cardStore)
            .environmentObject(environment.sequenceStore)
```

- [ ] **Step 17: `MenuBarContentView`**

Replace the full contents of `Sources/StrategyDeck/Views/MenuBar/MenuBarContentView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// The content shown inside the MenuBarExtra window.
///
/// Kept minimal — the full UI is in the floating panel.
struct MenuBarContentView: View {
    @EnvironmentObject var environment: AppEnvironment
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Strategy Deck")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(environment.cardStore.cards.count) cards")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if environment.sequenceStore.trayItems.isEmpty {
                Text("No cards selected.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                let items = environment.sequenceStore.trayItems.sorted { $0.order < $1.order }
                let cards = environment.cardStore.cards
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Sequence")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                    ForEach(items.prefix(6)) { item in
                        if let card = cards.first(where: { $0.id == item.cardID }) {
                            Text("→ \(card.title)")
                                .font(.system(size: 11))
                                .padding(.horizontal, 16)
                        }
                    }
                    if items.count > 6 {
                        Text("… and \(items.count - 6) more")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 6)
            }

            Divider()

            Button("Show Panel  ⌘⇧Space") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button("Settings…") { showingSettings = true }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            Button("Quit Strategy Deck") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(width: 240)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(environment)
        }
    }
}
```

- [ ] **Step 18: `SettingsView`**

Replace the full contents of `Sources/StrategyDeck/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

struct SettingsView: View {
    @EnvironmentObject var environment: AppEnvironment
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @State private var alertState: AlertState?
    @State private var showingExportSuccess = false
    @State private var defaultPinned = PanelFrameStore.savedPinned()

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .disabled(!launchAtLogin.isAvailable)

                if let err = launchAtLogin.lastError {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }

                Toggle("Pin panel by default", isOn: $defaultPinned)
                    .onChange(of: defaultPinned) { _, v in PanelFrameStore.save(pinned: v) }
            }

            Section("Global Shortcut") {
                HStack {
                    Text("Toggle panel")
                    Spacer()
                    Text("⌘⇧Space")
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.15)))
                }
                Text("Customizable shortcut configuration will be added in a future version.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Button("Export Cards & Sequences…") { exportData() }
                Button("Import Cards & Sequences…") { importData() }

                Divider()

                Button("Reset to Default Cards…", role: .destructive) {
                    alertState = .destructive(
                        title: "Reset to Default Cards?",
                        message: "Your custom cards will be permanently replaced with the built-in defaults. Saved sequences are not affected.",
                        confirmLabel: "Reset"
                    ) {
                        environment.cardStore.resetToSeed()
                    }
                }
            }

            Section("About") {
                Text("Strategy Deck — local-first, no account required.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 360, idealWidth: 400)
        .alertState($alertState)
    }

    // MARK: - Import / Export

    private func exportData() {
        let sequences = environment.sequenceStore.savedSequences
        let library = environment.cardStore.exportLibrary(sequences: sequences)
        guard let encoded = try? environment.importExport.export(library) else {
            alertState = .error(title: "Export Failed", "Could not encode the data for export.")
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "strategy-deck-export.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try encoded.write(to: url, options: [.atomic])
            } catch {
                alertState = .error(error)
            }
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let imported = try environment.importExport.importFile(at: url)
                alertState = AlertState(
                    title: "Import \(imported.cards.count) card(s)?",
                    message: "This will merge the imported cards and sequences into your library.",
                    primaryButton: nil,
                    primaryLabel: "Import"
                ) {
                    environment.cardStore.importLibrary(imported, merging: true)
                    environment.sequenceStore.importSequences(imported.sequences, merging: true)
                }
            } catch {
                alertState = .error(error)
            }
        }
    }
}
```

- [ ] **Step 19: `SuiteBadge`**

Replace the full contents of `Sources/StrategyDeck/Components/SuiteBadge.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// A small color + icon badge that identifies a suite.
///
/// Uses both color AND text initials so the interface is usable in grayscale
/// and for users with color-vision differences.
struct SuiteBadge: View {
    let suite: CardSuit
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(suiteColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.3)
                        .stroke(suiteColor.opacity(0.4), lineWidth: 0.5)
                )
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(suiteColor)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        String(suite.name.prefix(2)).uppercased()
    }

    var suiteColor: Color {
        SuiteColors.color(for: suite.id)
    }
}

/// Suite accent colors. Defined as stable named colors so they work in
/// both light and dark mode.
enum SuiteColors {
    static func color(for suiteID: String) -> Color {
        switch suiteID {
        case "search":         return .blue
        case "transformation": return .orange
        case "structure":      return .purple
        case "state":          return .green
        case "reliability":    return Color(red: 0.85, green: 0.15, blue: 0.15)
        case "debugging":      return Color(red: 0.7,  green: 0.5,  blue: 0.1)
        default:               return .secondary
        }
    }
}

#Preview {
    HStack {
        SuiteBadge(suite: CardSuit(id: "search", deckID: "software-engineering", name: "Search", iconName: "magnifyingglass", displayOrder: 0))
        SuiteBadge(suite: CardSuit(id: "reliability", deckID: "software-engineering", name: "Reliability", iconName: "shield.lefthalf.filled", displayOrder: 4))
    }
    .padding()
}
```

- [ ] **Step 20: `KnowledgeCardView` (rewrite of `StrategyCardView`)**

```bash
git mv Sources/StrategyDeck/Views/Cards/StrategyCardView.swift Sources/StrategyDeck/Views/Cards/KnowledgeCardView.swift
```

Replace the full contents of `Sources/StrategyDeck/Views/Cards/KnowledgeCardView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// The compact card shown in the grid. Intentionally small (~90pt tall).
struct KnowledgeCardView: View {
    let card: KnowledgeCard
    let suite: CardSuit?
    var isSelected: Bool = false
    let onTap: () -> Void
    let onAddToTray: () -> Void
    let onFavorite: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var accentColor: Color {
        suite.map { SuiteColors.color(for: $0.id) } ?? .secondary
    }

    private var softwareFields: SoftwareStrategyFields? {
        if case .softwareStrategy(let f) = card.metadata { return f }
        return nil
    }

    private var triggerSummary: String {
        let trigger = softwareFields?.trigger ?? ""
        return trigger.isEmpty ? "No trigger described yet." : trigger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                if let suite { SuiteBadge(suite: suite, size: 16) }
                Text(card.kind.symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(card.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if card.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
            }

            Divider().padding(.vertical, 4)

            Text(triggerSummary)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if let adv = softwareFields?.advantages.first, !adv.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.green)
                        Text(adv)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.spring(duration: 0.2)) { onAddToTray() }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .help("Add to Sequence")
            }

            if let cost = softwareFields?.costs.first, !cost.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.7))
                    Text(cost)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? accentColor.opacity(0.1)
                      : (isHovered ? Color(.controlBackgroundColor) : Color(.windowBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? accentColor.opacity(0.5) : Color(.separatorColor).opacity(0.6), lineWidth: isSelected ? 1 : 0.5)
                )
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .contextMenu { contextMenu }
        .draggable(card.id.uuidString)
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button { onAddToTray() } label: { Label("Add to Sequence", systemImage: "plus.circle") }
        Divider()
        Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
        Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        Button { onFavorite() } label: {
            Label(card.isFavorite ? "Unfavorite" : "Favorite", systemImage: card.isFavorite ? "star.slash" : "star")
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
    }
}
```

- [ ] **Step 21: `KnowledgeCardDetailView` (rewrite of `StrategyCardDetailView`)**

```bash
git mv Sources/StrategyDeck/Views/Cards/StrategyCardDetailView.swift Sources/StrategyDeck/Views/Cards/KnowledgeCardDetailView.swift
```

Replace the full contents of `Sources/StrategyDeck/Views/Cards/KnowledgeCardDetailView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// Full inspector for a card, shown as a sheet.
struct KnowledgeCardDetailView: View {
    let card: KnowledgeCard
    let suite: CardSuit?
    let allCards: [KnowledgeCard]
    let relationships: [CardRelationship]
    let onEdit: () -> Void
    let onAddToTray: () -> Void
    let onDismiss: () -> Void

    private var softwareFields: SoftwareStrategyFields? {
        if case .softwareStrategy(let f) = card.metadata { return f }
        return nil
    }

    /// Relationships where this card is either end, paired with the label to
    /// show (using the inverse label when this card is the target).
    private var relatedRows: [(label: String, card: KnowledgeCard)] {
        relationships.compactMap { rel in
            if rel.sourceCardID == card.id {
                guard let target = allCards.first(where: { $0.id == rel.targetCardID }) else { return nil }
                return (rel.type.label, target)
            } else if rel.targetCardID == card.id {
                guard let source = allCards.first(where: { $0.id == rel.sourceCardID }) else { return nil }
                return (rel.type.inverseLabel, source)
            }
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.escape)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        onAddToTray()
                        onDismiss()
                    } label: {
                        Label("Add to Sequence", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        onEdit()
                        onDismiss()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 10) {
                        if let suite { SuiteBadge(suite: suite, size: 30) }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(card.kind.symbol).font(.system(size: 13))
                                Text(card.title).font(.system(size: 17, weight: .bold))
                            }
                            if let suite {
                                Text(suite.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(SuiteColors.color(for: suite.id))
                            }
                        }
                        Spacer()
                    }

                    if !card.tags.isEmpty { TagRow(tags: card.tags) }

                    if let f = softwareFields {
                        Group {
                            if !f.trigger.isEmpty { detailSection("Trigger", f.trigger) }
                            if !f.problemShape.isEmpty { detailSection("Problem Shape", f.problemShape) }
                            if !f.desiredResult.isEmpty { detailSection("Desired Result", f.desiredResult) }
                            if !f.mechanism.isEmpty { detailSection("Mechanism", f.mechanism) }
                        }

                        if !f.requirements.isEmpty { bulletSection("Requirements", f.requirements) }

                        HStack(alignment: .top, spacing: 12) {
                            if !f.advantages.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    label("Advantages")
                                    ForEach(f.advantages, id: \.self) { Text("↑ \($0)").font(.system(size: 11)) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if !f.costs.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    label("Costs")
                                    ForEach(f.costs, id: \.self) { Text("↓ \($0)").font(.system(size: 11)) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !f.failureModes.isEmpty { bulletSection("Failure Modes", f.failureModes) }

                        if !f.timeComplexity.isEmpty || !f.spaceComplexity.isEmpty {
                            HStack(spacing: 20) {
                                if !f.timeComplexity.isEmpty { complexityBadge("Time", f.timeComplexity) }
                                if !f.spaceComplexity.isEmpty { complexityBadge("Space", f.spaceComplexity) }
                            }
                        }

                        if !f.flowDescription.isEmpty { detailSection("Flow", f.flowDescription) }

                        if !f.codeExample.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                label("Code Example")
                                Text(f.codeExample)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.08)))
                            }
                        }

                        if !f.realWorldExample.isEmpty { detailSection("Real-World Example", f.realWorldExample) }
                    }

                    if !relatedRows.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            label("Relationships")
                            ForEach(Array(relatedRows.enumerated()), id: \.offset) { _, row in
                                Text("\(row.label): \(row.card.title)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !card.backText.isEmpty { detailSection("Notes", card.backText) }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Subviews

    private func detailSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletSection(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title)
            ForEach(items, id: \.self) {
                Text("• \($0)").font(.system(size: 11))
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
    }

    private func complexityBadge(_ kind: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.1)))
    }
}
```

- [ ] **Step 22: `KnowledgeCardEditorView` (rewrite of `CardEditorView`)**

```bash
git mv Sources/StrategyDeck/Views/Cards/CardEditorView.swift Sources/StrategyDeck/Views/Cards/KnowledgeCardEditorView.swift
```

Replace the full contents of `Sources/StrategyDeck/Views/Cards/KnowledgeCardEditorView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// Full-form editor for creating or updating a KnowledgeCard. Only the
/// `.softwareStrategy` metadata case has a real form in this slice — a
/// future deck's metadata case gets its own editor section here without
/// touching the identity/tags fields above.
struct KnowledgeCardEditorView: View {
    enum Mode { case create, edit }

    let mode: Mode
    @Binding var card: KnowledgeCard
    let suits: [CardSuit]
    let onSave: (KnowledgeCard) -> Void
    let onCancel: () -> Void

    @State private var tagsText: String = ""
    @State private var requirementsText: String = ""
    @State private var advantagesText: String = ""
    @State private var costsText: String = ""
    @State private var failureModesText: String = ""

    private var softwareFields: Binding<SoftwareStrategyFields> {
        Binding(
            get: {
                if case .softwareStrategy(let f) = card.metadata { return f }
                return SoftwareStrategyFields()
            },
            set: { card.metadata = .softwareStrategy($0) }
        )
    }

    private var selectedSuitID: Binding<String> {
        Binding(
            get: { card.suitIDs.first ?? suits.first?.id ?? "" },
            set: { newID in
                card.suitIDs = [newID]
                if let deckID = suits.first(where: { $0.id == newID })?.deckID {
                    card.deckIDs = [deckID]
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Text(mode == .create ? "New Card" : "Edit Card")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Save") { commitAndSave() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(card.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Identity") {
                        LabeledField("Name") {
                            TextField("e.g. Hash-Based Lookup", text: $card.title)
                        }
                        LabeledField("Suite") {
                            Picker("Suite", selection: selectedSuitID) {
                                ForEach(suits.sorted { $0.displayOrder < $1.displayOrder }) { s in
                                    Text(s.name).tag(s.id)
                                }
                            }
                            .labelsHidden()
                        }
                        LabeledField("Tags (comma-separated)") {
                            TextField("e.g. hash, lookup, membership", text: $tagsText)
                        }
                    }

                    section("Problem") {
                        LabeledField("Trigger") {
                            TextEditor(text: softwareFields.trigger)
                                .frame(minHeight: 44)
                        }
                        LabeledField("Problem Shape") {
                            TextEditor(text: softwareFields.problemShape)
                                .frame(minHeight: 44)
                        }
                        LabeledField("Desired Result") {
                            TextEditor(text: softwareFields.desiredResult)
                                .frame(minHeight: 44)
                        }
                    }

                    section("Mechanism") {
                        LabeledField("How It Works") {
                            TextEditor(text: softwareFields.mechanism)
                                .frame(minHeight: 60)
                        }
                        LabeledField("Requirements (one per line)") {
                            TextEditor(text: $requirementsText)
                                .frame(minHeight: 44)
                        }
                    }

                    section("Trade-offs") {
                        LabeledField("Advantages (one per line)") {
                            TextEditor(text: $advantagesText)
                                .frame(minHeight: 44)
                        }
                        LabeledField("Costs (one per line)") {
                            TextEditor(text: $costsText)
                                .frame(minHeight: 44)
                        }
                        LabeledField("Failure Modes (one per line)") {
                            TextEditor(text: $failureModesText)
                                .frame(minHeight: 44)
                        }
                    }

                    section("Complexity") {
                        HStack(spacing: 12) {
                            LabeledField("Time") {
                                TextField("O(n)", text: softwareFields.timeComplexity)
                            }
                            LabeledField("Space") {
                                TextField("O(1)", text: softwareFields.spaceComplexity)
                            }
                        }
                    }

                    section("Examples") {
                        LabeledField("Flow Description") {
                            TextEditor(text: softwareFields.flowDescription)
                                .frame(minHeight: 44)
                        }
                        LabeledField("Code Example") {
                            TextEditor(text: softwareFields.codeExample)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 60)
                        }
                        LabeledField("Real-World Example") {
                            TextEditor(text: softwareFields.realWorldExample)
                                .frame(minHeight: 44)
                        }
                    }

                    section("Notes") {
                        LabeledField("Personal Notes") {
                            TextEditor(text: $card.backText)
                                .frame(minHeight: 60)
                        }
                    }
                }
                .padding(14)
            }
        }
        .onAppear { populateListFields() }
    }

    // MARK: - Helpers

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            content()
        }
    }

    private func populateListFields() {
        tagsText = card.tags.joined(separator: ", ")
        requirementsText = softwareFields.wrappedValue.requirements.joined(separator: "\n")
        advantagesText = softwareFields.wrappedValue.advantages.joined(separator: "\n")
        costsText = softwareFields.wrappedValue.costs.joined(separator: "\n")
        failureModesText = softwareFields.wrappedValue.failureModes.joined(separator: "\n")
    }

    private func commitAndSave() {
        card.tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var fields = softwareFields.wrappedValue
        fields.requirements = lines(requirementsText)
        fields.advantages = lines(advantagesText)
        fields.costs = lines(costsText)
        fields.failureModes = lines(failureModesText)
        card.metadata = .softwareStrategy(fields)
        onSave(card)
    }

    private func lines(_ text: String) -> [String] {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            content
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }
}
```

- [ ] **Step 23: `DeckSuitTreeView` (replaces `SuiteSelectorView`)**

```bash
git rm Sources/StrategyDeck/Views/Suites/SuiteSelectorView.swift
```

Create `Sources/StrategyDeck/Views/Suites/DeckSuitTreeView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// Collapsible Deck → Suit → Sub-suit tree for library navigation.
/// Selecting a deck row shows all its cards; selecting a suit row scopes to
/// that suit and every sub-suit nested underneath it.
struct DeckSuitTreeView: View {
    let decks: [KnowledgeDeck]
    let suits: [CardSuit]
    @Binding var selectedDeckID: String?
    @Binding var selectedSuiteID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(decks.sorted { $0.displayOrder < $1.displayOrder }) { deck in
                    DeckRow(
                        deck: deck,
                        suits: suits,
                        selectedDeckID: $selectedDeckID,
                        selectedSuiteID: $selectedSuiteID
                    )
                }
            }
            .padding(6)
        }
        .background(.bar)
    }
}

private struct DeckRow: View {
    let deck: KnowledgeDeck
    let suits: [CardSuit]
    @Binding var selectedDeckID: String?
    @Binding var selectedSuiteID: String?

    @State private var isExpanded = true

    private var rootSuits: [CardSuit] { suits.rootSuits(deckID: deck.id) }
    private var isSelected: Bool { selectedDeckID == deck.id && selectedSuiteID == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                selectedDeckID = deck.id
                selectedSuiteID = nil
            } label: {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: deck.iconName)
                        .font(.system(size: 10, weight: .semibold))
                    Text(deck.name)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(rootSuits) { suit in
                    SuitRow(
                        suit: suit,
                        allSuits: suits,
                        selectedSuiteID: $selectedSuiteID,
                        onSelect: {
                            selectedDeckID = deck.id
                            selectedSuiteID = suit.id
                        },
                        depth: 1
                    )
                }
            }
        }
    }
}

private struct SuitRow: View {
    let suit: CardSuit
    let allSuits: [CardSuit]
    @Binding var selectedSuiteID: String?
    let onSelect: () -> Void
    let depth: Int

    @State private var isExpanded = true

    private var children: [CardSuit] { allSuits.children(of: suit.id) }
    private var isSelected: Bool { selectedSuiteID == suit.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button(action: onSelect) {
                HStack(spacing: 4) {
                    if !children.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .frame(width: 10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer().frame(width: 10)
                    }
                    Image(systemName: suit.iconName)
                        .font(.system(size: 9))
                    Text(suit.name)
                        .font(.system(size: 10.5))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.vertical, 2.5)
                .padding(.leading, CGFloat(depth) * 12)
                .padding(.trailing, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(children) { child in
                    SuitRow(
                        suit: child,
                        allSuits: allSuits,
                        selectedSuiteID: $selectedSuiteID,
                        onSelect: { selectedSuiteID = child.id },
                        depth: depth + 1
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 24: `HeaderView` — add the sidebar toggle**

Replace the full contents of `Sources/StrategyDeck/Views/Panel/HeaderView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

struct HeaderView: View {
    @Binding var searchText: String
    @Binding var favoritesOnly: Bool
    let isPinned: Bool
    @Binding var isSidebarVisible: Bool
    let onTogglePin: () -> Void
    let onAddCard: () -> Void
    let onShowSettings: () -> Void
    let onResetSeed: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Strategy Deck")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.primary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isSidebarVisible.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSidebarVisible ? Color.accentColor : Color.secondary)
                .help(isSidebarVisible ? "Hide library sidebar" : "Show library sidebar")

                Button(action: onAddCard) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("New card")

                Toggle(isOn: Binding(get: { isPinned }, set: { _ in onTogglePin() })) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                .help(isPinned ? "Unpin panel" : "Pin panel on top")

                Menu {
                    Toggle("Show Favorites Only", isOn: $favoritesOnly)
                    Divider()
                    Button("Settings…", action: onShowSettings)
                    Divider()
                    Button("Reset to Default Cards…", action: onResetSeed)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search cards…", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.textBackgroundColor).opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor), lineWidth: 0.5))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .background(.bar)
    }
}
```

- [ ] **Step 25: `PanelRootView` — host the sidebar and switch to the new stores**

Replace the full contents of `Sources/StrategyDeck/Views/Panel/PanelRootView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// The root content view hosted inside the floating NSPanel.
struct PanelRootView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var sequenceStore: SequenceStore

    // Reference back to the controller so the header can toggle pin.
    let panelController: FloatingPanelController

    @State private var searchText = ""
    @State private var selectedDeckID: String?
    @State private var selectedSuiteID: String?
    @State private var favoritesOnly = false
    @State private var isSidebarVisible = true
    @State private var showingSettings = false
    @State private var alertState: AlertState?
    @State private var cardGridRef = CardGridViewProxy()

    private var filter: CardFilter {
        CardFilter(query: searchText, deckID: selectedDeckID, suitID: selectedSuiteID, favoritesOnly: favoritesOnly)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                searchText: $searchText,
                favoritesOnly: $favoritesOnly,
                isPinned: panelController.isPinned,
                isSidebarVisible: $isSidebarVisible,
                onTogglePin: { panelController.setPin(!panelController.isPinned) },
                onAddCard: { cardGridRef.presentCreate?() },
                onShowSettings: { showingSettings = true },
                onResetSeed: {
                    alertState = .destructive(
                        title: "Reset to Default Cards?",
                        message: "Your custom cards will be permanently replaced with the built-in defaults. Saved sequences are not affected.",
                        confirmLabel: "Reset"
                    ) { cardStore.resetToSeed() }
                }
            )

            Divider()

            HStack(spacing: 0) {
                if isSidebarVisible {
                    DeckSuitTreeView(
                        decks: cardStore.decks,
                        suits: cardStore.suits,
                        selectedDeckID: $selectedDeckID,
                        selectedSuiteID: $selectedSuiteID
                    )
                    .frame(width: 150)
                    Divider()
                }

                VStack(spacing: 0) {
                    KnowledgeCardGridContainer(filter: filter, suits: cardStore.suits, proxy: cardGridRef)
                    SequenceTrayView()
                        .environmentObject(sequenceStore)
                        .environmentObject(cardStore)
                }
            }
        }
        .background(Color(.windowBackgroundColor))
        .alertState($alertState)
        .onAppear {
            if selectedDeckID == nil { selectedDeckID = cardStore.decks.first?.id }
        }
        .onChange(of: cardStore.lastError as? NSError) { _, _ in
            if let err = cardStore.lastError { alertState = .error(err) }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(environment)
                .frame(minWidth: 360, minHeight: 420)
        }
    }
}

/// A thin proxy class so HeaderView can trigger card grid actions
/// without creating a circular view dependency.
final class CardGridViewProxy: ObservableObject {
    var presentCreate: (() -> Void)?
}

/// Wrapper that captures the proxy reference and hands it to the grid.
struct KnowledgeCardGridContainer: View {
    let filter: CardFilter
    let suits: [CardSuit]
    let proxy: CardGridViewProxy

    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var sequenceStore: SequenceStore

    var body: some View {
        InternalGrid(filter: filter, suits: suits, proxy: proxy)
    }
}

private struct InternalGrid: View {
    let filter: CardFilter
    let suits: [CardSuit]
    let proxy: CardGridViewProxy

    @EnvironmentObject var cardStore: CardStore
    @EnvironmentObject var sequenceStore: SequenceStore

    @State private var selectedCardID: UUID?
    @State private var detailCard: KnowledgeCard?
    @State private var editingCard: KnowledgeCard?
    @State private var isCreating = false
    @State private var newCard = InternalGrid.blankCard(suits: [])
    @State private var alertState: AlertState?
    @State private var pendingDeleteID: UUID?

    private var filteredCards: [KnowledgeCard] {
        filter.apply(to: cardStore.cards, suits: suits)
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 6)]

    var body: some View {
        ScrollView {
            if filteredCards.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(filteredCards) { card in
                        KnowledgeCardView(
                            card: card,
                            suite: primarySuite(for: card),
                            isSelected: selectedCardID == card.id,
                            onTap: { selectedCardID = card.id; detailCard = card },
                            onAddToTray: { sequenceStore.addToTray(cardID: card.id) },
                            onFavorite: { cardStore.toggleFavorite(id: card.id) },
                            onEdit: { selectedCardID = card.id; editingCard = card },
                            onDuplicate: { cardStore.duplicate(card) },
                            onDelete: {
                                pendingDeleteID = card.id
                                alertState = .destructive(
                                    title: "Delete \"\(card.title)\"?",
                                    message: "This card will be permanently removed from your library.",
                                    confirmLabel: "Delete"
                                ) {
                                    if let id = pendingDeleteID { cardStore.delete(id: id) }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .alertState($alertState)
        // Wire the proxy so the header can trigger "new card"
        .onAppear {
            proxy.presentCreate = { presentCreate() }
        }
        // Card detail
        .sheet(item: Binding(get: { detailCard }, set: { detailCard = $0 })) { card in
            KnowledgeCardDetailView(
                card: card,
                suite: primarySuite(for: card),
                allCards: cardStore.cards,
                relationships: cardStore.relationships,
                onEdit: { editingCard = card },
                onAddToTray: { sequenceStore.addToTray(cardID: card.id) },
                onDismiss: { detailCard = nil }
            )
            .frame(minWidth: 340, minHeight: 500)
        }
        // Edit
        .sheet(item: Binding(get: { editingCard }, set: { editingCard = $0 })) { card in
            KnowledgeCardEditorView(
                mode: .edit,
                card: Binding(get: { editingCard ?? card }, set: { editingCard = $0 }),
                suits: suits,
                onSave: { updated in cardStore.update(updated); editingCard = nil },
                onCancel: { editingCard = nil }
            )
            .frame(minWidth: 380, minHeight: 500)
        }
        // Create
        .sheet(isPresented: $isCreating) {
            KnowledgeCardEditorView(
                mode: .create,
                card: $newCard,
                suits: suits,
                onSave: { created in
                    cardStore.add(created)
                    isCreating = false
                    newCard = Self.blankCard(suits: suits)
                },
                onCancel: {
                    isCreating = false
                    newCard = Self.blankCard(suits: suits)
                }
            )
            .frame(minWidth: 380, minHeight: 500)
        }
        // Keyboard navigation
        .focusable()
        .onKeyPress(.space) { inspectSelected(); return .handled }
        .onKeyPress(.return) { inspectSelected(); return .handled }
    }

    // MARK: - Helpers

    private func primarySuite(for card: KnowledgeCard) -> CardSuit? {
        suits.first { card.suitIDs.contains($0.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(filter.query.isEmpty ? "No cards in this suite." : "No cards match \"\(filter.query)\".")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func inspectSelected() {
        guard let id = selectedCardID,
              let card = cardStore.cards.first(where: { $0.id == id }) else { return }
        detailCard = card
    }

    /// Called by the header's add-card button.
    private func presentCreate() {
        newCard = Self.blankCard(suits: suits)
        isCreating = true
    }

    private static func blankCard(suits: [CardSuit]) -> KnowledgeCard {
        KnowledgeCard(
            deckIDs: suits.first.map { [$0.deckID] } ?? [],
            suitIDs: suits.first.map { [$0.id] } ?? [],
            kind: .action,
            metadata: .softwareStrategy(SoftwareStrategyFields()),
            title: ""
        )
    }
}
```

- [ ] **Step 26: `SequenceTrayView` (rewrite of `LoadoutTrayView`)**

```bash
mkdir -p Sources/StrategyDeck/Views/Sequences
git mv Sources/StrategyDeck/Views/Loadouts/LoadoutTrayView.swift Sources/StrategyDeck/Views/Sequences/SequenceTrayView.swift
```

Replace the full contents of `Sources/StrategyDeck/Views/Sequences/SequenceTrayView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// Collapsible bottom tray showing the current ordered sequence of selected cards.
struct SequenceTrayView: View {
    @EnvironmentObject var sequenceStore: SequenceStore
    @EnvironmentObject var cardStore: CardStore

    @State private var isExpanded = true
    @State private var showingSaveSheet = false
    @State private var showingManager = false
    @State private var saveSequenceName = ""
    @State private var saveSequenceDesc = ""
    @State private var alertState: AlertState?
    @State private var editingNoteForID: UUID?

    private var orderedItems: [StrategySequenceItem] {
        sequenceStore.trayItems.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Tray header
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Sequence")
                            .font(.system(size: 11, weight: .semibold))
                        if !sequenceStore.trayItems.isEmpty {
                            Text("\(sequenceStore.trayItems.count)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(.secondary.opacity(0.15)))
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if !sequenceStore.trayItems.isEmpty {
                    Button {
                        alertState = .destructive(
                            title: "Clear Sequence?",
                            message: "All items will be removed from the tray. Save first if you want to keep this sequence.",
                            confirmLabel: "Clear"
                        ) { sequenceStore.clearTray() }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear sequence")

                    Button {
                        saveSequenceName = ""
                        saveSequenceDesc = ""
                        showingSaveSheet = true
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Button {
                    showingManager = true
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open saved sequence")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // Tray content
            if isExpanded {
                if orderedItems.isEmpty {
                    emptyTray
                } else {
                    trayList
                }
            }
        }
        .alertState($alertState)
        // Save sheet
        .sheet(isPresented: $showingSaveSheet) {
            SaveSequenceSheet(
                name: $saveSequenceName,
                description: $saveSequenceDesc,
                onSave: {
                    guard !saveSequenceName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    sequenceStore.saveSequence(name: saveSequenceName, description: saveSequenceDesc)
                    showingSaveSheet = false
                },
                onCancel: { showingSaveSheet = false }
            )
        }
        // Sequence manager sheet
        .sheet(isPresented: $showingManager) {
            SequenceManagerView(onDismiss: { showingManager = false })
                .environmentObject(sequenceStore)
                .environmentObject(cardStore)
                .frame(minWidth: 340, minHeight: 320)
        }
        // Drop target: accept card IDs dragged from the grid
        .dropDestination(for: String.self) { items, _ in
            for item in items {
                if let id = UUID(uuidString: item) {
                    sequenceStore.addToTray(cardID: id)
                }
            }
            return !items.isEmpty
        }
    }

    // MARK: - Subviews

    private var emptyTray: some View {
        Text("Drag cards here or tap + on a card to build your sequence.")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(10)
    }

    private var trayList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(orderedItems.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        TrayItemRow(
                            item: item,
                            card: cardStore.cards.first { $0.id == item.cardID },
                            onRemove: { sequenceStore.removeFromTray(id: item.id) },
                            onEditNote: { editingNoteForID = item.id }
                        )

                        if index < orderedItems.count - 1 {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: 220)
    }
}

// MARK: - Tray Item Row

private struct TrayItemRow: View {
    let item: StrategySequenceItem
    let card: KnowledgeCard?
    let onRemove: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(card?.kind.symbol ?? "?")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(card?.title ?? "Unknown Card")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            Button(action: onEditNote) {
                Image(systemName: "note.text")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help("Edit note")

            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 5).fill(.secondary.opacity(0.05)))
    }
}

// MARK: - Save Sheet

private struct SaveSequenceSheet: View {
    @Binding var name: String
    @Binding var description: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Save Sequence")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                TextField("e.g. Reliable API Integration", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { if !name.isEmpty { onSave() } }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description (optional)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                TextField("Brief description", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(18)
        .frame(width: 300)
    }
}
```

- [ ] **Step 27: `SequenceManagerView` (rewrite of `LoadoutManagerView`)**

```bash
git mv Sources/StrategyDeck/Views/Loadouts/LoadoutManagerView.swift Sources/StrategyDeck/Views/Sequences/SequenceManagerView.swift
rmdir Sources/StrategyDeck/Views/Loadouts 2>/dev/null || true
```

Replace the full contents of `Sources/StrategyDeck/Views/Sequences/SequenceManagerView.swift`:

```swift
import SwiftUI
import StrategyDeckCore

/// Sheet for browsing, opening, and deleting saved sequences.
struct SequenceManagerView: View {
    @EnvironmentObject var sequenceStore: SequenceStore
    @EnvironmentObject var cardStore: CardStore
    var onDismiss: () -> Void

    @State private var alertState: AlertState?
    @State private var pendingDeleteID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved Sequences")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if sequenceStore.savedSequences.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No saved sequences yet.\nBuild a tray and save it.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sequenceStore.savedSequences.sorted { $0.updatedAt > $1.updatedAt }) { sequence in
                        SequenceRow(
                            sequence: sequence,
                            cards: cardStore.cards,
                            onOpen: {
                                sequenceStore.openSequence(sequence)
                                onDismiss()
                            },
                            onDelete: {
                                pendingDeleteID = sequence.id
                                alertState = .destructive(
                                    title: "Delete \"\(sequence.name)\"?",
                                    message: "This sequence will be permanently removed.",
                                    confirmLabel: "Delete"
                                ) {
                                    if let id = pendingDeleteID { sequenceStore.deleteSequence(id: id) }
                                }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .alertState($alertState)
        .frame(minWidth: 320, minHeight: 300)
    }
}

private struct SequenceRow: View {
    let sequence: StrategySequence
    let cards: [KnowledgeCard]
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sequence.name)
                    .font(.system(size: 12, weight: .semibold))
                let names = sequence.orderedItems.sorted { $0.order < $1.order }.compactMap { item in
                    cards.first { $0.id == item.cardID }?.title
                }
                Text(names.prefix(4).joined(separator: " → "))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Open") { onOpen() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

### Part D — Verify and commit

- [ ] **Step 28: Build and test the whole package**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected: both succeed, zero errors, all tests pass — this includes every model test from Tasks 2–9 plus every rewritten test from this task.

- [ ] **Step 29: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor: cut over to the generalized card engine (KnowledgeCard/CardStore)

Replaces the single-domain StrategyCard/StrategySuite/StrategyLoadout
model with the domain-independent Deck/Suit/KnowledgeCard/CardRelationship/
StrategySequence engine, migrates all Software Engineering seed content
into it as the "software-engineering" deck, and rebuilds the panel UI
(tree sidebar, card views, sequence tray/manager) on top of it. No
behavior regression: search, favorites, CRUD, sequence build/save/reopen,
and import/export all work identically to before.
EOF
)"
```

---

## Task 11: Final verification against acceptance criteria

**Files:** none (verification only)

- [ ] **Step 1: Full clean build and test run**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected: both succeed with zero errors and zero test failures.

- [ ] **Step 2: Walk the spec's acceptance criteria for this slice**

Confirm each of these against the current code (no code changes expected here — this is a checklist, and any gap found means going back to fix it in the relevant earlier task):

1. The app launches showing one deck ("Software Engineering") with its six suits, browsable via the tree sidebar — check `SeedCardProvider.makeLibrary()` and `DeckSuitTreeView`.
2. Search, favorites, create/edit/duplicate/delete, and reset-to-seed all work identically to before, against `CardStore`/`KnowledgeCard`.
3. Card detail view shows relationship data sourced from `CardRelationship`, not embedded ID arrays — check `KnowledgeCardDetailView.relatedRows`.
4. The sequence builder (add to hand, reorder, per-item note, save, reopen, delete) works identically to before, against `SequenceStore`/`StrategySequence`.
5. Whole-library import/export round-trips losslessly — covered by `MalformedJSONTests.testImportExportRoundTrip`.
6. All tests pass (confirmed in Step 1).
7. The project builds clean and runs as a floating panel with no behavior regression.

- [ ] **Step 3: Grep for any remaining references to deleted types**

```bash
grep -rli "strategycard\b\|strategysuite\b\|strategyloadout\b\|loadoutitem\b\|\bappdata\b\|strategystore\b\|loadoutstore\b\|strategyfilter\b" Sources/ Tests/ || echo "clean"
```
Expected: **not** literally `clean` — this will list `KnowledgeLibrary.swift`, `SoftwareStrategyFields.swift`, and `SeedCardProvider.swift`. That's expected: Task 10 itself prescribes doc comments in those three files that reference the old type names in prose (e.g. "replaces `AppData`", "everything that used to live directly on `StrategyCard`") to explain the migration to future readers. Read each match and confirm it is prose/a doc comment, not an actual type reference, function call, or import — if so, the old model layer is fully gone and this step passes. If any match is real code (not a comment), that's a leftover reference that needs fixing before this slice is done.

- [ ] **Step 4: Report status**

Summarize for the user: what works, what's explicitly deferred (per the spec's non-goals: Japanese content, verb-centered view, sentence composer, cross-deck sequence UI, deck/suit creation UI, prerequisite/conflict warnings, card-game mode), and confirm this slice's acceptance criteria are met.
