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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trigger = try c.decodeIfPresent(String.self, forKey: .trigger) ?? ""
        problemShape = try c.decodeIfPresent(String.self, forKey: .problemShape) ?? ""
        desiredResult = try c.decodeIfPresent(String.self, forKey: .desiredResult) ?? ""
        mechanism = try c.decodeIfPresent(String.self, forKey: .mechanism) ?? ""
        requirements = try c.decodeIfPresent([String].self, forKey: .requirements) ?? []
        advantages = try c.decodeIfPresent([String].self, forKey: .advantages) ?? []
        costs = try c.decodeIfPresent([String].self, forKey: .costs) ?? []
        failureModes = try c.decodeIfPresent([String].self, forKey: .failureModes) ?? []
        timeComplexity = try c.decodeIfPresent(String.self, forKey: .timeComplexity) ?? ""
        spaceComplexity = try c.decodeIfPresent(String.self, forKey: .spaceComplexity) ?? ""
        flowDescription = try c.decodeIfPresent(String.self, forKey: .flowDescription) ?? ""
        codeExample = try c.decodeIfPresent(String.self, forKey: .codeExample) ?? ""
        realWorldExample = try c.decodeIfPresent(String.self, forKey: .realWorldExample) ?? ""
    }
}
