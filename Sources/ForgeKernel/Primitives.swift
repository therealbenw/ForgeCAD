import Foundation
import ForgeGeometry

/// Convenience constructors for common solids. Handy for tests and for the
/// app's "insert primitive" tools until those are sketch-driven.
public enum Primitives {
    /// Axis-aligned box with one corner at `origin`.
    public static func box(origin: Vec3 = .zero, size: Vec3) throws -> Solid {
        guard size.x > 0, size.y > 0, size.z > 0 else {
            throw KernelError.degenerateGeometry("box size must be positive on every axis")
        }
        let profile = [
            origin,
            origin + Vec3(size.x, 0, 0),
            origin + Vec3(size.x, size.y, 0),
            origin + Vec3(0, size.y, 0),
        ]
        return try Extrude.extrude(profile: profile, direction: .unitZ, distance: size.z)
    }

    /// Regular prism (polygonal approximation of a cylinder) standing on `plane`.
    public static func prism(on plane: Plane = .xy, radius: Double, height: Double, sides: Int = 32) throws -> Solid {
        guard sides >= 3 else { throw KernelError.degenerateGeometry("prism needs at least 3 sides") }
        guard radius > 0 else { throw KernelError.degenerateGeometry("prism radius must be positive") }
        let profile = (0..<sides).map { i -> Vec2 in
            let t = 2 * Double.pi * Double(i) / Double(sides)
            return Vec2(radius * cos(t), radius * sin(t))
        }
        return try Extrude.extrude(profile: profile, on: plane, distance: height)
    }
}
