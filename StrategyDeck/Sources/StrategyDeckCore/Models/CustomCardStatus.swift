import Foundation

/// A small preset color palette, reusing the app's own arena colors. Kept
/// as a closed set (rather than a free-form color picker) so this stays
/// data, not UI — the actual `Color` values live in the StrategyDeck (UI)
/// target's `SystemsMapDesign.swift`, matching how `SystemCardStatus`'s own
/// `arenaColor` is defined there rather than here.
public enum StatusColorToken: String, Codable, Hashable, Sendable, CaseIterable {
    case cyan
    case available
    case gold
    case threat
    case orange
    case purple
    case resolved
    case textDim
}

/// A user-defined status. Doesn't invent new behavior — it wears a custom
/// name/icon/color over one of the app's existing, already-understood
/// status behaviors (`behavesLike`), so every place that already knows how
/// to treat "available" or "locked" (playability, drag-and-drop actions,
/// status-change menus) keeps working unchanged for a custom status too.
public struct CustomCardStatus: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var iconName: String
    public var colorToken: StatusColorToken
    public var behavesLike: SystemCardStatus
    public var displayOrder: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String = "tag.fill",
        colorToken: StatusColorToken = .cyan,
        behavesLike: SystemCardStatus = .available,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorToken = colorToken
        self.behavesLike = behavesLike
        self.displayOrder = displayOrder
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Custom Status"
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "tag.fill"
        colorToken = try c.decodeIfPresent(StatusColorToken.self, forKey: .colorToken) ?? .cyan
        behavesLike = try c.decodeIfPresent(SystemCardStatus.self, forKey: .behavesLike) ?? .available
        displayOrder = try c.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    }
}

/// The customization data for one system map's status vocabulary: renamed
/// built-in labels plus any wholly new custom statuses. Bundled together
/// so UI code that needs to resolve "what should this status look like"
/// can take one value instead of two separate map fields.
public struct StatusCatalog: Sendable {
    public var customStatuses: [CustomCardStatus]
    public var labelOverrides: [String: String]

    public init(customStatuses: [CustomCardStatus] = [], labelOverrides: [String: String] = [:]) {
        self.customStatuses = customStatuses
        self.labelOverrides = labelOverrides
    }

    public static let empty = StatusCatalog()
}
