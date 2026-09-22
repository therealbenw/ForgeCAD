# Architecture

ForgeCAD is split into a platform-independent Swift package (**ForgeCore**)
and a thin iPad app. The package has no UI or RealityKit dependency, so the
whole modeling stack builds and tests on a Mac with `swift test`, and could be
reused on macOS or visionOS later.

```
 App/ForgeCAD (SwiftUI + RealityKit)
 ┌──────────────────────────────────────────────────────────────┐
 │  ContentView ── FeatureTreeView ── ViewportView (RealityView) │
 │                     DocumentStore (@Observable, undo)          │
 └──────────────────────────────┬───────────────────────────────┘
                                │ RenderMesh → MeshResource
 ForgeCore (Swift package)      ▼
 ┌────────────┐  ┌────────────┐  ┌────────────┐
 │ ForgeIO    │  │ ForgeRender│  │ForgeDocument│  feature tree, Regenerator, UndoStack
 │ STL/OBJ/   │  │ RenderMesh │  │            │
 │ .forge     │  │ OrbitCamera│  └─────┬──────┘
 └─────┬──────┘  └─────┬──────┘        │
       │               │        ┌──────┴──────┐
       │               │        │ ForgeSketch │  entities, constraints, solver, profiles
       │               │        └──────┬──────┘
       └───────┬───────┴───────────────┘
        ┌──────┴──────┐
        │ ForgeKernel │  B-rep topology, SolidBuilder, Extrude, Tessellator, Measure, Boolean
        └──────┬──────┘
        ┌──────┴──────┐
        │ForgeGeometry│  Vec2/Vec3, Plane, Ray, BoundingBox, Transform, Polygon2D, Tolerance
        └─────────────┘
```

## Data flow

1. The user edits the **Document** (a value type holding an ordered list of
   `Feature`s). Every edit is committed through `DocumentStore.commit`, which
   snapshots into the `UndoStack`.
2. `Regenerator.regenerate` replays the feature history:
   - `Sketch` features are solved by `RelaxationSolver`.
   - `Extrude` features pull closed profiles from the solved sketch
     (`Sketch.worldProfiles()`) and call `Extrude.extrude` to build a `Solid`.
   - Failures are recorded per feature; regeneration never throws.
3. Each `Solid` is tessellated to a `Mesh` (flat-shaded triangles) and
   converted to a `RenderMesh` (Float buffers).
4. `ViewportView` turns `RenderMesh`es into RealityKit `MeshResource`s and
   places them under a root entity that rotates Z-up model space into
   RealityKit's Y-up scene.

Geometry is never persisted — a `.forge` file is just the feature history as
JSON (`ForgeFileFormat`). Exports (STL/OBJ) are produced from the tessellation.

## Conventions

- **Units**: model space is millimetres. `Document.displayUnit` only affects
  formatting and input parsing.
- **Handedness**: model space is right-handed, **Z-up**. Sketch planes carry an
  explicit `(u, v, normal)` frame that is also right-handed, so a
  counter-clockwise profile in (u, v) has its normal along `plane.normal`.
- **Tolerances** live in one place (`Tolerance`). Numeric noise uses `linear`
  (1e-9 mm); merging user-authored vertices uses `modeling` (1e-6 mm).
- **Identifiers**: kernel entities use small integer ids local to a `Solid`;
  document features use `UUID`s so references survive reordering and file
  round-trips.
- **Determinism**: anything that produces output (tessellation, export)
  iterates `Solid.sortedFaces`, never raw dictionary order.
- **Value semantics everywhere**: `Solid`, `Sketch`, `Document` are structs.
  Undo is a snapshot stack; concurrency is trivially safe (`Sendable`).

## Module boundaries

| Module          | May import                             | Must not know about        |
|-----------------|----------------------------------------|----------------------------|
| ForgeGeometry   | simd, Foundation                       | anything else              |
| ForgeKernel     | ForgeGeometry                          | sketches, documents, UI    |
| ForgeSketch     | ForgeGeometry                          | solids                     |
| ForgeDocument   | Geometry, Kernel, Sketch               | rendering, files, UI       |
| ForgeRender     | Geometry, Kernel                       | RealityKit, documents      |
| ForgeIO         | Geometry, Kernel, Document             | UI                         |
| App             | everything + SwiftUI + RealityKit      | kernel internals           |

## Kernel design notes

- `Solid` is a single closed shell of `Face`s bounded by `Loop`s of
  `OrientedEdge`s referencing shared `Edge`s and `Vertex`es (a classic B-rep,
  minus half-edge pointers). `SolidBuilder` merges coincident vertices and
  shared line edges so topology is genuinely connected — a box has 8/12/6.
- Curved geometry is represented (`Curve3D.arc`, `Surface3D.cylinder`) but not
  yet tessellated or produced by any feature; that is milestone M2.
- Booleans (`Boolean.apply`) throw `notImplemented` today. The document layer
  already routes `join`/`cut`/`intersect` through it so the UI can be built
  against the final API.
- Tessellation is per-face ear clipping of the planar outer loop. Holes are
  declared in the topology but rejected by the tessellator until M2.

## Sketch solver

`RelaxationSolver` reduces every constraint to a residual vector between two
points and iteratively projects it out, splitting the correction unless a
point is `fixed`. It is deliberately simple and converges fast for
well-determined sketches. Milestone M4 replaces it with a Jacobian-based
Gauss-Newton / Levenberg-Marquardt solver that handles tangency, equal-length,
angles and over/under-constrained diagnostics.

## Testing strategy

- Every module has a Swift Testing target. Kernel tests assert on **mass
  properties** (volume via the divergence theorem, surface area) and **Euler
  characteristic**, which catch winding, orientation and topology bugs without
  brittle vertex-order assertions.
- Document tests exercise regeneration end-to-end (sketch → extrude → volume)
  and confirm that a broken feature is reported, not fatal.
- CI (`.github/workflows/ci.yml`) runs the package on macOS and builds both the
  package and the XcodeGen-generated app for the iOS Simulator.
