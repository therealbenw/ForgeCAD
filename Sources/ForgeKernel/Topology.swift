import ForgeGeometry

// MARK: - Identifiers

public struct VertexID: Hashable, Codable, Sendable, Comparable {
    public let raw: Int
    public init(_ raw: Int) { self.raw = raw }
    public static func < (a: VertexID, b: VertexID) -> Bool { a.raw < b.raw }
}

public struct EdgeID: Hashable, Codable, Sendable, Comparable {
    public let raw: Int
    public init(_ raw: Int) { self.raw = raw }
    public static func < (a: EdgeID, b: EdgeID) -> Bool { a.raw < b.raw }
}

public struct FaceID: Hashable, Codable, Sendable, Comparable {
    public let raw: Int
    public init(_ raw: Int) { self.raw = raw }
    public static func < (a: FaceID, b: FaceID) -> Bool { a.raw < b.raw }
}

// MARK: - Geometry carried by topology

/// The curve underlying an edge. Lines carry no data because their geometry is
/// fully defined by the edge's two vertices.
public enum Curve3D: Hashable, Codable, Sendable {
    case line
    /// Circular arc from the edge's start vertex to its end vertex, travelling
    /// counter-clockwise about `normal`.
    case arc(center: Vec3, normal: Vec3, radius: Double)
}

/// The surface underlying a face.
public enum Surface3D: Hashable, Codable, Sendable {
    case plane(Plane)
    case cylinder(origin: Vec3, axis: Vec3, radius: Double)

    public func transformed(by t: Transform) -> Surface3D {
        switch self {
        case .plane(let p):
            return .plane(p.transformed(by: t))
        case .cylinder(let origin, let axis, let radius):
            return .cylinder(origin: t.applying(point: origin), axis: t.applying(direction: axis), radius: radius)
        }
    }
}

// MARK: - Topological entities

public struct Vertex: Hashable, Codable, Sendable {
    public let id: VertexID
    public var point: Vec3

    public init(id: VertexID, point: Vec3) {
        self.id = id
        self.point = point
    }
}

public struct Edge: Hashable, Codable, Sendable {
    public let id: EdgeID
    public var start: VertexID
    public var end: VertexID
    public var curve: Curve3D

    public init(id: EdgeID, start: VertexID, end: VertexID, curve: Curve3D = .line) {
        self.id = id
        self.start = start
        self.end = end
        self.curve = curve
    }
}

/// An edge as used by a loop: `forward == false` means the loop traverses the
/// edge from `end` to `start`.
public struct OrientedEdge: Hashable, Codable, Sendable {
    public var edge: EdgeID
    public var forward: Bool

    public init(_ edge: EdgeID, forward: Bool = true) {
        self.edge = edge
        self.forward = forward
    }
}

/// A closed chain of oriented edges bounding a face.
public struct Loop: Hashable, Codable, Sendable {
    public var edges: [OrientedEdge]

    public init(edges: [OrientedEdge]) {
        self.edges = edges
    }
}

public struct Face: Hashable, Codable, Sendable {
    public let id: FaceID
    public var surface: Surface3D
    public var outer: Loop
    public var holes: [Loop]
    /// When `true` the face normal equals the surface normal; otherwise it is reversed.
    public var sameSense: Bool

    public init(id: FaceID, surface: Surface3D, outer: Loop, holes: [Loop] = [], sameSense: Bool = true) {
        self.id = id
        self.surface = surface
        self.outer = outer
        self.holes = holes
        self.sameSense = sameSense
    }

    public var normalIfPlanar: Vec3? {
        guard case .plane(let p) = surface else { return nil }
        return sameSense ? p.normal : -p.normal
    }
}
