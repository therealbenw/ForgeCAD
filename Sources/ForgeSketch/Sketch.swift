import ForgeGeometry

public struct SketchPointID: Hashable, Codable, Sendable {
    public let raw: Int
    public init(_ raw: Int) { self.raw = raw }
}

public struct SketchEntityID: Hashable, Codable, Sendable {
    public let raw: Int
    public init(_ raw: Int) { self.raw = raw }
}

public struct SketchPoint: Hashable, Codable, Sendable {
    public let id: SketchPointID
    public var position: Vec2

    public init(id: SketchPointID, position: Vec2) {
        self.id = id
        self.position = position
    }
}

public enum SketchEntity: Hashable, Codable, Sendable {
    case line(id: SketchEntityID, start: SketchPointID, end: SketchPointID)
    case circle(id: SketchEntityID, center: SketchPointID, radius: Double)
    /// Arc from `start` to `end` about `center`, counter-clockwise unless `clockwise`.
    case arc(id: SketchEntityID, center: SketchPointID, start: SketchPointID, end: SketchPointID, clockwise: Bool)

    public var id: SketchEntityID {
        switch self {
        case .line(let id, _, _), .circle(let id, _, _), .arc(let id, _, _, _, _):
            return id
        }
    }

    /// Point ids referenced by this entity.
    public var pointIDs: [SketchPointID] {
        switch self {
        case .line(_, let a, let b): return [a, b]
        case .circle(_, let c, _): return [c]
        case .arc(_, let c, let a, let b, _): return [c, a, b]
        }
    }
}

/// A 2D sketch on a plane: points, entities through those points, and
/// constraints between them. Everything is stored in sketch (u, v) space and
/// mapped to model space via `plane`.
public struct Sketch: Hashable, Codable, Sendable {
    public var plane: Plane
    public private(set) var points: [SketchPoint]
    public private(set) var entities: [SketchEntity]
    public var constraints: [SketchConstraint]
    private var nextPointID = 0
    private var nextEntityID = 0

    public init(plane: Plane = .xy) {
        self.plane = plane
        self.points = []
        self.entities = []
        self.constraints = []
    }

    // MARK: Building

    @discardableResult
    public mutating func addPoint(_ position: Vec2) -> SketchPointID {
        let id = SketchPointID(nextPointID)
        nextPointID += 1
        points.append(SketchPoint(id: id, position: position))
        return id
    }

    @discardableResult
    public mutating func addLine(from a: SketchPointID, to b: SketchPointID) -> SketchEntityID {
        let id = SketchEntityID(nextEntityID)
        nextEntityID += 1
        entities.append(.line(id: id, start: a, end: b))
        return id
    }

    /// Adds a line with fresh endpoints.
    @discardableResult
    public mutating func addLine(_ a: Vec2, _ b: Vec2) -> SketchEntityID {
        addLine(from: addPoint(a), to: addPoint(b))
    }

    @discardableResult
    public mutating func addCircle(center: SketchPointID, radius: Double) -> SketchEntityID {
        let id = SketchEntityID(nextEntityID)
        nextEntityID += 1
        entities.append(.circle(id: id, center: center, radius: radius))
        return id
    }

    @discardableResult
    public mutating func addCircle(center: Vec2, radius: Double) -> SketchEntityID {
        addCircle(center: addPoint(center), radius: radius)
    }

    public mutating func add(_ constraint: SketchConstraint) {
        constraints.append(constraint)
    }

    public mutating func removeEntity(_ id: SketchEntityID) {
        entities.removeAll { $0.id == id }
        constraints.removeAll { $0.entityIDs.contains(id) }
    }

    // MARK: Lookup

    public func point(_ id: SketchPointID) -> SketchPoint? {
        points.first { $0.id == id }
    }

    public func position(of id: SketchPointID) -> Vec2? {
        point(id)?.position
    }

    public mutating func setPosition(_ p: Vec2, of id: SketchPointID) {
        guard let i = points.firstIndex(where: { $0.id == id }) else { return }
        points[i].position = p
    }

    public func entity(_ id: SketchEntityID) -> SketchEntity? {
        entities.first { $0.id == id }
    }

    public var lines: [(id: SketchEntityID, start: SketchPointID, end: SketchPointID)] {
        entities.compactMap {
            if case .line(let id, let a, let b) = $0 { return (id, a, b) }
            return nil
        }
    }

    // MARK: Convenience shapes

    /// A closed rectangle with horizontal/vertical constraints on its sides.
    public static func rectangle(on plane: Plane = .xy, corner: Vec2, width: Double, height: Double) -> Sketch {
        var s = Sketch(plane: plane)
        let p0 = s.addPoint(corner)
        let p1 = s.addPoint(corner + Vec2(width, 0))
        let p2 = s.addPoint(corner + Vec2(width, height))
        let p3 = s.addPoint(corner + Vec2(0, height))
        let bottom = s.addLine(from: p0, to: p1)
        let right = s.addLine(from: p1, to: p2)
        let top = s.addLine(from: p2, to: p3)
        let left = s.addLine(from: p3, to: p0)
        s.add(.horizontal(bottom))
        s.add(.horizontal(top))
        s.add(.vertical(right))
        s.add(.vertical(left))
        s.add(.fixed(p0))
        return s
    }
}
