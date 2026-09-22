import ForgeGeometry
import ForgeKernel

/// Single-precision, GPU-ready copy of a kernel `Mesh`. The app turns this
/// into a RealityKit `MeshResource`; keeping the conversion here means the
/// kernel never has to know about RealityKit.
public struct RenderMesh: Hashable, Sendable {
    public var positions: [SIMD3<Float>]
    public var normals: [SIMD3<Float>]
    public var indices: [UInt32]

    public init(positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []) {
        self.positions = positions
        self.normals = normals
        self.indices = indices
    }

    public init(_ mesh: Mesh) {
        positions = mesh.positions.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
        normals = mesh.normals.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
        indices = mesh.indices
    }

    public var isEmpty: Bool { indices.isEmpty }
    public var triangleCount: Int { indices.count / 3 }

    public var boundingBox: BoundingBox {
        BoundingBox(points: positions.map { Vec3(Double($0.x), Double($0.y), Double($0.z)) })
    }
}

/// Model space is Z-up; RealityKit is Y-up. Rotating −90° about X maps
/// model +Z to scene +Y and model +Y to scene −Z.
public enum SceneConventions {
    public static let modelToScene = Transform.rotation(axis: .unitX, angle: -.pi / 2)
    public static let sceneToModel = Transform.rotation(axis: .unitX, angle: .pi / 2)
}
