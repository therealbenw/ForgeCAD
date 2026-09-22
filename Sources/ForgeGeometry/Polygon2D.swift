/// A simple (non-self-intersecting) 2D polygon given by its vertices in order.
public struct Polygon2D: Hashable, Codable, Sendable {
    public var points: [Vec2]

    public init(_ points: [Vec2]) {
        self.points = points
    }

    /// Positive for counter-clockwise winding.
    public var signedArea: Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for i in points.indices {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            sum += a.cross(b)
        }
        return sum * 0.5
    }

    public var area: Double { abs(signedArea) }
    public var isCounterClockwise: Bool { signedArea > 0 }

    public var centroid: Vec2 {
        guard !points.isEmpty else { return .zero }
        return points.reduce(Vec2.zero, +) / Double(points.count)
    }

    /// Indices into `points` forming one triangle. Winding is counter-clockwise
    /// in (u, v) regardless of the polygon's original winding.
    public struct Triangle: Hashable, Codable, Sendable {
        public var a: Int
        public var b: Int
        public var c: Int

        public init(_ a: Int, _ b: Int, _ c: Int) {
            self.a = a
            self.b = b
            self.c = c
        }
    }

    /// Ear-clipping triangulation. O(n²) — fine for sketch profiles, revisit
    /// when faces with hundreds of vertices show up.
    ///
    /// On a degenerate input (collinear runs, self-intersection) the routine
    /// returns the ears it managed to clip rather than looping forever.
    public func triangulate() -> [Triangle] {
        guard points.count >= 3 else { return [] }

        var ring = Array(points.indices)
        if !isCounterClockwise { ring.reverse() }

        var result: [Triangle] = []
        result.reserveCapacity(points.count - 2)

        while ring.count > 3 {
            var clipped = false
            for i in ring.indices {
                let prev = ring[(i + ring.count - 1) % ring.count]
                let cur = ring[i]
                let next = ring[(i + 1) % ring.count]
                if isEar(prev, cur, next, ring: ring) {
                    result.append(Triangle(prev, cur, next))
                    ring.remove(at: i)
                    clipped = true
                    break
                }
            }
            if !clipped { break }
        }
        if ring.count == 3 {
            result.append(Triangle(ring[0], ring[1], ring[2]))
        }
        return result
    }

    private func isEar(_ ia: Int, _ ib: Int, _ ic: Int, ring: [Int]) -> Bool {
        let a = points[ia], b = points[ib], c = points[ic]
        // Convex corner (CCW turn) with non-zero area.
        guard (b - a).cross(c - b) > Tolerance.linear else { return false }
        for i in ring where i != ia && i != ib && i != ic {
            if Self.contains(a, b, c, point: points[i]) { return false }
        }
        return true
    }

    private static func contains(_ a: Vec2, _ b: Vec2, _ c: Vec2, point p: Vec2) -> Bool {
        let tol = -Tolerance.linear
        return (b - a).cross(p - a) >= tol
            && (c - b).cross(p - b) >= tol
            && (a - c).cross(p - c) >= tol
    }
}
