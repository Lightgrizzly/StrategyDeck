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
