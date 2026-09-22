/// Geometric and dimensional constraints between sketch points and entities.
public enum SketchConstraint: Hashable, Codable, Sendable {
    /// Two points share a position.
    case coincident(SketchPointID, SketchPointID)
    /// The point may not be moved by the solver.
    case fixed(SketchPointID)
    /// A line's endpoints share a v coordinate.
    case horizontal(SketchEntityID)
    /// A line's endpoints share a u coordinate.
    case vertical(SketchEntityID)
    /// Euclidean distance between two points.
    case distance(SketchPointID, SketchPointID, Double)
    /// `b.u − a.u == value`.
    case horizontalDistance(SketchPointID, SketchPointID, Double)
    /// `b.v − a.v == value`.
    case verticalDistance(SketchPointID, SketchPointID, Double)

    public var entityIDs: [SketchEntityID] {
        switch self {
        case .horizontal(let e), .vertical(let e): return [e]
        default: return []
        }
    }

    public var pointIDs: [SketchPointID] {
        switch self {
        case .coincident(let a, let b), .distance(let a, let b, _),
             .horizontalDistance(let a, let b, _), .verticalDistance(let a, let b, _):
            return [a, b]
        case .fixed(let p):
            return [p]
        case .horizontal, .vertical:
            return []
        }
    }
}
