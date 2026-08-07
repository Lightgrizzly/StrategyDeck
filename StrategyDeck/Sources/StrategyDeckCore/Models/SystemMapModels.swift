import Foundation

// MARK: - Element kinds

/// The kinds of node a Systems Map diagram can contain. Flows and
/// relationships are edges (see ``SystemFlow`` / ``SystemRelationship``) and
/// are not part of this enum.
public enum SystemElementKind: String, Codable, Hashable, Sendable, CaseIterable {
    case stock
    case delay
    case constraint
    case goal
    case note

    public var displayName: String {
        switch self {
        case .stock: return "Stock"
        case .delay: return "Delay"
        case .constraint: return "Constraint"
        case .goal: return "Goal"
        case .note: return "Note"
        }
    }

    public var systemImage: String {
        switch self {
        case .stock: return "cylinder.split.1x2"
        case .delay: return "hourglass"
        case .constraint: return "exclamationmark.triangle"
        case .goal: return "flag.checkered"
        case .note: return "note.text"
        }
    }
}

/// The full set of target kinds a card can declare in
/// ``CardPlayabilityRules/systemTargetTypes``. A superset of
/// ``SystemElementKind`` that also covers the two edge types and
/// "the whole system" (no specific element).
public enum SystemTargetKind: String, Codable, Hashable, Sendable, CaseIterable {
    case stock, delay, constraint, goal, note, flow, relationship, system

    public var displayName: String {
        switch self {
        case .stock: return "Stock"
        case .delay: return "Delay"
        case .constraint: return "Constraint"
        case .goal: return "Goal"
        case .note: return "Note"
        case .flow: return "Flow"
        case .relationship: return "Relationship"
        case .system: return "Entire System"
        }
    }

    public var systemImage: String {
        switch self {
        case .stock: return "cylinder.split.1x2"
        case .delay: return "hourglass"
        case .constraint: return "exclamationmark.triangle"
        case .goal: return "flag.checkered"
        case .note: return "note.text"
        case .flow: return "arrow.right"
        case .relationship: return "link"
        case .system: return "point.3.connected.trianglepath.dotted"
        }
    }
}

// MARK: - Leverage levels (Donella Meadows-inspired)

public enum LeverageLevel: String, Codable, Hashable, Sendable, CaseIterable {
    case parameter
    case bufferOrCapacity
    case flowStructure
    case delay
    case feedback
    case information
    case rule
    case goal
    case paradigm

    public var displayName: String {
        switch self {
        case .parameter: return "Parameter"
        case .bufferOrCapacity: return "Buffer / Capacity"
        case .flowStructure: return "Flow Structure"
        case .delay: return "Delay"
        case .feedback: return "Feedback"
        case .information: return "Information"
        case .rule: return "Rule"
        case .goal: return "Goal"
        case .paradigm: return "Paradigm"
        }
    }

    /// Rough ordering from lowest to highest leverage, for sorting/filtering.
    public var rank: Int {
        switch self {
        case .parameter: return 0
        case .bufferOrCapacity: return 1
        case .flowStructure: return 2
        case .delay: return 3
        case .feedback: return 4
        case .information: return 5
        case .rule: return 6
        case .goal: return 7
        case .paradigm: return 8
        }
    }
}

// MARK: - Geometry (platform-agnostic — StrategyDeckCore has no UI import)

public struct SystemPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0
    }
}

public struct SystemSize: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double = 120, height: Double = 72) {
        self.width = width
        self.height = height
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 120
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? 72
    }
}

public struct SystemViewport: Codable, Hashable, Sendable {
    public var offsetX: Double
    public var offsetY: Double
    public var zoom: Double

    public init(offsetX: Double = 0, offsetY: Double = 0, zoom: Double = 1) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.zoom = zoom
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        offsetX = try c.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0
        offsetY = try c.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? 1
    }
}

// MARK: - Element (node: stock, delay, constraint, goal, note)

