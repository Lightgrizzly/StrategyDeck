import Foundation

/// The status vocabulary for a card evaluated against a Systems Map step.
/// Distinct from ``DuelCardStatus``/``StrategicZone`` because the Systems Map
/// mental model (state → rule → status) is functionally different from the
/// Duel board's zone metaphor, even though both are computed by the same
/// underlying ``PlayabilityEvaluator``.
public enum SystemCardStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case active
    case available
    case recommended
    case locked
    case disabled
    case exhausted
    case resolved
    case pending
    case irrelevant

    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .available: return "Available"
        case .recommended: return "Recommended"
        case .locked: return "Locked"
        case .disabled: return "Disabled"
        case .exhausted: return "Exhausted"
        case .resolved: return "Resolved"
        case .pending: return "Pending"
        case .irrelevant: return "Irrelevant"
        }
    }

    public var systemImage: String {
        switch self {
        case .active: return "bolt.fill"
        case .available: return "checkmark.circle"
        case .recommended: return "star.circle.fill"
        case .locked: return "lock.fill"
        case .disabled: return "minus.circle"
        case .exhausted: return "bolt.slash"
        case .resolved: return "checkmark.seal.fill"
        case .pending: return "hourglass"
        case .irrelevant: return "circle.dashed"
        }
    }

    /// The default group a card sorts into in the library, per the spec's
    /// suggested grouping (Active, Available, Locked/Disabled, Pending,
    /// Exhausted/Resolved, Irrelevant).
    public var groupRank: Int {
        switch self {
        case .active: return 0
        case .recommended: return 1
        case .available: return 1
        case .locked: return 2
        case .disabled: return 2
        case .pending: return 3
        case .exhausted: return 4
        case .resolved: return 4
        case .irrelevant: return 5
        }
    }

    public var groupTitle: String {
        switch groupRank {
        case 0: return "Active"
        case 1: return "Available"
        case 2: return "Locked / Disabled"
        case 3: return "Pending"
        case 4: return "Exhausted / Resolved"
        default: return "Irrelevant"
        }
    }
}

/// The full evaluation of one card against one Systems Map step, mirroring
/// the `CardEvaluation` shape from the feature spec while reusing
/// ``PlayabilityResult`` internally for the actual rule logic.
public struct SystemCardEvaluation: Sendable {
    public let cardID: UUID
    public let status: SystemCardStatus
    public let isPlayable: Bool
    public let relevance: Bool
    public let validTargetKinds: [SystemTargetKind]
    public let satisfiedRequirements: [String]
    public let missingRequirements: [String]
    public let blockingConditions: [String]
    public let unlockSuggestions: [String]
    public let isManuallyOverridden: Bool
    public let explanation: String

    public init(
        cardID: UUID,
        status: SystemCardStatus,
        isPlayable: Bool,
        relevance: Bool,
        validTargetKinds: [SystemTargetKind],
        satisfiedRequirements: [String],
        missingRequirements: [String],
        blockingConditions: [String],
        unlockSuggestions: [String],
        isManuallyOverridden: Bool,
        explanation: String
    ) {
        self.cardID = cardID
        self.status = status
        self.isPlayable = isPlayable
        self.relevance = relevance
        self.validTargetKinds = validTargetKinds
        self.satisfiedRequirements = satisfiedRequirements
        self.missingRequirements = missingRequirements
        self.blockingConditions = blockingConditions
        self.unlockSuggestions = unlockSuggestions
        self.isManuallyOverridden = isManuallyOverridden
        self.explanation = explanation
    }
}
