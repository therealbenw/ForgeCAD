# Roadmap

Milestones are ordered so that each one ships something a user can touch.
Boxes are unchecked until merged to `main` with tests.

## M0 — Skeleton ✅ (this commit)

- [x] Package layout, CI, docs
- [x] Geometry primitives with tolerance policy
- [x] B-rep topology + `SolidBuilder` with vertex/edge merging
- [x] Planar extrude with outward-normal guarantees, ear-clip tessellation
- [x] Sketch entities, H/V/coincident/fixed/distance constraints, relaxation solver
- [x] Closed-profile extraction (lines + circles)
- [x] Feature tree (`sketch`, `extrude`), regeneration with per-feature errors, undo
- [x] STL / OBJ export, `.forge` JSON format
- [x] iPad app shell: feature tree, RealityKit viewport, orbit/zoom, sample box, STL share

## M1 — Sketch on glass

Make sketching real on iPad before adding kernel depth.

- [ ] 2D sketch canvas (Canvas/Metal overlay) with Apple Pencil input
- [ ] Line / rectangle / circle tools with snapping to points, midpoints, grid
- [ ] Constraint inference while drawing (auto H/V, coincident on snap)
- [ ] Dimension editing with a numeric keypad; live re-solve
- [ ] Sketch plane picker (XY / XZ / YZ / planar face)
- [ ] Edit an existing sketch feature from the tree

## M2 — Curved geometry

- [ ] Arcs in sketch profiles (`Curve3D.arc` edges in extrude)
- [ ] Cylindrical faces from extruded arcs/circles; tessellation by chord/angular tolerance
- [ ] Faces with holes (bridge holes into outer loop for triangulation)
- [ ] Revolve feature
- [ ] Face/edge picking in the viewport (ray-cast against tessellation → face id)

## M3 — Booleans

The hard part. Plan: BSP-free face-face intersection on B-rep with robust
predicates, restricted to planar + cylindrical surfaces first.

- [ ] Face–face intersection curves (plane/plane, plane/cylinder, cylinder/cylinder)
- [ ] Edge splitting, loop reconstruction, inside/outside classification
- [ ] `union` / `subtract` / `intersect` wired to `join` / `cut` / `intersect` operations
- [ ] Fuzz tests: random boxes/prisms, verify volume identities
  (`vol(A∪B) = vol(A) + vol(B) − vol(A∩B)`) and Euler characteristic

## M4 — Real constraint solver

- [ ] Gauss-Newton / Levenberg-Marquardt over the constraint Jacobian
- [ ] Tangent, perpendicular, parallel, equal, angle, midpoint, symmetric constraints
- [ ] Degrees-of-freedom reporting; highlight over/under-constrained entities
- [ ] Drag-to-solve: move a point, everything else follows

## M5 — Polish the part workflow

- [ ] Fillet / chamfer on planar edges
- [ ] Shell, pattern (linear/circular), mirror
- [ ] Feature editing: reorder, suppress, roll back the history marker
- [ ] Document browser (`DocumentGroup`), iCloud, `.forge` open/save
- [ ] Measure tool, section view, appearance/material per body

## M6 — Interchange & platform

- [ ] STEP export (write AP214 for planar/cylindrical B-rep) — a big lift; consider
      bridging to an external kernel only for I/O if it proves too large
- [ ] USDZ export for Quick Look / AR
- [ ] 3MF export
- [ ] macOS Catalyst / native macOS target from the same package
- [ ] visionOS exploration (RealityKit is already the render path)

## Explicit non-goals (for now)

- Surface modeling (NURBS, lofts, sweeps)
- Assemblies and mates
- Simulation, CAM, drawings
