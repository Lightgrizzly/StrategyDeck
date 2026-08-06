import Foundation

// MARK: - Element state (lightweight per-scenario semantic tag)
//
// Distinct from card status: this describes the diagram element itself
// (e.g. "this flow is disabled in the Supplier Failure scenario"), not any
// card's evaluated status.

public enum SystemElementState: String, Codable, Hashable, Sendable, CaseIterable {
    case normal
    case active
    case disabled
    case hidden
    case atRisk
    case constrained

    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .active: return "Active"
        case .disabled: return "Disabled"
        case .hidden: return "Hidden"
        case .atRisk: return "At Risk"
        case .constrained: return "Constrained"
        }
    }
}

// MARK: - Override scope

/// How broadly a manual card-status override applies. Ordered narrowest to
/// broadest — evaluation checks in this order and the first match wins.
public enum SystemOverrideScope: String, Codable, Hashable, Sendable, CaseIterable {
    case thisElementOnly
    case allCompatibleElementsInScenario
    case entireScenario
    case workflowDefault

    public var displayName: String {
        switch self {
        case .thisElementOnly: return "This Element Only"
        case .allCompatibleElementsInScenario: return "All Compatible Elements"
        case .entireScenario: return "Entire Scenario"
        case .workflowDefault: return "Default For This Workflow"
        }
    }
}

// MARK: - Per-scenario value overrides for shared structural elements/flows

/// A scenario's override of one element's scenario-specific fields. All
/// fields are optional — nil means "use the shared base value."
public struct SystemElementOverride: Codable, Hashable, Sendable {
    public var currentValue: Double?
    public var state: SystemElementState?
    public var notes: String?

    public init(currentValue: Double? = nil, state: SystemElementState? = nil, notes: String? = nil) {
        self.currentValue = currentValue
        self.state = state
        self.notes = notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentValue = try c.decodeIfPresent(Double.self, forKey: .currentValue)
        state = try c.decodeIfPresent(SystemElementState.self, forKey: .state)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}

public struct SystemFlowOverride: Codable, Hashable, Sendable {
    public var rate: Double?
    public var isEnabled: Bool?
    public var state: SystemElementState?

    public init(rate: Double? = nil, isEnabled: Bool? = nil, state: SystemElementState? = nil) {
        self.rate = rate
        self.isEnabled = isEnabled
        self.state = state
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rate = try c.decodeIfPresent(Double.self, forKey: .rate)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled)
        state = try c.decodeIfPresent(SystemElementState.self, forKey: .state)
    }
}

// MARK: - Card status override
//
// Deliberately does NOT persist an `automaticStatus` snapshot — that's
// recomputed live by `SystemMapEvaluator` every time so it can never go
// stale. Only the override itself (what the user asserted, and why) is
// stored.

public struct SystemCardStatusOverride: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var cardID: UUID
    /// Only meaningful when `scope == .thisElementOnly`; nil for broader
    /// scopes since they aren't tied to one specific element.
    public var targetElementID: UUID?
    public var scope: SystemOverrideScope
    public var overriddenStatus: SystemCardStatus
    /// When set, this override is labeled as this custom status for display
    /// purposes — `overriddenStatus` still holds the underlying behavior
    /// (playability, drag-and-drop actions) that custom status wears.
    public var customStatusID: String?
    public var reason: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        targetElementID: UUID? = nil,
        scope: SystemOverrideScope = .thisElementOnly,
        overriddenStatus: SystemCardStatus,
        customStatusID: String? = nil,
        reason: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.cardID = cardID
        self.targetElementID = targetElementID
        self.scope = scope
        self.overriddenStatus = overriddenStatus
        self.customStatusID = customStatusID
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        targetElementID = try c.decodeIfPresent(UUID.self, forKey: .targetElementID)
        scope = try c.decodeIfPresent(SystemOverrideScope.self, forKey: .scope) ?? .thisElementOnly
        overriddenStatus = try c.decodeIfPresent(SystemCardStatus.self, forKey: .overriddenStatus) ?? .available
        customStatusID = try c.decodeIfPresent(String.self, forKey: .customStatusID)
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - Scenario
//
// A scenario is a different configuration/condition of the same shared
// workflow — NOT a moment in a timeline. "Normal Operations" and "Supplier
// Failure" both describe the same diagram; only the overrides differ.

