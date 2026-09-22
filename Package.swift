// swift-tools-version: 6.0
import PackageDescription

// ForgeCore is the platform-independent heart of ForgeCAD: geometry, the
// B-rep kernel, sketching, the parametric document model, render buffers
// and file I/O. It has no UI or RealityKit dependency so it builds and tests
// on macOS with `swift build` / `swift test`. The iPad app in App/ is a thin
// SwiftUI + RealityKit layer on top of these modules.
let package = Package(
    name: "ForgeCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ForgeGeometry", targets: ["ForgeGeometry"]),
        .library(name: "ForgeKernel", targets: ["ForgeKernel"]),
        .library(name: "ForgeSketch", targets: ["ForgeSketch"]),
        .library(name: "ForgeDocument", targets: ["ForgeDocument"]),
        .library(name: "ForgeRender", targets: ["ForgeRender"]),
        .library(name: "ForgeIO", targets: ["ForgeIO"]),
    ],
    targets: [
        // Math primitives: vectors, planes, rays, boxes, transforms, 2D polygons.
        .target(name: "ForgeGeometry"),
        // Boundary-representation topology, solid construction, tessellation.
        .target(name: "ForgeKernel", dependencies: ["ForgeGeometry"]),
        // 2D sketch entities, constraints and the constraint solver.
        .target(name: "ForgeSketch", dependencies: ["ForgeGeometry"]),
        // Parametric feature tree, regeneration, undo.
        .target(name: "ForgeDocument", dependencies: ["ForgeGeometry", "ForgeKernel", "ForgeSketch"]),
        // GPU-ready mesh buffers and camera math (no RealityKit here).
        .target(name: "ForgeRender", dependencies: ["ForgeGeometry", "ForgeKernel"]),
        // STL / OBJ export and the native .forge document format.
        .target(name: "ForgeIO", dependencies: ["ForgeGeometry", "ForgeKernel", "ForgeDocument"]),

        .testTarget(name: "ForgeGeometryTests", dependencies: ["ForgeGeometry"]),
        .testTarget(name: "ForgeKernelTests", dependencies: ["ForgeKernel"]),
        .testTarget(name: "ForgeSketchTests", dependencies: ["ForgeSketch"]),
        .testTarget(name: "ForgeDocumentTests", dependencies: ["ForgeDocument", "ForgeKernel"]),
        .testTarget(name: "ForgeIOTests", dependencies: ["ForgeIO", "ForgeKernel"]),
    ]
)
