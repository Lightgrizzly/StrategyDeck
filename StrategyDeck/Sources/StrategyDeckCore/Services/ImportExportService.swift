import Foundation

/// Pure JSON import/export logic. No UI dependency.
public enum ImportExportError: LocalizedError {
    case invalidJSON(underlying: Error)
    case noData

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let e): return "The file is not valid JSON or does not match the expected format.\n\n\(e.localizedDescription)"
        case .noData: return "No data was found to export."
        }
    }
}

public struct ImportExportService {
    public init() {}

    /// Encodes the given KnowledgeLibrary to pretty-printed JSON.
    public func export(_ data: KnowledgeLibrary) throws -> Data {
        do {
            return try JSONCoding.encoder.encode(data)
        } catch {
            throw ImportExportError.invalidJSON(underlying: error)
        }
    }

    /// Decodes a KnowledgeLibrary from raw JSON bytes.
    public func `import`(from data: Data) throws -> KnowledgeLibrary {
        do {
            return try JSONCoding.decoder.decode(KnowledgeLibrary.self, from: data)
        } catch {
            throw ImportExportError.invalidJSON(underlying: error)
        }
    }

    /// Reads a file and imports KnowledgeLibrary from it.
    public func importFile(at url: URL) throws -> KnowledgeLibrary {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportExportError.invalidJSON(underlying: error)
        }
        return try `import`(from: data)
    }
}
