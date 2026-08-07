import Foundation

/// A folder for organizing Systems Maps hierarchically. `parentFolderID ==
/// nil` means the folder lives at the root. Hierarchy is expressed purely
/// through stable ID references — never a slash-delimited path string — so
/// renaming or moving a folder never requires rewriting anything else.
public struct SystemMapFolder: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var parentFolderID: UUID?
    public var sortOrder: Int
    public var isExpanded: Bool
    public var iconName: String?
    public var colorToken: StatusColorToken?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        parentFolderID: UUID? = nil,
        sortOrder: Int = 0,
        isExpanded: Bool = true,
        iconName: String? = nil,
        colorToken: StatusColorToken? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentFolderID = parentFolderID
        self.sortOrder = sortOrder
        self.isExpanded = isExpanded
        self.iconName = iconName
        self.colorToken = colorToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Folder"
        parentFolderID = try c.decodeIfPresent(UUID.self, forKey: .parentFolderID)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isExpanded = try c.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName)
        colorToken = try c.decodeIfPresent(StatusColorToken.self, forKey: .colorToken)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

/// How to handle a non-empty folder's contents when it's deleted.
public enum FolderDeleteStrategy: Sendable {
    case moveContentsToParent
    case deleteAllContents
}

/// A Systems Map marked as a quick-access favorite. Purely a pointer — the
/// map still lives in exactly one real folder.
public struct SystemMapFavorite: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID { systemMapID }
    public var systemMapID: UUID
    public var createdAt: Date

    public init(systemMapID: UUID, createdAt: Date = Date()) {
        self.systemMapID = systemMapID
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        systemMapID = try c.decode(UUID.self, forKey: .systemMapID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    private enum CodingKeys: String, CodingKey {
        case systemMapID, createdAt
    }
}
