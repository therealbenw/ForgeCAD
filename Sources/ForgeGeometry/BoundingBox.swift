import simd

/// Axis-aligned bounding box. `empty` has `min > max` and unions with anything.
public struct BoundingBox: Hashable, Codable, Sendable {
    public var min: Vec3
    public var max: Vec3

    public static let empty = BoundingBox(
        min: Vec3(repeating: .infinity),
        max: Vec3(repeating: -.infinity)
    )

    public init(min: Vec3, max: Vec3) {
        self.min = min
        self.max = max
    }

    public init(points: some Sequence<Vec3>) {
        self = .empty
        for p in points { expand(toInclude: p) }
    }

    public var isEmpty: Bool { min.x > max.x || min.y > max.y || min.z > max.z }
    public var center: Vec3 { (min + max) * 0.5 }
    public var size: Vec3 { isEmpty ? .zero : max - min }
    public var diagonal: Double { size.length }
    /// Radius of the bounding sphere centred on `center`.
    public var radius: Double { diagonal * 0.5 }

    public mutating func expand(toInclude p: Vec3) {
        min = simd_min(min, p)
        max = simd_max(max, p)
    }

    public func union(_ other: BoundingBox) -> BoundingBox {
        BoundingBox(min: simd_min(min, other.min), max: simd_max(max, other.max))
    }

    public func contains(_ p: Vec3, tol: Double = Tolerance.linear) -> Bool {
        !isEmpty
            && p.x >= min.x - tol && p.x <= max.x + tol
            && p.y >= min.y - tol && p.y <= max.y + tol
            && p.z >= min.z - tol && p.z <= max.z + tol
    }
}
