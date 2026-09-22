import simd

/// Global tolerance policy. Every fuzzy comparison in the kernel goes through
/// here so the policy can be tuned in one place.
///
/// Model units are millimetres. `linear` is the "same point" threshold used
/// for numeric noise; `modeling` is the coarser threshold used when merging
/// user-authored geometry (e.g. deduplicating vertices while building a solid).
public enum Tolerance {
    /// Numeric-noise tolerance for lengths and coordinates (mm).
    public static let linear: Double = 1e-9
    /// Tolerance for comparing unit vectors / angles (radians).
    public static let angular: Double = 1e-9
    /// Vertex-merge tolerance for constructed geometry (mm).
    public static let modeling: Double = 1e-6

    public static func isZero(_ v: Double, tol: Double = linear) -> Bool {
        abs(v) <= tol
    }

    public static func equal(_ a: Double, _ b: Double, tol: Double = linear) -> Bool {
        abs(a - b) <= tol
    }

    public static func equal(_ a: Vec3, _ b: Vec3, tol: Double = linear) -> Bool {
        simd_distance(a, b) <= tol
    }

    public static func equal(_ a: Vec2, _ b: Vec2, tol: Double = linear) -> Bool {
        simd_distance(a, b) <= tol
    }
}