public struct SystemElement: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: SystemElementKind
    public var name: String
    public var description: String
    public var position: SystemPoint
    public var size: SystemSize
    public var category: String
    public var iconName: String?
    public var notes: String

    // Stock-only fields (ignored for other kinds, kept flat per the app's
    // existing convention of optional deck-specific fields living directly
    // on the shared struct rather than an associated-value enum).
    public var currentValue: Double?
    public var minimumValue: Double?
    public var maximumValue: Double?
    public var desiredValue: Double?
    public var unit: String

    // Delay-only fields
    public var delayDurationLabel: String
    public var delayIsPending: Bool
    public var delayCompletionCondition: String
    public var delayCreatedStepIndex: Int?
    public var delayExpectedCompletionStepIndex: Int?

    // Goal-only fields
    public var isPrimaryGoal: Bool
    public var successCriteria: String
    public var failureCondition: String

    public init(
        id: UUID = UUID(),
        kind: SystemElementKind,
        name: String,
        description: String = "",
        position: SystemPoint = SystemPoint(),
        size: SystemSize = SystemSize(),
        category: String = "",
        iconName: String? = nil,
        notes: String = "",
        currentValue: Double? = nil,
        minimumValue: Double? = nil,
        maximumValue: Double? = nil,
        desiredValue: Double? = nil,
        unit: String = "",
        delayDurationLabel: String = "",
        delayIsPending: Bool = false,
        delayCompletionCondition: String = "",
        delayCreatedStepIndex: Int? = nil,
        delayExpectedCompletionStepIndex: Int? = nil,
        isPrimaryGoal: Bool = false,
        successCriteria: String = "",
        failureCondition: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.description = description
        self.position = position
        self.size = size
        self.category = category
        self.iconName = iconName
        self.notes = notes
        self.currentValue = currentValue
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.desiredValue = desiredValue
        self.unit = unit
        self.delayDurationLabel = delayDurationLabel
        self.delayIsPending = delayIsPending
        self.delayCompletionCondition = delayCompletionCondition
        self.delayCreatedStepIndex = delayCreatedStepIndex
        self.delayExpectedCompletionStepIndex = delayExpectedCompletionStepIndex
        self.isPrimaryGoal = isPrimaryGoal
        self.successCriteria = successCriteria
        self.failureCondition = failureCondition
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(SystemElementKind.self, forKey: .kind) ?? .note
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        position = try c.decodeIfPresent(SystemPoint.self, forKey: .position) ?? SystemPoint()
        size = try c.decodeIfPresent(SystemSize.self, forKey: .size) ?? SystemSize()
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        currentValue = try c.decodeIfPresent(Double.self, forKey: .currentValue)
        minimumValue = try c.decodeIfPresent(Double.self, forKey: .minimumValue)
        maximumValue = try c.decodeIfPresent(Double.self, forKey: .maximumValue)
        desiredValue = try c.decodeIfPresent(Double.self, forKey: .desiredValue)
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        delayDurationLabel = try c.decodeIfPresent(String.self, forKey: .delayDurationLabel) ?? ""
        delayIsPending = try c.decodeIfPresent(Bool.self, forKey: .delayIsPending) ?? false
        delayCompletionCondition = try c.decodeIfPresent(String.self, forKey: .delayCompletionCondition) ?? ""
        delayCreatedStepIndex = try c.decodeIfPresent(Int.self, forKey: .delayCreatedStepIndex)
        delayExpectedCompletionStepIndex = try c.decodeIfPresent(Int.self, forKey: .delayExpectedCompletionStepIndex)
        isPrimaryGoal = try c.decodeIfPresent(Bool.self, forKey: .isPrimaryGoal) ?? false
        successCriteria = try c.decodeIfPresent(String.self, forKey: .successCriteria) ?? ""
        failureCondition = try c.decodeIfPresent(String.self, forKey: .failureCondition) ?? ""
    }

    /// Whether the current value has drifted from the desired value — used
    /// by the evaluator to explain "Available because inventory is below
    /// its desired value" style reasons.
    public var isBelowDesired: Bool {
        guard let currentValue, let desiredValue else { return false }
        return currentValue < desiredValue
    }

    public var isAboveDesired: Bool {
        guard let currentValue, let desiredValue else { return false }
        return currentValue > desiredValue
    }
}

