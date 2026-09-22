import simd

/// An oriented plane with an explicit in-plane basis so 2D sketch coordinates
/// map deterministically to and from model space.
///
/// `(uAxis, vAxis, normal)` is always a right-handed orthonormal frame:
/// `normal == uAxis × vAxis`.
public struct Plane: Hashable, Codable, Sendable {
    public var origin: Vec3
    public private(set) var normal: Vec3
    public private(set) var uAxis: Vec3
    public private(set) var vAxis: Vec3

    /// - Parameters:
    ///   - origin: A point on the plane.
    ///   - normal: Any non-zero normal; it is normalised.
    ///   - uHint: Preferred direction for the in-plane u axis. It is projected
    ///     onto the plane; if it is parallel to the normal a perpendicular is chosen.
    public init(origin: Vec3, normal: Vec3, uHint: Vec3? = nil) {
        precondition(!normal.isNearlyZero, "Plane normal must be non-zero")
        let n = normal.normalized
        var u = uHint ?? n.anyPerpendicular
        u = (u - n * u.dot(n)).normalized
        if u.isNearlyZero { u = n.anyPerpendicular }
        self.origin = origin
        self.normal = n
        self.uAxis = u
        self.vAxis = n.cross(u)
    }

    /// u = +X, v = +Y, normal = +Z.
    public static let xy = Plane(origin: .zero, normal: .unitZ, uHint: .unitX)
    /// u = +X, v = +Z, normal = −Y.
    public static let xz = Plane(origin: .zero, normal: -Vec3.unitY, uHint: .unitX)
    /// u = +Y, v = +Z, normal = +X.
    public static let yz = Plane(origin: .zero, normal: .unitX, uHint: .unitY)

    public func signedDistance(to p: Vec3) -> Double {
        (p - origin).dot(normal)
    }

    public func contains(_ p: Vec3, tol: Double = Tolerance.linear) -> Bool {
        Tolerance.isZero(signedDistance(to: p), tol: tol)
    }

    /// Closest point on the plane.
    public func project(_ p: Vec3) -> Vec3 {
        p - normal * signedDistance(to: p)
    }

    /// Model-space point → (u, v) sketch coordinates (drops the off-plane component).
    public func toLocal(_ p: Vec3) -> Vec2 {
        let d = p - origin
        return Vec2(d.dot(uAxis), d.dot(vAxis))
    }

    /// (u, v) sketch coordinates → model-space point.
    public func toWorld(_ p: Vec2) -> Vec3 {
        origin + uAxis * p.x + vAxis * p.y
    }

    /// Parallel plane shifted along the normal.
    public func offset(by distance: Double) -> Plane {
        var copy = self
        copy.origin += normal * distance
        return copy
    }

    /// Same plane with the normal reversed; u is preserved, v flips.
    public var flipped: Plane {
        Plane(origin: origin, normal: -normal, uHint: uAxis)
    }

    public func transformed(by t: Transform) -> Plane {
        Plane(
            origin: t.applying(point: origin),
            normal: t.applying(direction: normal),
            uHint: t.applying(direction: uAxis)
        )
    }
}
