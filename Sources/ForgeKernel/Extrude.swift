import ForgeGeometry

/// Linear extrusion of a closed planar profile into a solid.
public enum Extrude {
    /// Extrudes a closed planar profile (model-space points, no repeated
    /// closing point) by `distance` along `direction`.
    ///
    /// The profile may be concave but must not self-intersect. Winding does not
    /// matter — it is normalised so that all face normals point outward.
    public static func extrude(profile: [Vec3], direction: Vec3, distance: Double) throws -> Solid {
        guard profile.count >= 3 else {
            throw KernelError.degenerateGeometry("profile needs at least 3 points")
        }
        guard !Tolerance.isZero(distance) else {
            throw KernelError.degenerateGeometry("extrude distance is zero")
        }
        guard !direction.isNearlyZero else {
            throw KernelError.degenerateGeometry("extrude direction is zero")
        }

        let dir = direction.normalized * (distance < 0 ? -1 : 1)
        let offset = dir * abs(distance)

        // Wind the profile counter-clockwise about the extrusion direction so
        // that the bottom cap, top cap and side walls all face outward.
        let normal = SolidBuilder.newellNormal(profile)
        guard !normal.isNearlyZero else {
            throw KernelError.degenerateGeometry("profile is collinear")
        }
        guard !Tolerance.isZero(normal.normalized.dot(dir), tol: Tolerance.angular) else {
            throw KernelError.degenerateGeometry("extrude direction lies in the profile plane")
        }
        let base = normal.dot(dir) < 0 ? Array(profile.reversed()) : profile
        let top = base.map { $0 + offset }

        var builder = SolidBuilder()
        try builder.addPlanarFace(Array(base.reversed()))   // bottom cap faces −dir
        try builder.addPlanarFace(top)                       // top cap faces +dir
        for i in base.indices {
            let j = (i + 1) % base.count
            try builder.addPlanarFace([base[i], base[j], top[j], top[i]])
        }
        return builder.build()
    }

    /// Extrudes a 2D profile drawn on `plane` along the plane normal.
    /// Negative distances extrude against the normal.
    public static func extrude(profile: [Vec2], on plane: Plane, distance: Double) throws -> Solid {
        try extrude(profile: profile.map(plane.toWorld), direction: plane.normal, distance: distance)
    }
}
