import ForgeGeometry
import ForgeKernel

/// Wavefront OBJ export with per-vertex normals. Indices are 1-based per spec.
public enum OBJWriter {
    public static func string(_ mesh: Mesh, objectName: String = "ForgeCAD") -> String {
        var out = "# Exported by ForgeCAD\no \(objectName)\n"
        for p in mesh.positions { out += "v \(p.x) \(p.y) \(p.z)\n" }
        for n in mesh.normals { out += "vn \(n.x) \(n.y) \(n.z)\n" }
        var i = 0
        while i + 2 < mesh.indices.count {
            let a = mesh.indices[i] + 1, b = mesh.indices[i + 1] + 1, c = mesh.indices[i + 2] + 1
            out += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
            i += 3
        }
        return out
    }
}
