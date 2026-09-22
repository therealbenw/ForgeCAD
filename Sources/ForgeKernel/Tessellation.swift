import ForgeGeometry

/// An indexed triangle mesh with flat (per-face) shading. Each face gets its
/// own vertices so hard edges stay crisp.
public struct Mesh: Hashable, Codable, Sendable {
    public var positions: [Vec3]
    public var normals: [Vec3]
    public var indices: [UInt32]

    public init(positions: [Vec3] = [], normals: [Vec3] = [], indices: [UInt32] = []) {
        self.positions = positions
        self.normals = normals
        self.indices = indices
    }

    public var isEmpty: Bool { indices.isEmpty }
    public var triangleCount: Int { indices.count / 3 }
    public var boundingBox: BoundingBox { BoundingBox(points: positions) }

    public mutating func append(_ other: Mesh) {
        let base = UInt32(positions.count)
        positions.append(contentsOf: other.positions)
        normals.append(contentsOf: other.normals)
        indices.append(contentsOf: other.indices.map { $0 + base })
    }
}

public struct TessellationOptions: Hashable, Sendable {
    /// Maximum distance between a curved surface and its triangles (mm).
    public var chordTolerance: Double
    /// Maximum angle between adjacent facet normals on curved surfaces (radians).
    public var angularTolerance: Double

    public init(chordTolerance: Double = 0.01, angularTolerance: Double = 0.2) {
        self.chordTolerance = chordTolerance
        self.angularTolerance = angularTolerance
    }

    public static let `default` = TessellationOptions()
}

public enum Tessellator {
    public static func tessellate(_ solid: Solid, options: TessellationOptions = .default) throws -> Mesh {
        var mesh = Mesh()
        for face in solid.sortedFaces {
            mesh.append(try tessellate(face: face, in: solid, options: options))
        }
        return mesh
    }

    public static func tessellate(face: Face, in solid: Solid, options: TessellationOptions = .default) throws -> Mesh {
        switch face.surface {
        case .plane(let plane):
            return try tessellatePlanar(face: face, plane: plane, in: solid)
        case .cylinder:
            // Roadmap M2: sample the cylinder by chord/angular tolerance.
            throw KernelError.unsupported("tessellation of cylindrical faces")
        }
    }

    private static func tessellatePlanar(face: Face, plane: Plane, in solid: Solid) throws -> Mesh {
        guard face.holes.isEmpty else {
            // Roadmap M2: bridge holes into the outer loop before ear clipping.
            throw KernelError.unsupported("tessellation of planar faces with holes")
        }
        let points = solid.loopPoints(face.outer)
        guard points.count == face.outer.edges.count, points.count >= 3 else {
            throw KernelError.invalidTopology("face \(face.id.raw) has a broken outer loop")
        }

        let polygon = Polygon2D(points.map(plane.toLocal))
        let triangles = polygon.triangulate()
        guard !triangles.isEmpty else {
            throw KernelError.degenerateGeometry("face \(face.id.raw) could not be triangulated")
        }

        // Ear clipping yields CCW triangles in (u, v), i.e. normals along +plane.normal.
        // Flip winding when the face is reversed relative to its surface.
        let normal = face.sameSense ? plane.normal : -plane.normal
        var mesh = Mesh()
        mesh.positions = points
        mesh.normals = Array(repeating: normal, count: points.count)
        mesh.indices.reserveCapacity(triangles.count * 3)
        for t in triangles {
            if face.sameSense {
                mesh.indices += [UInt32(t.a), UInt32(t.b), UInt32(t.c)]
            } else {
                mesh.indices += [UInt32(t.a), UInt32(t.c), UInt32(t.b)]
            }
        }
        return mesh
    }
}
