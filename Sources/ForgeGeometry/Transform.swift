import simd

/// A rigid or affine 3D transform backed by a column-major 4×4 matrix.
public struct Transform: Equatable, @unchecked Sendable {
    public var matrix: simd_double4x4

    public init(matrix: simd_double4x4) {
        self.matrix = matrix
    }

    public static let identity = Transform(matrix: matrix_identity_double4x4)

    public static func translation(_ t: Vec3) -> Transform {
        var m = matrix_identity_double4x4
        m.columns.3 = SIMD4(t.x, t.y, t.z, 1)
        return Transform(matrix: m)
    }

    /// Rotation by `angle` radians about `axis` (right-hand rule).
    public static func rotation(axis: Vec3, angle: Double) -> Transform {
        Transform(matrix: simd_double4x4(simd_quatd(angle: angle, axis: axis.normalized)))
    }

    public static func scale(_ s: Vec3) -> Transform {
        Transform(matrix: simd_double4x4(diagonal: SIMD4(s.x, s.y, s.z, 1)))
    }

    public static func scale(_ s: Double) -> Transform {
        scale(Vec3(repeating: s))
    }

    /// Right-handed view matrix looking from `eye` toward `target`.
    public static func lookAt(eye: Vec3, target: Vec3, up: Vec3) -> Transform {
        let f = (target - eye).normalized
        let s = f.cross(up).normalized
        let u = s.cross(f)
        let m = simd_double4x4(columns: (
            SIMD4(s.x, u.x, -f.x, 0),
            SIMD4(s.y, u.y, -f.y, 0),
            SIMD4(s.z, u.z, -f.z, 0),
            SIMD4(-s.dot(eye), -u.dot(eye), f.dot(eye), 1)
        ))
        return Transform(matrix: m)
    }

    public func applying(point p: Vec3) -> Vec3 {
        let r = matrix * SIMD4(p.x, p.y, p.z, 1)
        return Vec3(r.x, r.y, r.z) / r.w
    }

    /// Applies only the linear part (no translation). Not renormalised.
    public func applying(vector v: Vec3) -> Vec3 {
        let r = matrix * SIMD4(v.x, v.y, v.z, 0)
        return Vec3(r.x, r.y, r.z)
    }

    /// Applies the linear part and renormalises — for normals and axes.
    public func applying(direction d: Vec3) -> Vec3 {
        applying(vector: d).normalized
    }

    public var inverse: Transform {
        Transform(matrix: matrix.inverse)
    }

    /// `(a * b)` applies `b` first, then `a`.
    public static func * (a: Transform, b: Transform) -> Transform {
        Transform(matrix: a.matrix * b.matrix)
    }

    /// Column-major flattening (16 values), used for hashing and serialisation.
    public var flattened: [Double] {
        [matrix.columns.0, matrix.columns.1, matrix.columns.2, matrix.columns.3]
            .flatMap { [$0.x, $0.y, $0.z, $0.w] }
    }
}

extension Transform: Hashable {
    public func hash(into hasher: inout Hasher) {
        for v in flattened { hasher.combine(v) }
    }
}

extension Transform: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let v = try container.decode([Double].self)
        guard v.count == 16 else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Transform expects 16 column-major values, got \(v.count)"
            )
        }
        matrix = simd_double4x4(columns: (
            SIMD4(v[0], v[1], v[2], v[3]),
            SIMD4(v[4], v[5], v[6], v[7]),
            SIMD4(v[8], v[9], v[10], v[11]),
            SIMD4(v[12], v[13], v[14], v[15])
        ))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(flattened)
    }
}
