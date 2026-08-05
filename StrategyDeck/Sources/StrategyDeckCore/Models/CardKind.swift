import Foundation

/// The domain-independent role a ``KnowledgeCard`` plays. Every deck's cards
/// map onto one of these nine kinds; deck-specific structure lives in
/// ``CardMetadata`` instead. Symbols are used in the UI so cards stay
/// identifiable in grayscale / without relying on color.
public enum CardKind: String, Codable, Hashable, Sendable, CaseIterable {
    /// Something that changes or processes reality.
    case action
    /// Something that must already be true.
    case condition
    /// Something that guides or constrains a decision.
    case principle
    /// Something used to inspect or diagnose reality.
    case observation
    /// A person, object, system, concept, or participant.
    case entity
    /// A connector between entities or actions (e.g. a particle, a preposition).
    case relation
    /// Something that alters another card (e.g. a verb conjugation, a flag).
    case modifier
    /// A reusable combination of other cards treated as one unit.
    case chunk
    /// An ordered or structured combination of cards.
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
