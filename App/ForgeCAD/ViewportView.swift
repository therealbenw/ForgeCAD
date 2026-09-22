import SwiftUI
import RealityKit
import ForgeGeometry
import ForgeRender

/// The 3D canvas. Model geometry lives under a root entity that rotates
/// ForgeCAD's Z-up model space into RealityKit's Y-up scene space; the camera
/// is a child of that same root so `OrbitCamera` math stays in model space.
struct ViewportView: View {
    @Environment(PartSession.self) private var session
    @State private var camera = OrbitCamera()
    @State private var lastDrag: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1

    private static let rootName = "forge.root"
    private static let cameraName = "forge.camera"
    private static let modelName = "forge.model"

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            RevisionComponent.registerComponent()

            let root = Entity()
            root.name = Self.rootName
            root.transform = RealityKit.Transform(matrix: Self.float4x4(SceneConventions.modelToScene.matrix))
            content.add(root)

            let model = Entity()
            model.name = Self.modelName
            root.addChild(model)

            let cam = PerspectiveCamera()
            cam.name = Self.cameraName
            root.addChild(cam)

            let key = DirectionalLight()
            key.light.intensity = 2500
            key.orientation = simd_quatf(angle: -.pi / 3, axis: [1, 0.3, 0])
            content.add(key)

            let fill = DirectionalLight()
            fill.light.intensity = 900
            fill.orientation = simd_quatf(angle: .pi / 2.5, axis: [1, -0.6, 0])
            content.add(fill)

            model.addChild(Self.makeGrid())
            rebuildModel(in: model)
            apply(camera, to: cam)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == Self.rootName }) else { return }
            if let model = root.findEntity(named: Self.modelName) {
                rebuildModel(in: model)
            }
            if let cam = root.findEntity(named: Self.cameraName) as? PerspectiveCamera {
                apply(camera, to: cam)
            }
        }
        .background(Color(white: 0.12))
        .gesture(orbitGesture)
        .simultaneousGesture(zoomGesture)
        .onChange(of: session.revision, initial: true) { _, _ in
            frameModel()
        }
    }

    // MARK: Gestures

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let dx = value.translation.width - lastDrag.width
                let dy = value.translation.height - lastDrag.height
                lastDrag = value.translation
                camera.orbit(deltaAzimuth: -Double(dx) * 0.008, deltaElevation: Double(dy) * 0.008)
            }
            .onEnded { _ in lastDrag = .zero }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let step = value.magnification / lastMagnification
                lastMagnification = value.magnification
                camera.dolly(factor: 1 / Double(step))
            }
            .onEnded { _ in lastMagnification = 1 }
    }

    // MARK: Scene assembly

    /// Records which document revision an entity's meshes reflect.
    private struct RevisionComponent: Component {
        var revision: Int
    }

    private func rebuildModel(in model: Entity) {
        if model.components[RevisionComponent.self]?.revision == session.revision { return }
        model.components.set(RevisionComponent(revision: session.revision))

        for child in model.children where child.name.hasPrefix("body.") {
            child.removeFromParent()
        }

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1))
        material.roughness = 0.55
        material.metallic = 0.1

        for (index, mesh) in session.renderMeshes.enumerated() {
            guard let resource = try? MeshResource.make(from: mesh) else { continue }
            let entity = ModelEntity(mesh: resource, materials: [material])
            entity.name = "body.\(index)"
            model.addChild(entity)
        }
    }

    private func apply(_ camera: OrbitCamera, to entity: PerspectiveCamera) {
        entity.camera.fieldOfViewInDegrees = Float(camera.fieldOfView)
        entity.camera.near = 0.1
        entity.camera.far = 100_000
        entity.look(
            at: SIMD3<Float>(camera.target),
            from: SIMD3<Float>(camera.position),
            upVector: SIMD3<Float>(camera.up),
            relativeTo: entity.parent
        )
    }

    private func frameModel() {
        let box = session.renderMeshes.reduce(ForgeGeometry.BoundingBox.empty) { $0.union($1.boundingBox) }
        if box.isEmpty {
            camera = OrbitCamera()
        } else {
            camera.frame(box)
        }
    }

    private static func float4x4(_ m: simd_double4x4) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(m.columns.0),
            SIMD4<Float>(m.columns.1),
            SIMD4<Float>(m.columns.2),
            SIMD4<Float>(m.columns.3)
        ))
    }

    /// A 10 mm grid on the XY plane, drawn as thin quads (RealityKit meshes
    /// have no line primitive), so the empty scene still reads as a workspace.
    private static func makeGrid(extent: Float = 200, step: Float = 10, width: Float = 0.15) -> Entity {
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        func addLine(_ a: SIMD3<Float>, _ b: SIMD3<Float>) {
            let dir = simd_normalize(b - a)
            let side = SIMD3<Float>(-dir.y, dir.x, 0) * (width / 2)
            let base = UInt32(positions.count)
            positions += [a - side, a + side, b + side, b - side]
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }

        var i: Float = -extent
        while i <= extent {
            addLine([i, -extent, 0], [i, extent, 0])
            addLine([-extent, i, 0], [extent, i, 0])
            i += step
        }

        var descriptor = MeshDescriptor(name: "grid")
        descriptor.positions = MeshBuffer(positions)
        descriptor.primitives = .triangles(indices)

        let entity = Entity()
        entity.name = "grid"
        if let mesh = try? MeshResource.generate(from: [descriptor]) {
            let material = UnlitMaterial(color: UIColor(white: 0.32, alpha: 1))
            entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        }
        return entity
    }
}

extension MeshResource {
    /// Builds a flat-shaded RealityKit mesh from a kernel-produced `RenderMesh`.
    static func make(from mesh: RenderMesh) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: "body")
        descriptor.positions = MeshBuffer(mesh.positions)
        descriptor.normals = MeshBuffer(mesh.normals)
        descriptor.primitives = .triangles(mesh.indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
