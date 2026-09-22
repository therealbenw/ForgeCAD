import simd

/// A 2D vector or point, used in sketch (u, v) space.
public typealias Vec2 = SIMD2<Double>

/// A 3D vector or point in model space. Model space is right-handed and Z-up.
public typealias Vec3 = SIMD3<Double>

public extension SIMD3 where Scalar == Double {
    static var unitX: Vec3 { Vec3(1, 0, 0) }
    static var unitY: Vec3 { Vec3(0, 1, 0) }
    static var unitZ: Vec3 { Vec3(0, 0, 1) }

    var length: Double { simd_length(self) }
    var lengthSquared: Double { simd_length_squared(self) }

    /// Unit-length copy, or the original vector if it is (nearly) zero.
    var normalized: Vec3 {
        let l = length
        return l > Tolerance.linear ? self / l : self
    }

    var isNearlyZero: Bool { lengthSquared <= Tolerance.linear * Tolerance.linear }

    func dot(_ other: Vec3) -> Double { simd_dot(self, other) }
    func cross(_ other: Vec3) -> Vec3 { simd_cross(self, other) }
    func distance(to other: Vec3) -> Double { simd_distance(self, other) }

    /// Some unit vector perpendicular to this one. Deterministic for a given input.
    var anyPerpendicular: Vec3 {
        let n = normalized
        let helper = abs(n.x) < 0.9 ? Vec3.unitX : Vec3.unitY
        return n.cross(helper).normalized
    }

    /// True when the two directions are parallel or anti-parallel.
    func isParallel(to other: Vec3, tol: Double = Tolerance.angular) -> Bool {
        normalized.cross(other.normalized).length <= tol
    }
}

public extension SIMD2 where Scalar == Double {
    static var unitX: Vec2 { Vec2(1, 0) }
    static var unitY: Vec2 { Vec2(0, 1) }

    var length: Double { simd_length(self) }
    var lengthSquared: Double { simd_length_squared(self) }

    var normalized: Vec2 {
        let l = length
        return l > Tolerance.linear ? self / l : self
    }

    var isNearlyZero: Bool { lengthSquared <= Tolerance.linear * Tolerance.linear }

    /// Counter-clockwise perpendicular.
    var perpendicular: Vec2 { Vec2(-y, x) }

    func dot(_ other: Vec2) -> Double { simd_dot(self, other) }

    /// The z-component of the 3D cross product; positive when `other` is
    /// counter-clockwise from `self`.
    func cross(_ other: Vec2) -> Double { x * other.y - y * other.x }

    func distance(to other: Vec2) -> Double { simd_distance(self, other) }
}