// MARK: - Flow (edge: stock -> stock)

public enum FlowDirection: String, Codable, Hashable, Sendable, CaseIterable {
    case inflow      // enters a stock from outside the visible system
    case outflow     // leaves a stock
    case transfer    // moves value between two stocks

    public var displayName: String {
        switch self {
        case .inflow: return "Inflow"
        case .outflow: return "Outflow"
        case .transfer: return "Transfer"
        }
    }
}

public struct SystemFlow: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var sourceElementID: UUID?
    public var targetElementID: UUID?
    public var direction: FlowDirection
    public var rate: Double?
    public var capacity: Double?
    public var delayLabel: String
    public var isEnabled: Bool
    public var conditions: [String]
    public var formulaNotes: String
    public var category: String

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        sourceElementID: UUID? = nil,
        targetElementID: UUID? = nil,
        direction: FlowDirection = .transfer,
        rate: Double? = nil,
        capacity: Double? = nil,
        delayLabel: String = "",
        isEnabled: Bool = true,
        conditions: [String] = [],
        formulaNotes: String = "",
        category: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sourceElementID = sourceElementID
        self.targetElementID = targetElementID
        self.direction = direction
        self.rate = rate
        self.capacity = capacity
        self.delayLabel = delayLabel
        self.isEnabled = isEnabled
        self.conditions = conditions
        self.formulaNotes = formulaNotes
        self.category = category
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Flow"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        sourceElementID = try c.decodeIfPresent(UUID.self, forKey: .sourceElementID)
        targetElementID = try c.decodeIfPresent(UUID.self, forKey: .targetElementID)
        direction = try c.decodeIfPresent(FlowDirection.self, forKey: .direction) ?? .transfer
        rate = try c.decodeIfPresent(Double.self, forKey: .rate)
        capacity = try c.decodeIfPresent(Double.self, forKey: .capacity)
        delayLabel = try c.decodeIfPresent(String.self, forKey: .delayLabel) ?? ""
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        conditions = try c.decodeIfPresent([String].self, forKey: .conditions) ?? []
        formulaNotes = try c.decodeIfPresent(String.self, forKey: .formulaNotes) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
    }
}

// MARK: - Relationship (edge: element -> element, semantic feedback link)

public enum RelationshipType: String, Codable, Hashable, Sendable, CaseIterable {
    case reinforces
    case balances
    case increases
    case decreases
    case enables
    case disables
    case constrains
    case suppliesInformationTo
    case triggers
    case delays
    case dependsOn

    public var displayName: String {
        switch self {
        case .reinforces: return "Reinforces"
        case .balances: return "Balances"
        case .increases: return "Increases"
        case .decreases: return "Decreases"
        case .enables: return "Enables"
        case .disables: return "Disables"
        case .constrains: return "Constrains"
        case .suppliesInformationTo: return "Supplies Information To"
        case .triggers: return "Triggers"
        case .delays: return "Delays"
        case .dependsOn: return "Depends On"
        }
    }

    /// Short marker shown on the diagram connector.
    public var marker: String {
        switch self {
        case .reinforces: return "R"
        case .balances: return "B"
        case .increases: return "+"
        case .decreases: return "–"
        case .enables: return "→"
        case .disables: return "⊘"
        case .constrains: return "◇"
        case .suppliesInformationTo: return "ℹ"
        case .triggers: return "⚡"
        case .delays: return "⏱"
        case .dependsOn: return "⋯"
        }
    }
}

public enum RelationshipPolarity: String, Codable, Hashable, Sendable, CaseIterable {
    case positive, negative, neutral
}

