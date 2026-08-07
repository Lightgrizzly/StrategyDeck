import SwiftUI
import AppKit
import StrategyDeckCore

/// A single `String`-based `.draggable`/`.dropDestination` payload carries
/// both maps and folders. A bare UUID string is a map (matches the
/// convention already used elsewhere); a `"folder:"`-prefixed UUID string
/// is a folder — mirrors the `"issue:"` prefix convention used to
/// disambiguate card vs. issue drags in the Contextual Hand.
private enum SystemMapDragPayload {
    static func folderPayload(for id: UUID) -> String { "folder:" + id.uuidString }

    static func folderID(from payload: String) -> UUID? {
        guard payload.hasPrefix("folder:") else { return nil }
        return UUID(uuidString: String(payload.dropFirst("folder:".count)))
    }
}

/// The map-row actions needed by both the recursive folder tree (maps shown
/// inline beneath an expanded folder, Finder-style) and the folder contents
/// pane — bundled so `SystemMapFolderRow` doesn't need six separate closures
/// threaded through every recursion level.
private struct MapRowActions {
    let onOpen: (UUID) -> Void
    let onDuplicate: (UUID) -> Void
    let onToggleFavorite: (UUID) -> Void
    let onMove: (UUID, UUID?) -> Void
    let onExport: (SystemMap) -> Void
    let onDeleteRequest: (SystemMap) -> Void
}

