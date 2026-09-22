import SwiftUI
import UniformTypeIdentifiers
import ForgeDocument
import ForgeIO

/// SwiftUI document wrapper for a `.forge` part. The on-disk format is owned
/// by `ForgeFileFormat` in ForgeIO; this type only adapts it to `DocumentGroup`.
struct ForgeFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.forge]

    var part: Document

    init(part: Document = Document(name: "Untitled")) {
        self.part = part
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var part = try ForgeFileFormat.decode(data)
        // The file name is the user-facing name; keep the embedded one in sync
        // so exports (STL solid name etc.) follow renames done in Files.
        if let filename = configuration.file.filename {
            part.name = (filename as NSString).deletingPathExtension
        }
        self.part = part
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try ForgeFileFormat.encode(part))
    }
}

extension UTType {
    /// Matches `UTExportedTypeDeclarations` in App/project.yml.
    static let forge = UTType(exportedAs: ForgeFileFormat.uniformTypeIdentifier, conformingTo: .json)
    /// Apple's system-declared identifier for STL.
    static let stl = UTType(importedAs: "public.standard-tessellated-geometry-format", conformingTo: .threeDContent)
}