public struct SystemRelationship: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var sourceElementID: UUID
    public var targetElementID: UUID
    public var relationshipType: RelationshipType
    public var polarity: RelationshipPolarity
    public var delayLabel: String
    public var label: String

    public init(
        id: UUID = UUID(),
        sourceElementID: UUID,
        targetElementID: UUID,
        relationshipType: RelationshipType,
        polarity: RelationshipPolarity = .neutral,
        delayLabel: String = "",
        label: String = ""
    ) {
        self.id = id
        self.sourceElementID = sourceElementID
        self.targetElementID = targetElementID
        self.relationshipType = relationshipType
        self.polarity = polarity
        self.delayLabel = delayLabel
        self.label = label
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceElementID = try c.decode(UUID.self, forKey: .sourceElementID)
        targetElementID = try c.decode(UUID.self, forKey: .targetElementID)
        relationshipType = try c.decodeIfPresent(RelationshipType.self, forKey: .relationshipType) ?? .increases
        polarity = try c.decodeIfPresent(RelationshipPolarity.self, forKey: .polarity) ?? .neutral
        delayLabel = try c.decodeIfPresent(String.self, forKey: .delayLabel) ?? ""
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
    }
}

// MARK: - Legacy step model (pre-scenario). Kept only so old save files can
// be decoded and archived during migration — see `SystemMap.init(from:)`
// and `SystemScenario.migrated(from:name:isDefault:)`. Not used by any live
// code path; do not build new features on this.

// MARK: - Card play (a card applied to a target within the system)

public enum SystemCardPlayStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case active
    case pending
    case exhausted
    case resolved
}

public struct SystemCardPlay: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    public var targetElementID: UUID?
    public var targetKind: SystemTargetKind
    public var status: SystemCardPlayStatus
    public var playedAtStepIndex: Int
    public var notes: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        targetElementID: UUID? = nil,
        targetKind: SystemTargetKind,
        status: SystemCardPlayStatus = .active,
        playedAtStepIndex: Int,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.cardID = cardID
        self.targetElementID = targetElementID
        self.targetKind = targetKind
        self.status = status
        self.playedAtStepIndex = playedAtStepIndex
        self.notes = notes
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        targetElementID = try c.decodeIfPresent(UUID.self, forKey: .targetElementID)
        targetKind = try c.decodeIfPresent(SystemTargetKind.self, forKey: .targetKind) ?? .system
        status = try c.decodeIfPresent(SystemCardPlayStatus.self, forKey: .status) ?? .active
        playedAtStepIndex = try c.decodeIfPresent(Int.self, forKey: .playedAtStepIndex) ?? 0
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - Change entry (for "Changes This Step")

public enum SystemChangeKind: String, Codable, Hashable, Sendable {
    case stockChanged, flowEnabled, flowDisabled, flowRateChanged
    case constraintAdded, constraintRemoved
    case delayStarted, delayCompleted
    case relationshipAdded, relationshipRemoved
    case informationBecameKnown, goalChanged
    case cardPlayed, cardBecameActive, cardBecameAvailable
    case cardBecameLocked, cardBecameDisabled, cardBecameExhausted, cardResolved

    public var systemImage: String {
        switch self {
        case .stockChanged: return "arrow.up.arrow.down"
        case .flowEnabled: return "play.circle"
        case .flowDisabled: return "pause.circle"
        case .flowRateChanged: return "gauge.with.dots.needle.33percent"
        case .constraintAdded: return "exclamationmark.triangle.fill"
        case .constraintRemoved: return "checkmark.shield"
        case .delayStarted: return "hourglass"
        case .delayCompleted: return "hourglass.bottomhalf.filled"
        case .relationshipAdded: return "link"
        case .relationshipRemoved: return "link.badge.plus"
        case .informationBecameKnown: return "lightbulb.fill"
        case .goalChanged: return "flag.checkered"
        case .cardPlayed: return "play.fill"
        case .cardBecameActive: return "bolt.fill"
        case .cardBecameAvailable: return "checkmark.circle"
        case .cardBecameLocked: return "lock.fill"
        case .cardBecameDisabled: return "minus.circle"
        case .cardBecameExhausted: return "bolt.slash"
        case .cardResolved: return "checkmark.seal.fill"
        }
    }
}

