import Foundation
import ForgeGeometry

/// A turntable camera in model space (Z-up). Pure math, no framework types,
/// so it is testable and reusable across RealityKit / Metal back ends.
public struct OrbitCamera: Hashable, Codable, Sendable {
    public var target: Vec3
    public var distance: Double
    /// Rotation about +Z, radians. 0 looks along −X... i.e. the eye sits on +X.
    public var azimuth: Double
    /// Elevation above the XY plane, radians, clamped to ±(π/2 − ε).
    public var elevation: Double
    /// Vertical field of view in degrees.
    public var fieldOfView: Double

    public var minDistance: Double = 1
    public var maxDistance: Double = 100_000

    private static let maxElevation = Double.pi / 2 - 0.01

    public init(
        target: Vec3 = .zero,
        distance: Double = 300,
        azimuth: Double = .pi / 4,
        elevation: Double = .pi / 6,
        fieldOfView: Double = 55
    ) {
        self.target = target
        self.distance = distance
        self.azimuth = azimuth
        self.elevation = elevation
        self.fieldOfView = fieldOfView
    }

    public var up: Vec3 { .unitZ }

    public var position: Vec3 {
        let ce = cos(elevation)
        return target + Vec3(ce * cos(azimuth), ce * sin(azimuth), sin(elevation)) * distance
    }

    public var forward: Vec3 { (target - position).normalized }
    public var right: Vec3 { forward.cross(up).normalized }
    /// Camera-space up (perpendicular to `forward`), as opposed to world `up`.
    public var trueUp: Vec3 { right.cross(forward) }

    public var viewMatrix: Transform {
        .lookAt(eye: position, target: target, up: up)
    }

    // MARK: Interaction

    public mutating func orbit(deltaAzimuth: Double, deltaElevation: Double) {
        azimuth = (azimuth + deltaAzimuth).truncatingRemainder(dividingBy: 2 * .pi)
        elevation = min(max(elevation + deltaElevation, -Self.maxElevation), Self.maxElevation)
    }

    /// Multiplies the distance; `factor < 1` zooms in.
    public mutating func dolly(factor: Double) {
        distance = min(max(distance * factor, minDistance), maxDistance)
    }

    /// Slides the target in the view plane. `dx`/`dy` are fractions of the
    /// visible height at the target, so drags feel the same at every zoom.
    public mutating func pan(dx: Double, dy: Double) {
        let visibleHeight = 2 * distance * tan(fieldOfView * .pi / 360)
        target += right * (-dx * visibleHeight) + trueUp * (-dy * visibleHeight)
    }

    /// Frames a bounding box with a little margin, keeping the current angles.
    public mutating func frame(_ box: BoundingBox, margin: Double = 1.15) {
        guard !box.isEmpty else { return }
        target = box.center
        let radius = max(box.radius, 1e-3)
        distance = min(max(radius * margin / sin(fieldOfView * .pi / 360), minDistance), maxDistance)
    }
}
