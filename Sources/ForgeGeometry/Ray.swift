/// A half-line used for picking and projection.
public struct Ray: Hashable, Codable, Sendable {
    public var origin: Vec3
    public private(set) var direction: Vec3

    public init(origin: Vec3, direction: Vec3) {
        precondition(!direction.isNearlyZero, "Ray direction must be non-zero")
        self.origin = origin
        self.direction = direction.normalized
    }

    public func point(at t: Double) -> Vec3 {
        origin + direction * t
    }

    /// Parameter `t` where the ray hits the plane, or `nil` if it is parallel
    /// or the hit is behind the origin.
    public func intersect(_ plane: Plane) -> Double? {
        let denom = direction.dot(plane.normal)
        if Tolerance.isZero(denom, tol: Tolerance.angular) { return nil }
        let t = (plane.origin - origin).dot(plane.normal) / denom
        return t >= 0 ? t : nil
    }

    public func closestPoint(to p: Vec3) -> Vec3 {
        let t = max(0, (p - origin).dot(direction))
        return point(at: t)
    }
}