public struct SystemScenario: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var isDefault: Bool
    public var order: Int

    public var elementOverrides: [UUID: SystemElementOverride]
    public var flowOverrides: [UUID: SystemFlowOverride]
    public var relationshipStates: [UUID: SystemElementState]

    public var knownInformation: String
    public var unknownInformation: String

    public var cardStatusOverrides: [SystemCardStatusOverride]
    public var cardNotes: [UUID: String]

    /// Overrides the map's `defaultDeckID` for this scenario only. `nil`
    /// means "inherit the map's default deck." See `SystemMap.effectiveDeckID(for:)`.
    public var deckOverrideID: String?

    public var selectedElementID: UUID?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        isDefault: Bool = false,
        order: Int = 0,
        elementOverrides: [UUID: SystemElementOverride] = [:],
        flowOverrides: [UUID: SystemFlowOverride] = [:],
        relationshipStates: [UUID: SystemElementState] = [:],
        knownInformation: String = "",
        unknownInformation: String = "",
        cardStatusOverrides: [SystemCardStatusOverride] = [],
        cardNotes: [UUID: String] = [:],
        deckOverrideID: String? = nil,
        selectedElementID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isDefault = isDefault
        self.order = order
        self.elementOverrides = elementOverrides
        self.flowOverrides = flowOverrides
        self.relationshipStates = relationshipStates
        self.knownInformation = knownInformation
        self.unknownInformation = unknownInformation
        self.cardStatusOverrides = cardStatusOverrides
        self.cardNotes = cardNotes
        self.deckOverrideID = deckOverrideID
        self.selectedElementID = selectedElementID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Scenario"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        elementOverrides = try c.decodeIfPresent([UUID: SystemElementOverride].self, forKey: .elementOverrides) ?? [:]
        flowOverrides = try c.decodeIfPresent([UUID: SystemFlowOverride].self, forKey: .flowOverrides) ?? [:]
        relationshipStates = try c.decodeIfPresent([UUID: SystemElementState].self, forKey: .relationshipStates) ?? [:]
        knownInformation = try c.decodeIfPresent(String.self, forKey: .knownInformation) ?? ""
        unknownInformation = try c.decodeIfPresent(String.self, forKey: .unknownInformation) ?? ""
        cardStatusOverrides = try c.decodeIfPresent([SystemCardStatusOverride].self, forKey: .cardStatusOverrides) ?? []
        cardNotes = try c.decodeIfPresent([UUID: String].self, forKey: .cardNotes) ?? [:]
        deckOverrideID = try c.decodeIfPresent(String.self, forKey: .deckOverrideID)
        selectedElementID = try c.decodeIfPresent(UUID.self, forKey: .selectedElementID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Builds a scenario from legacy step data during migration — carries
    /// over known/unknown information and converts any recorded card plays
    /// into `.thisElementOnly`-scoped status overrides so that history isn't
    /// lost, just reframed as scenario state.
    public static func migrated(from step: SystemStep, name: String, isDefault: Bool, order: Int) -> SystemScenario {
        var scenario = SystemScenario(name: name, isDefault: isDefault, order: order)
        scenario.knownInformation = step.knownInformation
        scenario.unknownInformation = step.unknownInformation
        scenario.cardStatusOverrides = step.cardPlays.map { play in
            SystemCardStatusOverride(
                cardID: play.cardID,
                targetElementID: play.targetElementID,
                scope: .thisElementOnly,
                overriddenStatus: SystemCardStatus(rawValue: play.status.rawValue) ?? .active,
                reason: play.notes.isEmpty ? "Migrated from prior step history." : play.notes,
                createdAt: play.createdAt,
                updatedAt: play.createdAt
            )
        }
        return scenario
    }
}