public struct SystemChangeEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: SystemChangeKind
    public var label: String
    public var relatedElementID: UUID?
    public var relatedCardID: UUID?

    public init(
        id: UUID = UUID(),
        kind: SystemChangeKind,
        label: String,
        relatedElementID: UUID? = nil,
        relatedCardID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.relatedElementID = relatedElementID
        self.relatedCardID = relatedCardID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(SystemChangeKind.self, forKey: .kind) ?? .cardPlayed
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        relatedElementID = try c.decodeIfPresent(UUID.self, forKey: .relatedElementID)
        relatedCardID = try c.decodeIfPresent(UUID.self, forKey: .relatedCardID)
    }
}

// MARK: - Step (a snapshot of the evolving system)

public struct SystemStep: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var index: Int
    public var title: String
    public var notes: String
    public var elements: [SystemElement]
    public var flows: [SystemFlow]
    public var relationships: [SystemRelationship]
    public var knownInformation: String
    public var unknownInformation: String
    public var cardPlays: [SystemCardPlay]
    /// User-forced status per card ID, overriding the deterministic
    /// evaluation for this step. The automatic explanation is preserved
    /// separately by the evaluator, not discarded.
    public var manualStatusOverrides: [UUID: SystemCardStatus]
    public var selectedElementID: UUID?
    public var changes: [SystemChangeEntry]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        index: Int,
        title: String = "",
        notes: String = "",
        elements: [SystemElement] = [],
        flows: [SystemFlow] = [],
        relationships: [SystemRelationship] = [],
        knownInformation: String = "",
        unknownInformation: String = "",
        cardPlays: [SystemCardPlay] = [],
        manualStatusOverrides: [UUID: SystemCardStatus] = [:],
        selectedElementID: UUID? = nil,
        changes: [SystemChangeEntry] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.notes = notes
        self.elements = elements
        self.flows = flows
        self.relationships = relationships
        self.knownInformation = knownInformation
        self.unknownInformation = unknownInformation
        self.cardPlays = cardPlays
        self.manualStatusOverrides = manualStatusOverrides
        self.selectedElementID = selectedElementID
        self.changes = changes
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        elements = try c.decodeIfPresent([SystemElement].self, forKey: .elements) ?? []
        flows = try c.decodeIfPresent([SystemFlow].self, forKey: .flows) ?? []
        relationships = try c.decodeIfPresent([SystemRelationship].self, forKey: .relationships) ?? []
        knownInformation = try c.decodeIfPresent(String.self, forKey: .knownInformation) ?? ""
        unknownInformation = try c.decodeIfPresent(String.self, forKey: .unknownInformation) ?? ""
        cardPlays = try c.decodeIfPresent([SystemCardPlay].self, forKey: .cardPlays) ?? []
        manualStatusOverrides = try c.decodeIfPresent([UUID: SystemCardStatus].self, forKey: .manualStatusOverrides) ?? [:]
        selectedElementID = try c.decodeIfPresent(UUID.self, forKey: .selectedElementID)
        changes = try c.decodeIfPresent([SystemChangeEntry].self, forKey: .changes) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// Duplicates this step forward as the starting point for the next one —
    /// structure, values, and the card-play ledger all carry forward, only
    /// the per-step scratch (changes, notes) resets. Mirrors
    /// `DuelPanel.duplicated(order:)`.
    public func duplicated(index: Int) -> SystemStep {
        SystemStep(
            id: UUID(),
            index: index,
            title: "",
            notes: "",
            elements: elements,
            flows: flows,
            relationships: relationships,
            knownInformation: knownInformation,
            unknownInformation: unknownInformation,
            cardPlays: cardPlays,
            manualStatusOverrides: manualStatusOverrides,
            selectedElementID: selectedElementID,
            changes: [],
            createdAt: Date()
        )
    }
}