/// Replaces the flat "Saved System Maps" list with a lightweight
/// project-explorer: a folder tree on the left, the selected folder's
/// contents on the right. Root is `selectedFolderID == nil`.
struct SystemMapExplorerView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore

    @Binding var selectedFolderID: UUID?
    let onCreateMap: (UUID?) -> Void
    let onOpenMap: (UUID) -> Void

    @State private var searchText = ""
    @State private var renamingFolder: SystemMapFolder?
    @State private var renameText = ""
    @State private var deletingFolder: SystemMapFolder?
    @State private var alertState: AlertState?
    @State private var isRootDropTargeted = false
    @State private var virtualScope: VirtualScope?
    @State private var reorderTargetMapID: UUID?
    @State private var showContentsPaneWhenCompact = false
    @State private var isCompact = false

    /// Below this width, the tree and contents panes no longer fit side by
    /// side — collapse to a single navigable pane instead of squeezing both.
    private static let compactWidthThreshold: CGFloat = 560

    /// A quick-access collection that isn't a real folder — selecting one
    /// clears `selectedFolderID` navigation and shows a flat, cross-folder
    /// list instead of a single folder's contents.
    private enum VirtualScope: Equatable {
        case favorites, recentlyOpened
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(AC.borderDim).frame(height: 1)

            if !searchText.isEmpty {
                SystemMapSearchResultsView(
                    query: searchText,
                    onOpenMap: onOpenMap
                )
            } else if isCompact {
                Group {
                    if showContentsPaneWhenCompact {
                        folderContents
                    } else {
                        folderTree
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    folderTree
                        .frame(minWidth: 200, idealWidth: 240, maxWidth: 400, maxHeight: .infinity)
                    folderContents
                        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { isCompact = geometry.size.width < Self.compactWidthThreshold }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        isCompact = newWidth < Self.compactWidthThreshold
                    }
            }
        )
        .alertState($alertState)
        .sheet(item: $renamingFolder) { folder in
            VStack(alignment: .leading, spacing: 16) {
                Text("RENAME FOLDER").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1)
                TextField("Name", text: $renameText).arenaFieldStyle()
                HStack {
                    Button("Cancel") { renamingFolder = nil }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save") {
                        systemMapStore.renameFolder(id: folder.id, name: renameText)
                        renamingFolder = nil
                    }
                    .buttonStyle(ArenaButtonStyle(isDisabled: renameText.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 320)
            .background(AC.bg)
            .colorScheme(.dark)
        }
        .sheet(item: $deletingFolder) { folder in
            FolderDeleteConfirmationSheet(
                folder: folder,
                directMapCount: systemMapStore.directMapCount(folderID: folder.id),
                totalMapCount: systemMapStore.totalMapCount(folderID: folder.id),
                subfolderCount: systemMapStore.descendantFolderIDs(of: folder.id).count,
                onMoveToParent: {
                    systemMapStore.deleteFolder(id: folder.id, strategy: .moveContentsToParent)
                    if selectedFolderID == folder.id { selectedFolderID = folder.parentFolderID }
                    deletingFolder = nil
                },
                onDeleteAll: {
                    systemMapStore.deleteFolder(id: folder.id, strategy: .deleteAllContents)
                    if selectedFolderID == folder.id || systemMapStore.descendantFolderIDs(of: folder.id).contains(selectedFolderID ?? UUID()) {
                        selectedFolderID = folder.parentFolderID
                    }
                    deletingFolder = nil
                },
                onCancel: { deletingFolder = nil }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ArenaSectionLabel(text: "Systems Maps", icon: "folder")
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(AC.textDim)
                TextField("Search maps and folders…", text: $searchText)
                    .font(.system(size: 11)).textFieldStyle(.plain).foregroundStyle(AC.text)
            }
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(AC.surface))
            .frame(maxWidth: 260)
            Spacer()
            Button(action: { onCreateMap(selectedFolderID) }) {
                Label("MAP", systemImage: "plus").font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
            Button(action: {
                let folder = systemMapStore.createFolder(name: "New Folder", parentFolderID: selectedFolderID)
                renamingFolder = folder
                renameText = folder.name
            }) {
                Label("FOLDER", systemImage: "folder.badge.plus").font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .buttonStyle(ArenaOutlineButtonStyle())
        }
        .padding(10)
        .background(AC.surface)
    }

    /// Selecting a real folder always exits any virtual collection (Favorites /
    /// Recently Opened), so the two kinds of selection can't be active at once.
    private var folderSelectionBinding: Binding<UUID?> {
        Binding(get: { selectedFolderID }, set: { selectedFolderID = $0; virtualScope = nil; if isCompact { showContentsPaneWhenCompact = true } })
    }

    private var mapRowActions: MapRowActions {
        MapRowActions(
            onOpen: onOpenMap,
            onDuplicate: { systemMapStore.duplicateSystemMap(id: $0) },
            onToggleFavorite: { systemMapStore.toggleFavorite($0) },
            onMove: { mapID, folderID in systemMapStore.moveMap(id: mapID, toFolder: folderID) },
            onExport: exportMap,
            onDeleteRequest: { map in
                alertState = .destructive(
                    title: "Delete “\(map.title)”?",
                    message: "This will remove the saved system map and all its scenarios permanently.",
                    confirmLabel: "Delete"
                ) { systemMapStore.deleteSystemMap(id: map.id) }
            }
        )
    }

    private var folderTree: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                rootRow
                virtualScopeRow(.favorites, icon: "star.fill", title: "Favorites", count: systemMapStore.favorites.count)
                virtualScopeRow(.recentlyOpened, icon: "clock", title: "Recently Opened", count: systemMapStore.systemMaps.filter { $0.lastOpenedAt != nil }.count)
                Rectangle().fill(AC.borderDim).frame(height: 1).padding(.vertical, 2)
                ForEach(systemMapStore.childFolders(of: nil)) { folder in
                    SystemMapFolderRow(
                        folder: folder,
                        depth: 1,
                        selectedFolderID: folderSelectionBinding,
                        onCreateMapHere: onCreateMap,
                        onRename: { renamingFolder = $0; renameText = $0.name },
                        onDelete: { deletingFolder = $0 },
                        mapActions: mapRowActions
                    )
                }
                ForEach(systemMapStore.maps(inFolder: nil).sorted { $0.sortOrder < $1.sortOrder }) { map in
                    SystemMapTreeMapRow(map: map, depth: 1, actions: mapRowActions)
                }
            }
            .padding(6)
        }
        .background(AC.surface.opacity(0.5))
    }

    private var rootRow: some View {
        Button(action: { selectedFolderID = nil; virtualScope = nil; if isCompact { showContentsPaneWhenCompact = true } }) {
            HStack(spacing: 5) {
                Image(systemName: "house").font(.system(size: 10))
                Text("Root").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(systemMapStore.directMapCount(folderID: nil))").font(.system(size: 9, design: .monospaced)).foregroundStyle(AC.textDim)
            }
            .padding(.vertical, 4).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 5).fill(isRootDropTargeted ? AC.goldSoft : (selectedFolderID == nil && virtualScope == nil ? AC.cyanSoft : Color.clear)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isRootDropTargeted ? AC.gold.opacity(0.6) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedFolderID == nil && virtualScope == nil ? AC.cyan : AC.textSub)
        .dropDestination(for: String.self, action: { items, _ in
            guard let payload = items.first else { return false }
            if let folderID = SystemMapDragPayload.folderID(from: payload) {
                systemMapStore.moveFolder(id: folderID, toParent: nil)
                return true
            }
            guard let mapID = UUID(uuidString: payload) else { return false }
            systemMapStore.moveMap(id: mapID, toFolder: nil)
            return true
        }, isTargeted: { isRootDropTargeted = $0 })
    }

    private func virtualScopeRow(_ scope: VirtualScope, icon: String, title: String, count: Int) -> some View {
        Button(action: { virtualScope = scope; if isCompact { showContentsPaneWhenCompact = true } }) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(count)").font(.system(size: 9, design: .monospaced)).foregroundStyle(AC.textDim)
            }
            .padding(.vertical, 4).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 5).fill(virtualScope == scope ? AC.cyanSoft : Color.clear))
        }
        .buttonStyle(.plain)
        .foregroundStyle(virtualScope == scope ? AC.cyan : AC.textSub)
    }

    @ViewBuilder
    private var folderContents: some View {
        if let scope = virtualScope {
            virtualScopeContents(scope)
        } else {
            folderScopeContents
        }
    }

    @ViewBuilder
    private func virtualScopeContents(_ scope: VirtualScope) -> some View {
        let maps: [SystemMap] = {
            switch scope {
            case .favorites:
                let favoriteIDs = Set(systemMapStore.favorites.map(\.systemMapID))
                return systemMapStore.systemMaps.filter { favoriteIDs.contains($0.id) }
            case .recentlyOpened:
                return systemMapStore.systemMaps
                    .filter { $0.lastOpenedAt != nil }
                    .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            }
        }()

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                if isCompact {
                    Button(action: { showContentsPaneWhenCompact = false }) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AC.textSub)
                }
                Image(systemName: scope == .favorites ? "star.fill" : "clock").font(.system(size: 10)).foregroundStyle(AC.cyan)
                Text(scope == .favorites ? "Favorites" : "Recently Opened").font(.system(size: 11, weight: .bold)).foregroundStyle(AC.cyan)
            }
            .padding(10)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            if maps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: scope == .favorites ? "star" : "clock").font(.system(size: 26)).foregroundStyle(AC.textGhost)
                    Text(scope == .favorites ? "No favorites yet." : "No system maps opened yet.")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(AC.textSub)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(maps) { map in
                            VStack(alignment: .leading, spacing: 4) {
                                Text((["Root"] + systemMapStore.breadcrumbs(for: map.folderID).map(\.name)).joined(separator: " / "))
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AC.textDim)
                                SystemMapSummaryRow(
                                    map: map,
                                    isFavorite: systemMapStore.isFavorite(map.id),
                                    onOpen: { onOpenMap(map.id) },
                                    onDuplicate: { systemMapStore.duplicateSystemMap(id: map.id) },
                                    onToggleFavorite: { systemMapStore.toggleFavorite(map.id) },
                                    onMoveTo: { destination in systemMapStore.moveMap(id: map.id, toFolder: destination) },
                                    onExport: { exportMap(map) },
                                    onDelete: {
                                        alertState = .destructive(
                                            title: "Delete “\(map.title)”?",
                                            message: "This will remove the saved system map and all its scenarios permanently.",
                                            confirmLabel: "Delete"
                                        ) { systemMapStore.deleteSystemMap(id: map.id) }
                                    }
                                )
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    @ViewBuilder
    private var folderScopeContents: some View {
        let folderID = selectedFolderID
        let maps = systemMapStore.maps(inFolder: folderID).sorted { $0.sortOrder < $1.sortOrder }
        let childFolders = systemMapStore.childFolders(of: folderID)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if isCompact {
                    Button(action: { showContentsPaneWhenCompact = false }) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AC.textSub)
                }
                SystemMapBreadcrumbView(folderID: folderID, onNavigate: { selectedFolderID = $0; virtualScope = nil })
            }
            .padding(10)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            if maps.isEmpty && childFolders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder").font(.system(size: 26)).foregroundStyle(AC.textGhost)
                    Text("This folder is empty.").font(.system(size: 12, weight: .semibold)).foregroundStyle(AC.textSub)
                    HStack(spacing: 8) {
                        Button("New System Map Here", action: { onCreateMap(folderID) }).buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !childFolders.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ArenaSectionLabel(text: "Subfolders", color: AC.gold)
                                LazyVStack(alignment: .leading, spacing: 6) {
                                    ForEach(childFolders) { folder in
                                        FolderSummaryRow(
                                            folder: folder,
                                            directCount: systemMapStore.directMapCount(folderID: folder.id),
                                            totalCount: systemMapStore.totalMapCount(folderID: folder.id),
                                            onOpen: { selectedFolderID = folder.id }
                                        )
                                    }
                                }
                            }
                        }
                        if !maps.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ArenaSectionLabel(text: "Systems Maps", color: AC.cyan)
                                LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(maps) { map in
                                    SystemMapSummaryRow(
                                        map: map,
                                        isFavorite: systemMapStore.isFavorite(map.id),
                                        onOpen: { onOpenMap(map.id) },
                                        onDuplicate: { systemMapStore.duplicateSystemMap(id: map.id) },
                                        onToggleFavorite: { systemMapStore.toggleFavorite(map.id) },
                                        onMoveTo: { destination in systemMapStore.moveMap(id: map.id, toFolder: destination) },
                                        onExport: { exportMap(map) },
                                        onDelete: {
                                            alertState = .destructive(
                                                title: "Delete “\(map.title)”?",
                                                message: "This will remove the saved system map and all its scenarios permanently.",
                                                confirmLabel: "Delete"
                                            ) { systemMapStore.deleteSystemMap(id: map.id) }
                                        }
                                    )
                                    .draggable(map.id.uuidString) {
                                        Text(map.title).font(.system(size: 11, weight: .semibold))
                                            .padding(8).background(AC.surfaceHi).colorScheme(.dark)
                                    }
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(reorderTargetMapID == map.id ? AC.gold.opacity(0.7) : Color.clear, lineWidth: 1.5))
                                    .dropDestination(for: String.self, action: { items, _ in
                                        guard let payload = items.first, SystemMapDragPayload.folderID(from: payload) == nil,
                                              let draggedMapID = UUID(uuidString: payload), draggedMapID != map.id else { return false }
                                        if systemMapStore.systemMaps.first(where: { $0.id == draggedMapID })?.folderID == folderID {
                                            systemMapStore.reorderMap(id: draggedMapID, before: map.id)
                                        } else {
                                            systemMapStore.moveMap(id: draggedMapID, toFolder: folderID)
                                        }
                                        return true
                                    }, isTargeted: { reorderTargetMapID = $0 ? map.id : (reorderTargetMapID == map.id ? nil : reorderTargetMapID) })
                                }
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private func exportMap(_ map: SystemMap) {
        guard let encoded = try? JSONCoding.encoder.encode(map) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(map.title)-system-map.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? encoded.write(to: url, options: [.atomic])
        }
    }
}

