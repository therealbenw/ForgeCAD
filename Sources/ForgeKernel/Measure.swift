import ForgeGeometry

/// Mass properties computed from the tessellated boundary. Exact for planar
/// solids; accurate to the tessellation tolerance otherwise.
public enum Measure {
    /// Signed volume via the divergence theorem. Positive for outward-facing meshes.
    public static func volume(of mesh: Mesh) -> Double {
        var sum = 0.0
        var i = 0
        while i + 2 < mesh.indices.count {
            let a = mesh.positions[Int(mesh.indices[i])]
            let b = mesh.positions[Int(mesh.indices[i + 1])]
            let c = mesh.positions[Int(mesh.indices[i + 2])]
            sum += a.dot(b.cross(c))
            i += 3
        }
        return sum / 6
    }

    public static func surfaceArea(of mesh: Mesh) -> Double {
        var sum = 0.0
        var i = 0
        while i + 2 < mesh.indices.count {
            let a = mesh.positions[Int(mesh.indices[i])]
            let b = mesh.positions[Int(mesh.indices[i + 1])]
            let c = mesh.positions[Int(mesh.indices[i + 2])]
            sum += (b - a).cross(c - a).length * 0.5
            i += 3
        }
        return sum
    }

    public static func volume(of solid: Solid, options: TessellationOptions = .default) throws -> Double {
        volume(of: try Tessellator.tessellate(solid, options: options))
    }

    public static func surfaceArea(of solid: Solid, options: TessellationOptions = .default) throws -> Double {
        surfaceArea(of: try Tessellator.tessellate(solid, options: options))
    }
}
