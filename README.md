# ForgeCAD

Parametric solid modeling for iPad, built on a custom Swift B-rep kernel and
rendered with SwiftUI + RealityKit.

[![CI](https://github.com/therealbenw/ForgeCAD/actions/workflows/ci.yml/badge.svg)](https://github.com/therealbenw/ForgeCAD/actions/workflows/ci.yml)

> **Status: M0 skeleton.** The modeling stack (sketch → constraints → extrude →
> B-rep → tessellation → STL) works end-to-end and is tested; the app shows a
> feature tree, an orbitable 3D viewport, opens and saves `.forge` parts
> through the system document browser, and can insert and export a sample
> box. See [docs/ROADMAP.md](docs/ROADMAP.md) for what comes next.

## Layout

```
ForgeCAD/
├── Package.swift          ForgeCore — the platform-independent modeling stack
├── Sources/
│   ├── ForgeGeometry/     vectors, planes, transforms, 2D polygons, tolerances
│   ├── ForgeKernel/       B-rep topology, SolidBuilder, Extrude, Tessellator, Measure
│   ├── ForgeSketch/       sketch entities, constraints, solver, profile extraction
│   ├── ForgeDocument/     feature tree, Regenerator
│   ├── ForgeRender/       RenderMesh (GPU buffers), OrbitCamera
│   └── ForgeIO/           STL / OBJ export, .forge document format
├── Tests/                 Swift Testing suites, one per module
├── App/
│   ├── project.yml        XcodeGen spec for the iPad app
│   └── ForgeCAD/          SwiftUI + RealityKit app: DocumentGroup, PartSession, viewport
└── docs/                  ARCHITECTURE.md, ROADMAP.md
```

## Getting started

### Requirements

- Xcode 16.2 or newer (iOS 18 SDK, Swift 6). The Command Line Tools alone can
  `swift build` the package but cannot run the tests or build the app.
- An iPad running iPadOS 18+ (or the simulator).
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`.

### Build & test the modeling stack

```sh
swift build
swift test
```

### Run the app

Option A — generate the project (recommended, keeps `.xcodeproj` out of git):

```sh
cd App
xcodegen generate
open ForgeCAD.xcodeproj
```

Option B — by hand in Xcode:

1. File ▸ New ▸ Project ▸ iOS App, product name `ForgeCAD`, SwiftUI, Swift.
   Save it inside `App/`.
2. Delete the template `ContentView.swift`/`ForgeCADApp.swift` and add the
   files from `App/ForgeCAD/` to the target.
3. File ▸ Add Package Dependencies ▸ Add Local… ▸ pick the repository root
   and add all six `Forge*` products to the app target.
4. Set deployment target to iOS 18.0, device family to iPad.

Then pick an iPad destination and run. ForgeCAD is a document-based app: the
system document browser opens first — tap **Create Document** to start a new
`.forge` part (or open an existing one from Files/iCloud). Tap **Add box** to
create a sketch + extrude, drag to orbit, pinch to zoom, undo with the toolbar,
⌘Z or three-finger swipe, and use the share button to export STL. Parts
autosave; reopening a `.forge` file regenerates its feature history.

### Quick tour in code

```swift
import ForgeSketch, ForgeDocument, ForgeKernel, ForgeIO

var doc = Document(name: "Block")
let sketch = doc.addSketch(Sketch.rectangle(corner: .zero, width: 20, height: 10))
doc.addExtrude(of: sketch, extent: .blind(5))

let result = Regenerator.regenerate(doc)
let solid = result.bodies[0].solid                 // 8 vertices, 12 edges, 6 faces
try Measure.volume(of: solid)                      // 1000.0
let stl = STLWriter.binaryData(try Tessellator.tessellate(solid))
```

## Design in one paragraph

Everything the user makes is a **feature history** (`Document`), never stored
geometry. Regeneration replays it: sketches are solved, profiles extruded into
**B-rep solids** with shared topology, solids tessellated into flat-shaded
meshes, meshes handed to RealityKit. Model space is millimetres, right-handed,
Z-up; the viewport rotates into RealityKit's Y-up. All core types are value
types and `Sendable`, so undo is a snapshot swap registered with the system
`UndoManager` and there is no shared mutable state to guard. Details in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Issues and PRs welcome — the roadmap
lists the concrete next steps, and M1 (sketching on iPad) and M2 (curved
faces) are good places to start.

## License

MIT — see [LICENSE](LICENSE).