// MARK: - Recursive folder tree row

private struct SystemMapFolderRow: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    let folder: SystemMapFolder
    let depth: Int
    @Binding var selectedFolderID: UUID?
    let onCreateMapHere: (UUID?) -> Void
    let onRename: (SystemMapFolder) -> Void
    let onDelete: (SystemMapFolder) -> Void
    let mapActions: MapRowActions

    @State private var showingNewSubfolderField = false
    @State private var isDropTargeted = false

    private var children: [SystemMapFolder] { systemMapStore.childFolders(of: folder.id) }
    private var maps: [SystemMap] { systemMapStore.maps(inFolder: folder.id).sorted { $0.sortOrder < $1.sortOrder } }
    private var isSelected: Bool { selectedFolderID == folder.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Button(action: { systemMapStore.setFolderExpanded(id: folder.id, isExpanded: !folder.isExpanded) }) {
                    Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold)).frame(width: 10)
                }
                .buttonStyle(.plain)
                Button(action: { selectedFolderID = folder.id }) {
                    HStack(spacing: 5) {
                        Image(systemName: folder.iconName ?? "folder").font(.system(size: 10))
                        Text(folder.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(systemMapStore.directMapCount(folderID: folder.id))")
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(AC.textDim)
                    }
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(isSelected ? AC.cyan : (folder.colorToken?.color ?? AC.textSub))
            .padding(.vertical, 3).padding(.leading, CGFloat(depth - 1) * 12).padding(.trailing, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isDropTargeted ? AC.goldSoft : (isSelected ? AC.cyanSoft : Color.clear))
            )
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isDropTargeted ? AC.gold.opacity(0.6) : Color.clear, lineWidth: 1))
            .contextMenu {
                Button("New System Map Here") { onCreateMapHere(folder.id) }
                Button("New Subfolder") { showingNewSubfolderField = true }
                Divider()
                Button("Rename") { onRename(folder) }
                Menu("Move To…") {
                    Button("Root") { systemMapStore.moveFolder(id: folder.id, toParent: nil) }
                    ForEach(allFoldersExceptSelfAndDescendants(), id: \.id) { candidate in
                        Button(String(repeating: "— ", count: depthOf(candidate)) + candidate.name) {
                            systemMapStore.moveFolder(id: folder.id, toParent: candidate.id)
                        }
                    }
                }
                Divider()
                Button("Expand All") { systemMapStore.setDescendantsExpanded(of: folder.id, isExpanded: true) }
                Button("Collapse All") { systemMapStore.setDescendantsExpanded(of: folder.id, isExpanded: false) }
                Divider()
                Button("Delete", role: .destructive) { onDelete(folder) }
            }
            .draggable(SystemMapDragPayload.folderPayload(for: folder.id))
            .dropDestination(for: String.self, action: { items, _ in
                guard let payload = items.first else { return false }
                if let draggedFolderID = SystemMapDragPayload.folderID(from: payload) {
                    systemMapStore.moveFolder(id: draggedFolderID, toParent: folder.id)
                    return true
                }
                guard let mapID = UUID(uuidString: payload) else { return false }
                systemMapStore.moveMap(id: mapID, toFolder: folder.id)
                return true
            }, isTargeted: { isDropTargeted = $0 })

            if folder.isExpanded {
                if showingNewSubfolderField {
                    InlineCreateRow(placeholder: "New subfolder name…", autoFocus: true) { name in
                        systemMapStore.createFolder(name: name, parentFolderID: folder.id)
                        showingNewSubfolderField = false
                    }
                    .padding(.leading, CGFloat(depth) * 12)
                }
                ForEach(children) { child in
                    SystemMapFolderRow(
                        folder: child,
                        depth: depth + 1,
                        selectedFolderID: $selectedFolderID,
                        onCreateMapHere: onCreateMapHere,
                        onRename: onRename,
                        onDelete: onDelete,
                        mapActions: mapActions
                    )
                }
                ForEach(maps) { map in
                    SystemMapTreeMapRow(map: map, depth: depth + 1, actions: mapActions)
                }
            }
        }
    }

    private func depthOf(_ folder: SystemMapFolder) -> Int {
        systemMapStore.breadcrumbs(for: folder.id).count - 1
    }

    private func allFoldersExceptSelfAndDescendants() -> [SystemMapFolder] {
        let excluded = systemMapStore.descendantFolderIDs(of: folder.id).union([folder.id])
        return systemMapStore.folders.filter { !excluded.contains($0.id) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Map leaf row (shown inline in the tree beneath an expanded folder)

private struct SystemMapTreeMapRow: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    let map: SystemMap
    let depth: Int
    let actions: MapRowActions

    @State private var isDropTargeted = false

    private var isFavorite: Bool { systemMapStore.isFavorite(map.id) }

    var body: some View {
        Button(action: { actions.onOpen(map.id) }) {
            HStack(spacing: 5) {
                Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 9))
                Text(map.title).font(.system(size: 11)).lineLimit(1)
                if isFavorite {
                    Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(AC.gold)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(AC.textSub)
        .padding(.vertical, 3).padding(.leading, CGFloat(depth - 1) * 12 + 14).padding(.trailing, 4)
        .background(RoundedRectangle(cornerRadius: 5).fill(isDropTargeted ? AC.goldSoft : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(isDropTargeted ? AC.gold.opacity(0.6) : Color.clear, lineWidth: 1))
        .contextMenu {
            Button("Open") { actions.onOpen(map.id) }
            Button("Duplicate") { actions.onDuplicate(map.id) }
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites") { actions.onToggleFavorite(map.id) }
            Menu("Move To…") {
                Button("Root") { actions.onMove(map.id, nil) }
                ForEach(systemMapStore.folders.filter { $0.id != map.folderID }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { folder in
                    Button(folder.name) { actions.onMove(map.id, folder.id) }
                }
            }
            Button("Export JSON") { actions.onExport(map) }
            Divider()
            Button("Delete", role: .destructive) { actions.onDeleteRequest(map) }
        }
        .draggable(map.id.uuidString) {
            Text(map.title).font(.system(size: 11, weight: .semibold))
                .padding(8).background(AC.surfaceHi).colorScheme(.dark)
        }
        .dropDestination(for: String.self, action: { items, _ in
            guard let payload = items.first, SystemMapDragPayload.folderID(from: payload) == nil,
                  let draggedMapID = UUID(uuidString: payload), draggedMapID != map.id else { return false }
            if systemMapStore.systemMaps.first(where: { $0.id == draggedMapID })?.folderID == map.folderID {
                systemMapStore.reorderMap(id: draggedMapID, before: map.id)
            } else {
                systemMapStore.moveMap(id: draggedMapID, toFolder: map.folderID)
            }
            return true
        }, isTargeted: { isDropTargeted = $0 })
    }
}

// MARK: - Compact subfolder summary (shown in folder contents, not the tree)

private struct FolderSummaryRow: View {
    let folder: SystemMapFolder
    let directCount: Int
    let totalCount: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack {
                Image(systemName: folder.iconName ?? "folder.fill").foregroundStyle(folder.colorToken?.color ?? AC.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(AC.text)
                    Text(totalCount == directCount ? "\(directCount) map\(directCount == 1 ? "" : "s")" : "\(directCount) maps · \(totalCount) including subfolders")
                        .font(.system(size: 9)).foregroundStyle(AC.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(AC.textGhost)
            }
            .padding(10)
            .background(AngularCardShape(cornerRadius: 8, cornerCut: 12).fill(AC.surface))
            .overlay(AngularCardShape(cornerRadius: 8, cornerCut: 12).stroke(AC.borderDim, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breadcrumbs

struct SystemMapBreadcrumbView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    let folderID: UUID?
    let onNavigate: (UUID?) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button("Root") { onNavigate(nil) }
                .buttonStyle(.plain).font(.system(size: 11, weight: folderID == nil ? .bold : .regular)).foregroundStyle(folderID == nil ? AC.cyan : AC.textSub)
            ForEach(systemMapStore.breadcrumbs(for: folderID)) { folder in
                Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(AC.textGhost)
                Button(folder.name) { onNavigate(folder.id) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: folder.id == folderID ? .bold : .regular))
                    .foregroundStyle(folder.id == folderID ? AC.cyan : AC.textSub)
            }
        }
    }
}

// MARK: - Cross-folder search

private struct SystemMapSearchResultsView: View {
    @EnvironmentObject var systemMapStore: SystemMapStore
    let query: String
    let onOpenMap: (UUID) -> Void

    private var results: [SystemMap] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return systemMapStore.systemMaps
            .filter {
                $0.title.lowercased().contains(needle)
                    || $0.description.lowercased().contains(needle)
                    || $0.primaryGoal.lowercased().contains(needle)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func pathText(for map: SystemMap) -> String {
        let crumbs = systemMapStore.breadcrumbs(for: map.folderID).map(\.name)
        return (["Root"] + crumbs).joined(separator: " / ")
    }

    var body: some View {
        ScrollView {
            Group {
                if results.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 22)).foregroundStyle(AC.textGhost)
                        Text("No system maps match “\(query)”.").font(.system(size: 12)).foregroundStyle(AC.textSub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(results) { map in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pathText(for: map))
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AC.textDim)
                                SystemMapSummaryRow(
                                    map: map,
                                    isFavorite: systemMapStore.isFavorite(map.id),
                                    onOpen: { onOpenMap(map.id) },
                                    onDuplicate: { systemMapStore.duplicateSystemMap(id: map.id) },
                                    onToggleFavorite: { systemMapStore.toggleFavorite(map.id) },
                                    onDelete: { systemMapStore.deleteSystemMap(id: map.id) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Folder delete safety

private struct FolderDeleteConfirmationSheet: View {
    let folder: SystemMapFolder
    let directMapCount: Int
    let totalMapCount: Int
    let subfolderCount: Int
    let onMoveToParent: () -> Void
    let onDeleteAll: () -> Void
    let onCancel: () -> Void

    private var isEmpty: Bool { totalMapCount == 0 && subfolderCount == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DELETE FOLDER").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.threat).kerning(1.5)
            Text("“\(folder.name)”").font(.system(size: 13, weight: .semibold)).foregroundStyle(AC.text)

            if isEmpty {
                Text("This folder is empty.").font(.system(size: 11)).foregroundStyle(AC.textSub)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This folder contains:").font(.system(size: 11)).foregroundStyle(AC.textSub)
                    Text("• \(totalMapCount) Systems Map\(totalMapCount == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(AC.text)
                    Text("• \(subfolderCount) Subfolder\(subfolderCount == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(AC.text)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if !isEmpty {
                    Button("Move Contents to Parent Folder", action: onMoveToParent)
                        .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(isEmpty ? "Delete Folder" : "Delete Folder and All Contents", action: onDeleteAll)
                    .buttonStyle(ArenaButtonStyle(color: AC.threat))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Cancel", action: onCancel)
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .background(AC.bg)
        .colorScheme(.dark)
    }
}
