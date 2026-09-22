# Contributing

## Ground rules

- Kernel and sketch code is **pure Swift, value types, `Sendable`**, no UI
  frameworks. If it needs RealityKit or UIKit it belongs in `App/`.
- Every geometry change ships with a test that asserts on measurable
  properties (volume, area, Euler characteristic, residual) rather than on
  exact vertex order.
- Keep the tolerance policy centralised in `ForgeGeometry.Tolerance`. Don't
  sprinkle `1e-6` literals.
- Output must be deterministic: iterate `sortedFaces` / `sortedEdges`, never
  raw dictionary order.
- Regeneration must not throw. Wrap feature failures in `FeatureError`.

## Workflow

```sh
swift build                 # host build of ForgeCore
swift test                  # needs Xcode (Swift Testing), not just Command Line Tools
cd App && xcodegen generate # regenerate the app project after touching project.yml
```

Branch from `main`, open a PR, CI must be green. Squash-merge with a message in
the form `module: what changed` (e.g. `kernel: tessellate cylindrical faces`).

## Adding a feature type

1. Add a case to `Feature` (`Sources/ForgeDocument/Feature.swift`) with its
   own `Codable` struct.
2. Handle it in `Regenerator.regenerate` and record failures as `FeatureError`.
3. Add an icon in `FeatureTreeView.icon(for:)`.
4. Bump `Document.currentFormatVersion` only if existing files can no longer
   decode; add a migration in `ForgeFileFormat.decode`.
