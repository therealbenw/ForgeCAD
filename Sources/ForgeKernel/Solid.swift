import ForgeGeometry

/// A boundary-representation solid: a single closed shell of faces.
///
/// `Solid` is a plain value. Construction goes through `SolidBuilder` so that
/// identifiers stay unique and shared vertices/edges are merged.
public struct Solid: Hashable, Codable, Sendable {
    public var vertices: [VertexID: Vertex]
    public var edges: [EdgeID: Edge]
    public var faces: [FaceID: Face]

    public init(vertices: [VertexID: Vertex] = [:], edges: [EdgeID: Edge] = [:], faces: [FaceID: Face] = [:]) {
        self.vertices = vertices
        self.edges = edges
        self.faces = faces
    }

    public var isEmpty: Bool { faces.isEmpty }

    /// Faces in a stable order (by id) — use this whenever output must be deterministic.
    public var sortedFaces: [Face] { faces.values.sorted { $0.id < $1.id } }
    public var sortedEdges: [Edge] { edges.values.sorted { $0.id < $1.id } }
    public var sortedVertices: [Vertex] { vertices.values.sorted { $0.id < $1.id } }

    public func vertex(_ id: VertexID) -> Vertex? { vertices[id] }
    public func edge(_ id: EdgeID) -> Edge? { edges[id] }
    public func face(_ id: FaceID) -> Face? { faces[id] }

    /// The start vertex of an oriented edge, honouring its direction.
    public func startVertex(of oriented: OrientedEdge) -> VertexID? {
        guard let e = edges[oriented.edge] else { return nil }
        return oriented.forward ? e.start : e.end
    }

    /// Vertex positions around a loop, one per edge, in traversal order.
    /// Only meaningful for loops made of line edges; arcs are not sampled here.
    public func loopPoints(_ loop: Loop) -> [Vec3] {
        loop.edges.compactMap { oe in
            startVertex(of: oe).flatMap { vertices[$0]?.point }
        }
    }

    public var boundingBox: BoundingBox {
        BoundingBox(points: vertices.values.map(\.point))
    }

    public func transformed(by t: Transform) -> Solid {
        var copy = self
        for (id, v) in vertices {
            copy.vertices[id]?.point = t.applying(point: v.point)
        }
        for (id, e) in edges {
            if case .arc(let center, let normal, let radius) = e.curve {
                copy.edges[id]?.curve = .arc(
                    center: t.applying(point: center),
                    normal: t.applying(direction: normal),
                    radius: radius
                )
            }
        }
        for (id, f) in faces {
            copy.faces[id]?.surface = f.surface.transformed(by: t)
        }
        return copy
    }

    /// Euler–Poincaré sanity check for a single closed shell without through-holes:
    /// V − E + F == 2. Returns `false` for anything that isn't a simple closed solid.
    public var satisfiesEulerFormula: Bool {
        vertices.count - edges.count + faces.count == 2
    }
}
