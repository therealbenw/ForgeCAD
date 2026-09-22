import Foundation
import ForgeGeometry
import ForgeKernel

/// STL export. Binary is the default for size; ASCII is handy for debugging.
public enum STLWriter {
    /// Little-endian binary STL: 80-byte header, UInt32 triangle count, then
    /// 50 bytes per triangle (normal, three vertices, UInt16 attribute).
    public static func binaryData(_ mesh: Mesh, name: String = "ForgeCAD") -> Data {
        var data = Data()
        data.reserveCapacity(84 + mesh.triangleCount * 50)

        var header = Array(name.utf8.prefix(80))
        header += Array(repeating: 0, count: 80 - header.count)
        data.append(contentsOf: header)
        appendLE(UInt32(mesh.triangleCount), to: &data)

        for t in 0..<mesh.triangleCount {
            let i0 = Int(mesh.indices[t * 3])
            let i1 = Int(mesh.indices[t * 3 + 1])
            let i2 = Int(mesh.indices[t * 3 + 2])
            let a = mesh.positions[i0], b = mesh.positions[i1], c = mesh.positions[i2]
            let n = (b - a).cross(c - a).normalized
            for v in [n, a, b, c] {
                appendLE(Float(v.x).bitPattern, to: &data)
                appendLE(Float(v.y).bitPattern, to: &data)
                appendLE(Float(v.z).bitPattern, to: &data)
            }
            appendLE(UInt16(0), to: &data)
        }
        return data
    }

    public static func asciiString(_ mesh: Mesh, name: String = "ForgeCAD") -> String {
        var out = "solid \(name)\n"
        for t in 0..<mesh.triangleCount {
            let i0 = Int(mesh.indices[t * 3])
            let i1 = Int(mesh.indices[t * 3 + 1])
            let i2 = Int(mesh.indices[t * 3 + 2])
            let a = mesh.positions[i0], b = mesh.positions[i1], c = mesh.positions[i2]
            let n = (b - a).cross(c - a).normalized
            out += "  facet normal \(fmt(n))\n    outer loop\n"
            out += "      vertex \(fmt(a))\n      vertex \(fmt(b))\n      vertex \(fmt(c))\n"
            out += "    endloop\n  endfacet\n"
        }
        out += "endsolid \(name)\n"
        return out
    }

    private static func fmt(_ v: Vec3) -> String {
        "\(v.x) \(v.y) \(v.z)"
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
