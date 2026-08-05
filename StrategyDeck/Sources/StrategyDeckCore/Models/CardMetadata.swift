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

    private enum CodingKeys: String, CodingKey {
        case softwareStrategy
        case generic
    }

    /// Lenient by design: a missing key, an empty payload, or a case this
    /// version of the app doesn't know about (e.g. written by a newer
    /// version) all decode to `.generic` rather than failing the whole
    /// card — and since `JSONPersistenceService` fails a load at the whole
    /// *file* level on any decode error, one card's metadata must never be
    /// able to take down the rest of the library.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let fields = try c.decodeIfPresent(SoftwareStrategyFields.self, forKey: .softwareStrategy) {
            self = .softwareStrategy(fields)
        } else {
            self = .generic
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .softwareStrategy(let fields):
            try c.encode(fields, forKey: .softwareStrategy)
        case .generic:
            try c.encode(true, forKey: .generic)
        }
    }
}
