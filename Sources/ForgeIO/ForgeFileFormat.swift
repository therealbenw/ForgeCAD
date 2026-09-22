import Foundation
import ForgeDocument

/// The native `.forge` document format: the `Document` feature history as
/// pretty-printed, key-sorted JSON so diffs stay readable in version control.
public enum ForgeFileFormat {
    public static let fileExtension = "forge"
    public static let uniformTypeIdentifier = "com.forgecad.document"

    public enum FormatError: Error, Hashable, Sendable, CustomStringConvertible {
        case newerFormat(found: Int, supported: Int)

        public var description: String {
            switch self {
            case .newerFormat(let found, let supported):
                return "Document format \(found) is newer than the supported version \(supported)"
            }
        }
    }

    public static func encode(_ document: Document) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> Document {
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.formatVersion <= Document.currentFormatVersion else {
            throw FormatError.newerFormat(found: document.formatVersion, supported: Document.currentFormatVersion)
        }
        // Future: run per-version migrations here when formatVersion < current.
        return document
    }
}
