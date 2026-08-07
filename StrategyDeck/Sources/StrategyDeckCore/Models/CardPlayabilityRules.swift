import Foundation

public struct CardPlayabilityRules: Codable, Hashable, Sendable {
    public var prerequisites: [String]
    public var requiredActiveCardTitles: [String]
    public var requiredKnownInfo: [String]
    /// State conditions that must currently be true (present in the
    /// evaluator's active-state-conditions set) for this card to be
    /// available — e.g. produced by a mitigated/resolved issue.
    public var requiredStateConditions: [String]
    /// Free-text conditions that, while currently active (e.g. produced by
    /// an open issue), block this card. The inverse of
    /// `requiredStateConditions`.
    public var blockedByConditions: [String]
    public var unlockedByCardTitles: [String]
    public var blockedByCardTitles: [String]
    public var unlocksCardTitles: [String]
    public var disablesCardTitles: [String]
    public var canBeReused: Bool
    public var exhaustsAfterUse: Bool
    /// Which Systems Map element kinds this card can be applied to. Empty
    /// means "untargeted" — the card applies anywhere and is never marked
    /// Irrelevant by selection, which keeps every pre-existing card fully
    /// usable in the Systems Map without requiring authoring for each one.
    public var systemTargetTypes: [SystemTargetKind]
    /// Optional Donella Meadows–style leverage classification, used only for
    /// Systems Map filtering/metadata. Nil means "not classified."
    public var leverageLevel: LeverageLevel?

    public init(
        prerequisites: [String] = [],
        requiredActiveCardTitles: [String] = [],
        requiredKnownInfo: [String] = [],
        requiredStateConditions: [String] = [],
        blockedByConditions: [String] = [],
        unlockedByCardTitles: [String] = [],
        blockedByCardTitles: [String] = [],
        unlocksCardTitles: [String] = [],
        disablesCardTitles: [String] = [],
        canBeReused: Bool = true,
        exhaustsAfterUse: Bool = false,
        systemTargetTypes: [SystemTargetKind] = [],
        leverageLevel: LeverageLevel? = nil
    ) {
        self.prerequisites = prerequisites
        self.requiredActiveCardTitles = requiredActiveCardTitles
        self.requiredKnownInfo = requiredKnownInfo
        self.requiredStateConditions = requiredStateConditions
        self.blockedByConditions = blockedByConditions
        self.unlockedByCardTitles = unlockedByCardTitles
        self.blockedByCardTitles = blockedByCardTitles
        self.unlocksCardTitles = unlocksCardTitles
        self.disablesCardTitles = disablesCardTitles
        self.canBeReused = canBeReused
        self.exhaustsAfterUse = exhaustsAfterUse
        self.systemTargetTypes = systemTargetTypes
        self.leverageLevel = leverageLevel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prerequisites = try c.decodeIfPresent([String].self, forKey: .prerequisites) ?? []
        requiredActiveCardTitles = try c.decodeIfPresent([String].self, forKey: .requiredActiveCardTitles) ?? []
        requiredKnownInfo = try c.decodeIfPresent([String].self, forKey: .requiredKnownInfo) ?? []
        requiredStateConditions = try c.decodeIfPresent([String].self, forKey: .requiredStateConditions) ?? []
        blockedByConditions = try c.decodeIfPresent([String].self, forKey: .blockedByConditions) ?? []
        unlockedByCardTitles = try c.decodeIfPresent([String].self, forKey: .unlockedByCardTitles) ?? []
        blockedByCardTitles = try c.decodeIfPresent([String].self, forKey: .blockedByCardTitles) ?? []
        unlocksCardTitles = try c.decodeIfPresent([String].self, forKey: .unlocksCardTitles) ?? []
        disablesCardTitles = try c.decodeIfPresent([String].self, forKey: .disablesCardTitles) ?? []
        canBeReused = try c.decodeIfPresent(Bool.self, forKey: .canBeReused) ?? true
        exhaustsAfterUse = try c.decodeIfPresent(Bool.self, forKey: .exhaustsAfterUse) ?? false
        systemTargetTypes = try c.decodeIfPresent([SystemTargetKind].self, forKey: .systemTargetTypes) ?? []
        leverageLevel = try c.decodeIfPresent(LeverageLevel.self, forKey: .leverageLevel)
    }

    public var isEmpty: Bool {
        prerequisites.isEmpty &&
        requiredActiveCardTitles.isEmpty &&
        requiredKnownInfo.isEmpty &&
        requiredStateConditions.isEmpty &&
        blockedByConditions.isEmpty &&
        unlockedByCardTitles.isEmpty &&
        blockedByCardTitles.isEmpty &&
        unlocksCardTitles.isEmpty &&
        disablesCardTitles.isEmpty
    }
}
