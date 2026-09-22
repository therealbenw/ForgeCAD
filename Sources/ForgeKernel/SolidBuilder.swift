import ForgeGeometry

/// Incrementally assembles a `Solid`, merging coincident vertices and shared
/// line edges so the result has proper shared topology.
///
/// Vertex merging is a linear scan; that is fine for feature-level solids
/// (tens to hundreds of vertices) and should become a spatial hash later.
public struct SolidBuilder: Sendable {
    private var solid = Solid()
    private var nextVertex = 0
    private var nextEdge = 0
    private var nextFace = 0
    private let mergeTolerance: Double

    public init(mergeTolerance: Double = Tolerance.modeling) {
        self.mergeTolerance = mergeTolerance
    }

    public func build() -> Solid { solid }

    // MARK: Vertices

    @discardableResult
    public mutating func addVertex(_ p: Vec3) -> VertexID {
        if let existing = solid.vertices.values.first(where: { Tolerance.equal($0.point, p, tol: mergeTolerance) }) {
            return existing.id
        }
        let id = VertexID(nextVertex)
        nextVertex += 1
        solid.vertices[id] = Vertex(id: id, point: p)
        return id
    }

    // MARK: Edges

    /// Adds a line edge, or returns the existing one between the same vertices.
    /// The returned orientation is relative to the requested `from → to` direction.
    @discardableResult
    public mutating func addLineEdge(from a: VertexID, to b: VertexID) -> OrientedEdge {
        for e in solid.edges.values where e.curve == .line {
            if e.start == a && e.end == b { return OrientedEdge(e.id, forward: true) }
            if e.start == b && e.end == a { return OrientedEdge(e.id, forward: false) }
        }
        let id = EdgeID(nextEdge)
        nextEdge += 1
        solid.edges[id] = Edge(id: id, start: a, end: b, curve: .line)
        return OrientedEdge(id, forward: true)
    }

    /// Adds a closed loop of line edges through the given vertices.
    public mutating func addLineLoop(_ ids: [VertexID]) -> Loop {
        var edges: [OrientedEdge] = []
        for i in ids.indices {
            edges.append(addLineEdge(from: ids[i], to: ids[(i + 1) % ids.count]))
        }
        return Loop(edges: edges)
    }

    // MARK: Faces

    /// Adds a planar face whose outer boundary passes through `points` in order.
    /// The face normal follows the winding (right-hand rule), so wind the
    /// points counter-clockwise when viewed from outside the solid.
    @discardableResult
    public mutating func addPlanarFace(_ points: [Vec3], holes: [[Vec3]] = []) throws -> FaceID {
        guard points.count >= 3 else {
            throw KernelError.degenerateGeometry("a face needs at least 3 points")
        }
        let normal = Self.newellNormal(points)
        guard !normal.isNearlyZero else {
            throw KernelError.degenerateGeometry("face points are collinear")
        }
        let centroid = points.reduce(Vec3.zero, +) / Double(points.count)
        let plane = Plane(origin: centroid, normal: normal, uHint: points[1] - points[0])
        for p in points + holes.flatMap({ $0 }) where !plane.contains(p, tol: mergeTolerance) {
            throw KernelError.nonPlanarProfile
        }

        let outer = addLineLoop(points.map { addVertex($0) })
        let holeLoops = holes.map { addLineLoop($0.map { addVertex($0) }) }

        let id = FaceID(nextFace)
        nextFace += 1
        solid.faces[id] = Face(id: id, surface: .plane(plane), outer: outer, holes: holeLoops, sameSense: true)
        return id
    }

    /// Area-weighted polygon normal (Newell's method). Robust to slightly
    /// non-planar input and to concave outlines.
    public static func newellNormal(_ points: [Vec3]) -> Vec3 {
        var n = Vec3.zero
        for i in points.indices {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            n.x += (a.y - b.y) * (a.z + b.z)
            n.y += (a.z - b.z) * (a.x + b.x)
            n.z += (a.x - b.x) * (a.y + b.y)
        }
        return n
    }
}
