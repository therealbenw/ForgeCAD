# ForgeCAD — instructions for Claude Code sessions

## Every change is a pull request from its own worktree
- **Never commit to `main` and never edit files in the main checkout.** If you
  find yourself on `main` in the repository root, create a worktree first
  (EnterWorktree, named after the branch slug) before touching any file.
  Sessions started with `claude -w <name>` are already in one.
- Branch off `origin/main`. Names: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`,
  `ci/<slug>`. If the work depends on another open PR, base the branch on that
  PR's branch and say so at the top of the PR body.
- Commit messages: `module: what changed` (`kernel`, `sketch`, `document`,
  `render`, `io`, `app`, `tests`, `ci`, `docs`).
- When the work is done: push, `gh pr create` with **Why / What changed /
  Verify** sections, then `gh pr checks <n> --watch` and report the result.
  **Do not merge** — the user reviews and merges every PR.
- Plan before building: for anything beyond a small fix, lay out the design
  decisions and get them confirmed before writing code.

## Build and test
- `swift build` works with Command Line Tools. `swift test` and the iPad app
  need full Xcode; on a machine without it, CI is the gate — check **both**
  jobs (macOS package tests, iOS package + app build) before reporting green.
- Swift Testing gotcha: `#expect(...)` captures its expression immutably —
  hoist mutating calls into a `let` first.
- The app project is generated: `cd App && xcodegen generate`. Edit
  `App/project.yml`, never a `.xcodeproj`.

## Code rules (details in CONTRIBUTING.md and docs/ARCHITECTURE.md)
- `ForgeCore` modules are pure Swift, value types, `Sendable`, no UI or
  RealityKit imports. UI code lives only in `App/`.
- Tolerances go through `ForgeGeometry.Tolerance`; no bare `1e-6` literals.
- Output must be deterministic: iterate `sortedFaces` / `sortedEdges`.
- Regeneration never throws; feature failures become `FeatureError`s.
- Model space is millimetres, right-handed, Z-up.
- Geometry tests assert on measurable properties (volume, area, Euler
  characteristic, solver residual), not vertex order.
