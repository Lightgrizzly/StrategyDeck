import Foundation
@testable import StrategyDeckCore

/// In-memory persistence for tests — holds data in a dictionary, never touches disk.
final class InMemoryPersistence: PersistenceService {
    var storage: [String: Data] = [:]
    let containerDirectory = URL(fileURLWithPath: "/tmp/test-\(UUID().uuidString)")

    func url(for filename: String) -> URL { containerDirectory.appendingPathComponent(filename) }
    func fileExists(_ filename: String) -> Bool { storage[filename] != nil }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        guard let data = storage[filename] else {
            throw PersistenceError.decodeFailed(path: filename, underlying: NSError(domain: "test", code: 0))
        }
        return try JSONCoding.decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        storage[filename] = try JSONCoding.encoder.encode(value)
    }

    func delete(_ filename: String) throws { storage.removeValue(forKey: filename) }

    func loadBundledLibrary() throws -> KnowledgeLibrary { SeedCardProvider.makeLibrary() }
}