// MARK: - System Map
//
// A map is a shared base workflow (elements/flows/relationships — the
// structural diagram) plus a set of scenarios. A scenario represents a
// different configuration or condition of that same workflow (e.g. "Normal
// Operations" vs "Supplier Failure"), not a moment in a timeline. Card
// statuses are evaluated against the selected scenario + selected element,
// never against a chronological step (see `SystemMapEvaluator`).

public struct SystemMap: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var description: String
    public var primaryGoal: String
    public var failureCondition: String
    public var createdAt: Date
    public var updatedAt: Date

    /// Shared structural workflow — applies to every scenario. Editing this
    /// is "editing shared workflow structure," distinct from editing a
    /// scenario's overrides.
    public var elements: [SystemElement]
    public var flows: [SystemFlow]
    public var relationships: [SystemRelationship]
    public var viewport: SystemViewport

    public var scenarios: [SystemScenario]
    public var selectedScenarioID: UUID?

    /// The deck that supplies this map's card library by default. `nil`
    /// means "All Cards." A scenario may override this via
    /// `SystemScenario.deckOverrideID` — see `effectiveDeckID(for:)`.
    public var defaultDeckID: String?

    /// Card-status overrides that apply across every scenario for this map
    /// (`SystemOverrideScope.workflowDefault`). Scenario-scoped overrides
    /// live on `SystemScenario.cardStatusOverrides` instead.
    public var workflowDefaultOverrides: [SystemCardStatusOverride]

    /// Preserved verbatim from any pre-scenario save file so old step
    /// history is never silently discarded, even though it's no longer part
    /// of the live model. Populated only by the migration path in
    /// `init(from:)`; never written to by current code.
    public var legacyStepsArchive: [SystemStep]?

    /// Wholly new, user-defined statuses for this map's card vocabulary.
    public var customStatuses: [CustomCardStatus]
    /// Renamed display labels for the built-in statuses, keyed by
    /// `SystemCardStatus.rawValue`. A missing key means "use the default
    /// label."
    public var statusLabelOverrides: [String: String]

    /// Convenience bundle of both status-customization fields, for UI code
    /// that needs to resolve a status's display name/icon/color.
    public var statusCatalog: StatusCatalog {
        StatusCatalog(customStatuses: customStatuses, labelOverrides: statusLabelOverrides)
    }

    /// User-pinned Contextual Hand cards. Pinning never changes a card's
    /// status — only its ranking within the Contextual Hand.
    public var cardPins: [ContextualCardPin]

    /// Bugs, blockers, issues, risks, constraints, assumptions, incidents,
    /// unknowns, and warnings attached to this map's elements.
    public var issues: [SystemIssue]

    /// The folder this map lives in. `nil` means the root — every existing
    /// map before this feature migrates here automatically.
    public var folderID: UUID?
    /// Manual ordering among sibling maps within the same folder.
    public var sortOrder: Int
    /// Stamped by `SystemMapStore.openSystemMap`, independent of
    /// `updatedAt` — backs "Recently Opened" without a separate model.
    public var lastOpenedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        primaryGoal: String = "",
        failureCondition: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        elements: [SystemElement] = [],
        flows: [SystemFlow] = [],
        relationships: [SystemRelationship] = [],
        viewport: SystemViewport = SystemViewport(),
        scenarios: [SystemScenario] = [],
        selectedScenarioID: UUID? = nil,
        defaultDeckID: String? = nil,
        workflowDefaultOverrides: [SystemCardStatusOverride] = [],
        legacyStepsArchive: [SystemStep]? = nil,
        customStatuses: [CustomCardStatus] = [],
        statusLabelOverrides: [String: String] = [:],
        cardPins: [ContextualCardPin] = [],
        issues: [SystemIssue] = [],
        folderID: UUID? = nil,
        sortOrder: Int = 0,
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.primaryGoal = primaryGoal
        self.failureCondition = failureCondition
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.elements = elements
        self.flows = flows
        self.relationships = relationships
        self.viewport = viewport
        self.scenarios = scenarios
        self.selectedScenarioID = selectedScenarioID
        self.defaultDeckID = defaultDeckID
        self.workflowDefaultOverrides = workflowDefaultOverrides
        self.legacyStepsArchive = legacyStepsArchive
        self.customStatuses = customStatuses
        self.statusLabelOverrides = statusLabelOverrides
        self.cardPins = cardPins
        self.issues = issues
        self.folderID = folderID
        self.sortOrder = sortOrder
        self.lastOpenedAt = lastOpenedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, primaryGoal, failureCondition, createdAt, updatedAt
        case elements, flows, relationships, viewport
        case scenarios, selectedScenarioID, defaultDeckID, workflowDefaultOverrides
        case legacyStepsArchive
        case legacySteps = "steps"
        case cardPins
        case issues
        case folderID, sortOrder, lastOpenedAt
        case customStatuses, statusLabelOverrides
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled System Map"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        primaryGoal = try c.decodeIfPresent(String.self, forKey: .primaryGoal) ?? ""
        failureCondition = try c.decodeIfPresent(String.self, forKey: .failureCondition) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        viewport = try c.decodeIfPresent(SystemViewport.self, forKey: .viewport) ?? SystemViewport()
        customStatuses = try c.decodeIfPresent([CustomCardStatus].self, forKey: .customStatuses) ?? []
        statusLabelOverrides = try c.decodeIfPresent([String: String].self, forKey: .statusLabelOverrides) ?? [:]
        cardPins = try c.decodeIfPresent([ContextualCardPin].self, forKey: .cardPins) ?? []
        issues = try c.decodeIfPresent([SystemIssue].self, forKey: .issues) ?? []
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        lastOpenedAt = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt)

        let decodedElements = try c.decodeIfPresent([SystemElement].self, forKey: .elements)
        let decodedFlows = try c.decodeIfPresent([SystemFlow].self, forKey: .flows)
        let decodedRelationships = try c.decodeIfPresent([SystemRelationship].self, forKey: .relationships)
        let decodedScenarios = try c.decodeIfPresent([SystemScenario].self, forKey: .scenarios) ?? []
        let legacySteps = try c.decodeIfPresent([SystemStep].self, forKey: .legacySteps)

        if decodedElements != nil || decodedFlows != nil || decodedRelationships != nil || !decodedScenarios.isEmpty {
            // Already in the scenario-based shape (current format, possibly
            // with zero scenarios if this is a brand-new in-progress map).
            elements = decodedElements ?? []
            flows = decodedFlows ?? []
            relationships = decodedRelationships ?? []
            scenarios = decodedScenarios
            selectedScenarioID = try c.decodeIfPresent(UUID.self, forKey: .selectedScenarioID)
            defaultDeckID = try c.decodeIfPresent(String.self, forKey: .defaultDeckID)
            workflowDefaultOverrides = try c.decodeIfPresent([SystemCardStatusOverride].self, forKey: .workflowDefaultOverrides) ?? []
            legacyStepsArchive = try c.decodeIfPresent([SystemStep].self, forKey: .legacyStepsArchive)
        } else if let legacySteps, !legacySteps.isEmpty {
            // Pre-scenario save file. Migrate: latest step's structure
            // becomes the shared base workflow; latest step becomes the
            // default "Current State" scenario, and — if the map had more
            // than one step — the first step becomes an "Initial State"
            // scenario. The full original step history is preserved in
            // `legacyStepsArchive` regardless, so nothing is discarded.
            let sorted = legacySteps.sorted { $0.index < $1.index }
            let latest = sorted[sorted.count - 1]
            let first = sorted[0]

            elements = latest.elements
            flows = latest.flows
            relationships = latest.relationships

            let currentState = SystemScenario.migrated(from: latest, name: "Current State", isDefault: true, order: sorted.count > 1 ? 1 : 0)
            if sorted.count > 1, first.id != latest.id {
                let initialState = SystemScenario.migrated(from: first, name: "Initial State", isDefault: false, order: 0)
                scenarios = [initialState, currentState]
            } else {
                scenarios = [currentState]
            }
            selectedScenarioID = currentState.id
            defaultDeckID = nil
            workflowDefaultOverrides = []
            legacyStepsArchive = sorted
        } else {
            // Brand-new map, nothing to migrate.
            elements = []
            flows = []
            relationships = []
            scenarios = []
            selectedScenarioID = nil
            defaultDeckID = nil
            workflowDefaultOverrides = []
            legacyStepsArchive = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(primaryGoal, forKey: .primaryGoal)
        try c.encode(failureCondition, forKey: .failureCondition)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(elements, forKey: .elements)
        try c.encode(flows, forKey: .flows)
        try c.encode(relationships, forKey: .relationships)
        try c.encode(viewport, forKey: .viewport)
        try c.encode(scenarios, forKey: .scenarios)
        try c.encodeIfPresent(selectedScenarioID, forKey: .selectedScenarioID)
        try c.encodeIfPresent(defaultDeckID, forKey: .defaultDeckID)
        try c.encode(workflowDefaultOverrides, forKey: .workflowDefaultOverrides)
        try c.encodeIfPresent(legacyStepsArchive, forKey: .legacyStepsArchive)
        try c.encode(customStatuses, forKey: .customStatuses)
        try c.encode(statusLabelOverrides, forKey: .statusLabelOverrides)
        try c.encode(cardPins, forKey: .cardPins)
        try c.encode(issues, forKey: .issues)
        try c.encodeIfPresent(folderID, forKey: .folderID)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encodeIfPresent(lastOpenedAt, forKey: .lastOpenedAt)
    }

    public var sortedScenarios: [SystemScenario] {
        scenarios.sorted { $0.order != $1.order ? $0.order < $1.order : $0.createdAt < $1.createdAt }
    }

    /// The scenario that card evaluation and the diagram should currently
    /// reflect: the explicitly selected one, falling back to the default,
    /// falling back to the first available.
    public var selectedScenario: SystemScenario? {
        if let selectedScenarioID, let match = scenarios.first(where: { $0.id == selectedScenarioID }) {
            return match
        }
        return scenarios.first(where: { $0.isDefault }) ?? sortedScenarios.first
    }

    /// Base elements merged with a scenario's value overrides. Structural
    /// fields (name/description/category/position) always come from the
    /// shared base; only scenario-overridable fields (currentValue) differ.
    public func effectiveElements(for scenario: SystemScenario) -> [SystemElement] {
        elements.map { element in
            guard let override = scenario.elementOverrides[element.id] else { return element }
            var merged = element
            if let currentValue = override.currentValue { merged.currentValue = currentValue }
            if let notes = override.notes { merged.notes = notes }
            return merged
        }
    }

    /// Resolves which deck should supply the card library for a scenario:
    /// the scenario's own override, falling back to the map's default,
    /// falling back to `nil` ("All Cards").
    public func effectiveDeckID(for scenario: SystemScenario) -> String? {
        scenario.deckOverrideID ?? defaultDeckID
    }

    public func effectiveFlows(for scenario: SystemScenario) -> [SystemFlow] {
        flows.map { flow in
            guard let override = scenario.flowOverrides[flow.id] else { return flow }
            var merged = flow
            if let rate = override.rate { merged.rate = rate }
            if let isEnabled = override.isEnabled { merged.isEnabled = isEnabled }
            return merged
        }
    }
}
