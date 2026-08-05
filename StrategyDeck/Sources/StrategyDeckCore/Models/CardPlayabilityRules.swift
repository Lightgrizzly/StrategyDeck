import Foundation

public struct CardPlayabilityRules: Codable, Hashable, Sendable {
    public var prerequisites: [String]
    public var requiredActiveCardTitles: [String]
    public var requiredKnownInfo: [String]
    public var requiredStateConditions: [String]
    public var unlockedByCardTitles: [String]
    public var blockedByCardTitles: [String]
    public var unlocksCardTitles: [String]
    public var disablesCardTitles: [String]
    public var canBeReused: Bool
    public var exhaustsAfterUse: Bool

    public init(
        prerequisites: [String] = [],
        requiredActiveCardTitles: [String] = [],
        requiredKnownInfo: [String] = [],
        requiredStateConditions: [String] = [],
        unlockedByCardTitles: [String] = [],
        blockedByCardTitles: [String] = [],
        unlocksCardTitles: [String] = [],
        disablesCardTitles: [String] = [],
        canBeReused: Bool = true,
        exhaustsAfterUse: Bool = false
    ) {
        self.prerequisites = prerequisites
        self.requiredActiveCardTitles = requiredActiveCardTitles
        self.requiredKnownInfo = requiredKnownInfo
        self.requiredStateConditions = requiredStateConditions
        self.unlockedByCardTitles = unlockedByCardTitles
        self.blockedByCardTitles = blockedByCardTitles
        self.unlocksCardTitles = unlocksCardTitles
        self.disablesCardTitles = disablesCardTitles
        self.canBeReused = canBeReused
        self.exhaustsAfterUse = exhaustsAfterUse
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prerequisites = try c.decodeIfPresent([String].self, forKey: .prerequisites) ?? []
        requiredActiveCardTitles = try c.decodeIfPresent([String].self, forKey: .requiredActiveCardTitles) ?? []
        requiredKnownInfo = try c.decodeIfPresent([String].self, forKey: .requiredKnownInfo) ?? []
        requiredStateConditions = try c.decodeIfPresent([String].self, forKey: .requiredStateConditions) ?? []
        unlockedByCardTitles = try c.decodeIfPresent([String].self, forKey: .unlockedByCardTitles) ?? []
        blockedByCardTitles = try c.decodeIfPresent([String].self, forKey: .blockedByCardTitles) ?? []
        unlocksCardTitles = try c.decodeIfPresent([String].self, forKey: .unlocksCardTitles) ?? []
        disablesCardTitles = try c.decodeIfPresent([String].self, forKey: .disablesCardTitles) ?? []
        canBeReused = try c.decodeIfPresent(Bool.self, forKey: .canBeReused) ?? true
        exhaustsAfterUse = try c.decodeIfPresent(Bool.self, forKey: .exhaustsAfterUse) ?? false
    }

    public var isEmpty: Bool {
        prerequisites.isEmpty &&
        requiredActiveCardTitles.isEmpty &&
        requiredKnownInfo.isEmpty &&
        requiredStateConditions.isEmpty &&
        unlockedByCardTitles.isEmpty &&
        blockedByCardTitles.isEmpty &&
        unlocksCardTitles.isEmpty &&
        disablesCardTitles.isEmpty
    }
}
