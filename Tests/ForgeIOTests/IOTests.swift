import Foundation
import Testing
import ForgeGeometry
import ForgeKernel
import ForgeDocument
import ForgeSketch
@testable import ForgeIO

@Suite struct STLTests {
    @Test func binaryLayout() throws {
        let mesh = try Tessellator.tessellate(try Primitives.box(size: Vec3(1, 1, 1)))
        let data = STLWriter.binaryData(mesh, name: "box")
        #expect(mesh.triangleCount == 12)
        #expect(data.count == 84 + 12 * 50)

        let count = data.subdata(in: 80..<84).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        #expect(UInt32(littleEndian: count) == 12)
        #expect(String(decoding: data.prefix(3), as: UTF8.self) == "box")
    }

    @Test func asciiHasOneFacetPerTriangle() throws {
        let mesh = try Tessellator.tessellate(try Primitives.box(size: Vec3(1, 1, 1)))
        let text = STLWriter.asciiString(mesh)
        #expect(text.hasPrefix("solid ForgeCAD"))
        #expect(text.components(separatedBy: "facet normal").count - 1 == 12)
        #expect(text.hasSuffix("endsolid ForgeCAD\n"))
    }
}

@Suite struct OBJTests {
    @Test func countsMatchMesh() throws {
        let mesh = try Tessellator.tessellate(try Primitives.box(size: Vec3(1, 2, 3)))
        let lines = OBJWriter.string(mesh).split(separator: "\n")
        #expect(lines.filter { $0.hasPrefix("v ") }.count == mesh.positions.count)
        #expect(lines.filter { $0.hasPrefix("vn ") }.count == mesh.normals.count)
        #expect(lines.filter { $0.hasPrefix("f ") }.count == mesh.triangleCount)
    }
}

@Suite struct ForgeFileFormatTests {
    @Test func roundTrip() throws {
        var doc = Document(name: "Bracket")
        let sketch = doc.addSketch(Sketch.rectangle(corner: .zero, width: 30, height: 10))
        doc.addExtrude(of: sketch, extent: .blind(4))

        let data = try ForgeFileFormat.encode(doc)
        #expect(String(decoding: data, as: UTF8.self).contains("\"formatVersion\" : 1"))
        #expect(try ForgeFileFormat.decode(data) == doc)
    }

    @Test func rejectsNewerFormat() throws {
        var doc = Document(name: "Future")
        doc.formatVersion = Document.currentFormatVersion + 1
        let data = try ForgeFileFormat.encode(doc)
        #expect(throws: ForgeFileFormat.FormatError.self) {
            try ForgeFileFormat.decode(data)
        }
    }
}
