import Foundation

/// Errors surfaced by the persistence layer. Never swallowed silently — the UI
/// turns these into alerts so user data is never lost without notice.
public enum PersistenceError: LocalizedError {
    case decodeFailed(path: String, underlying: Error)
    case encodeFailed(underlying: Error)
    case writeFailed(path: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .decodeFailed(let path, let underlying):
            return "Could not read “\(path)”. The file may be corrupted.\n\n\(underlying.localizedDescription)"
        case .encodeFailed(let underlying):
            return "Could not prepare data for saving.\n\n\(underlying.localizedDescription)"
        case .writeFailed(let path, let underlying):
            return "Could not save to “\(path)”.\n\n\(underlying.localizedDescription)"
        }
    }
}

/// UI-agnostic JSON persistence. Deliberately generic so the storage backend
/// (JSON today) could be swapped for SwiftData/SQLite later without touching the
/// stores that depend on it.
///
/// The abstraction is a small protocol so tests can inject a temp-directory or
/// in-memory implementation.
public protocol PersistenceService {
    /// Directory where user-owned files live (created on demand).
    var containerDirectory: URL { get }
    func url(for filename: String) -> URL
    func fileExists(_ filename: String) -> Bool
    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T
    func save<T: Encodable>(_ value: T, to filename: String) throws
    func delete(_ filename: String) throws
    /// The bundled read-only seed shipped inside the app.
    func loadBundledLibrary() throws -> KnowledgeLibrary
}

public final class JSONPersistenceService: PersistenceService {
    public let containerDirectory: URL
    private let fileManager: FileManager

    /// - Parameters:
    ///   - containerDirectory: where user files are written. Defaults to
    ///     `~/Library/Application Support/StrategyDeck`.
    public init(
        containerDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.containerDirectory = containerDirectory ?? JSONPersistenceService.defaultContainer(fileManager)
    }

    private static func defaultContainer(_ fm: FileManager) -> URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("StrategyDeck", isDirectory: true)
    }

    private func ensureContainer() throws {
        if !fileManager.fileExists(atPath: containerDirectory.path) {
            try fileManager.createDirectory(at: containerDirectory, withIntermediateDirectories: true)
        }
    }

    public func url(for filename: String) -> URL {
        containerDirectory.appendingPathComponent(filename)
    }

    public func fileExists(_ filename: String) -> Bool {
        fileManager.fileExists(atPath: url(for: filename).path)
    }

    public func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let fileURL = url(for: filename)
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw PersistenceError.decodeFailed(path: filename, underlying: error)
        }
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodeFailed(path: filename, underlying: error)
        }
    }

    public func save<T: Encodable>(_ value: T, to filename: String) throws {
        try ensureContainer()
        let data: Data
        do {
            data = try JSONCoding.encoder.encode(value)
        } catch {
            throw PersistenceError.encodeFailed(underlying: error)
        }
        do {
            // Atomic write: writes to a temp file then renames, so a crash mid-write
            // can never leave a half-written (corrupt) library on disk.
            try data.write(to: url(for: filename), options: [.atomic])
        } catch {
            throw PersistenceError.writeFailed(path: filename, underlying: error)
        }
    }

    public func delete(_ filename: String) throws {
        let fileURL = url(for: filename)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    public func loadBundledLibrary() throws -> KnowledgeLibrary {
        // Seed is defined as Swift code in SeedCardProvider so there is no
        // JSON resource file to decode — the seed always matches the model.
        return SeedCardProvider.makeLibrary()
    }
}

/// Shared encoder/decoder configuration. Used by both the app and the seed
/// generator so what is written always matches what is read.
public enum JSONCoding {
    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
