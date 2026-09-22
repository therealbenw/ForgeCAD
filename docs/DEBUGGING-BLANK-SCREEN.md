# Triage: the iPad app launches to a blank white screen

The ForgeCAD app builds cleanly and runs, but shows **the status bar over an
all-white screen** — no navigation bar, no sidebar, no toolbar, and no crash.

The expected UI on `main` is a `NavigationSplitView`: a "No features yet"
sidebar and a dark viewport with a 10 mm grid, plus Undo / Redo / Add box in
the toolbar.

This document is a self-contained triage runbook. It is written for someone
picking up the repository on a Mac with **full Xcode installed** — the primary
dev machine has Command Line Tools only and cannot build or run the app at all,
which is why the diagnosis has to happen elsewhere.

**No fixes until the cause is isolated.** The bisect edits in Phase 3 are
one-line, throwaway probes, reverted immediately. They are not the fix.

## Running this with Claude Code

From the repository root:

```sh
claude "read docs/DEBUGGING-BLANK-SCREEN.md and walk me through Setup, Phase 0 and Phase 1"
```

Claude can run every shell command and read every file here, but it cannot
drive Xcode's GUI. Capturing the view hierarchy, pausing the debugger and
reading Thread 1 are yours — paste the results back and Claude takes it from
there.

---

## What is already established — don't re-test it

| Fact | Evidence |
|---|---|
| The build is sound | CI run `35675031258` on `main` @ `72ccba3`: *ForgeCore + app (iOS Simulator)* ✅ and *ForgeCore (macOS host)* ✅ |
| `main` is the **pre-`DocumentGroup`** app | `ForgeCADApp` is a plain `WindowGroup { ContentView().environment(store) }`; `ContentView.swift` and `DocumentStore.swift` are both present |
| So there should be **no document browser** | The document-based rewrite lives on `feat/document-group`, which is not merged |
| The process is alive and didn't crash | The status bar is drawn; a dead app drops to the home screen and detaches the debugger |
| A missing `App/ForgeCAD/Info.plist` is **not** the bug | `App/project.yml` declares `info.path` + `properties`, so XcodeGen writes that file at generate time. It is absent from a fresh clone by design |
| The viewport has **no simulator guard** | There is no `#if targetEnvironment(simulator)` anywhere in `App/ForgeCAD/`; `ViewportView` builds a `RealityView` unconditionally and sets `content.camera = .virtual` |

## The two shapes of this failure

`UILaunchScreen: {}` in `App/project.yml` produces exactly what you're seeing:
the status bar over a white system background. So either:

- **(A) Stuck on the launch screen** — the app never presented its first frame.
  The cause is at startup: a blocked main thread, or a scene that never
  materialises.
- **(B) The SwiftUI tree is up but painting white** — `NavigationSplitView`,
  `FeatureTreeView` or `RealityView` is rendering nothing.

Phase 1 decides which in about two minutes. Everything after that hangs off the
answer.

---

## Setup — from a fresh clone (10 min)

```sh
git clone https://github.com/therealbenw/ForgeCAD.git
cd ForgeCAD
git checkout main

brew install xcodegen          # if you don't have it
cd App && xcodegen generate
open ForgeCAD.xcodeproj
```

The `.xcodeproj` is gitignored and generated from `App/project.yml` — edit the
YAML, never the project file, or your change is overwritten on the next
`xcodegen generate`.

Select the **ForgeCAD** scheme and an **iPad** simulator (the target is iPad
only: `TARGETED_DEVICE_FAMILY: "2"`), then Run.

---

## Phase 0 — capture the facts (5 min, no changes)

```sh
git branch --show-current && git log --oneline -3
xcodebuild -version
xcrun simctl list devices booted
```

Expected: branch `main` at `72ccba3`.

> If you're on `feat/document-group` instead, you're testing a different app
> (document browser first). The tree below still applies, but the Phase 3 file
> names become `PartEditorView.swift` / `PartSession.swift`.

Note the Xcode version and the **simulator's iOS version**. An iOS 26 simulator
running a project pinned to `xcodeVersion: "16.0"` with an iOS 18 deployment
target is worth knowing about before we blame the code.

---

## Phase 1 — launch screen, or view tree? (decisive)

### 1.1 Capture the view hierarchy

With the white screen showing: **Debug ▸ View Debugging ▸ Capture View Hierarchy**.

| What you see | Conclusion | Go to |
|---|---|---|
| `_UIHostingView` with real subviews (`UINavigationBar`, split-view containers) | The view tree is up and painting white → **(B)** | Phase 3 |
| Only a `UIWindow` + a bare `UIView`, no hosting view | First frame never presented → **(A)** | Phase 2 |
| Capture fails or hangs | Main thread is blocked → **(A)** | 1.2, then Phase 2 |

### 1.2 Pause and read the main thread

Hit pause in Xcode's debug bar and look at **Thread 1**:

- Blocked in `RealityKit`, `Metal`, `MTLCreateSystemDefaultDevice`,
  `semaphore_wait` or `dispatch_sync` → a startup deadlock, almost certainly
  the renderer. Screenshot the stack.
- Sitting in `__CFRunLoopRun` / `mach_msg2_trap` → **not** blocked. The app is
  idle and simply has nothing to draw → shape **(B)**.

### 1.3 Stream the app's own log

```sh
xcrun simctl terminate booted com.therealbenw.ForgeCAD 2>/dev/null
xcrun simctl launch --console-pty booted com.therealbenw.ForgeCAD
```

and, in a second terminal, the system side:

```sh
xcrun simctl spawn booted log stream --level debug \
  --predicate 'processImagePath CONTAINS "ForgeCAD" OR senderImagePath CONTAINS "RealityKit"'
```

Keep anything mentioning `RealityKit`, `CoreRE`, `Metal`, `AGX`, `MTLDevice`,
`Compiler failed`, `NSInternalInconsistencyException` or `Invalid UTType`.

**Deliverable from Phase 1:** shape (A) or (B), the Thread 1 stack if you paused
it, and any log lines. That alone probably names the culprit.

---

## Phase 2 — startup path (shape A only)

### 2.1 Run on a physical iPad — the single most informative test

RealityKit is the one component in this app that behaves differently in the
simulator. If an iPad and a signing identity are available, this test is worth
more than everything else in this phase combined.

1. Connect the iPad, unlock it, trust the Mac.
2. Xcode ▸ target `ForgeCAD` ▸ **Signing & Capabilities** ▸ set Team to your
   Apple ID. If provisioning complains the bundle id is taken, change
   `PRODUCT_BUNDLE_IDENTIFIER` in `App/project.yml` (e.g. append `.dev`) and
   run `xcodegen generate` again.
3. On the iPad: Settings ▸ General ▸ VPN & Device Management ▸ trust the cert.
4. Select the iPad as destination and Run.

| Result | Conclusion |
|---|---|
| **Works on device, white in simulator** | RealityKit-in-simulator. Not a code bug → Phase 5, "simulator fallback" |
| **White on both** | A real defect in our code or config → 2.2 |

### 2.2 Verify what actually got installed

```sh
APP=$(xcrun simctl get_app_container booted com.therealbenw.ForgeCAD)
plutil -p "$APP/Info.plist" | grep -Ei 'launch|scene|device|bundleid|storyboard'
ls "$APP/Frameworks" 2>/dev/null
```

Check that `UILaunchScreen` is present, `UIDeviceFamily = [2]`, there is **no**
`UISceneStoryboardFile` / `UIMainStoryboardFile` (a stray storyboard reference
with no storyboard is a classic permanent-launch-screen bug), and that the
`Forge*` libraries are linked — either in `Frameworks/` or statically merged.

### 2.3 Clean-room rebuild — rules out stale artefacts

```sh
rm -rf ~/Library/Developer/Xcode/DerivedData/ForgeCAD-*
cd App && rm -rf ForgeCAD.xcodeproj && xcodegen generate
```

In the Simulator: Device ▸ Erase All Content and Settings. Then Run again. A
wedged simulator GPU context is a real and common cause of blank Metal apps.

### 2.4 Scene probe

In `App/ForgeCAD/ForgeCADApp.swift`, temporarily replace the window body:

```swift
WindowGroup {
    Text("scene ok")          // was: ContentView().environment(store)
}
```

| Result | Conclusion |
|---|---|
| "scene ok" appears | Scene, Info.plist and launch path are fine; the fault is inside `ContentView` → Phase 3 |
| Still white | The scene itself never presents — config or bundle level. Re-check 2.2, then try a brand-new empty Xcode iPad app on the same simulator to see whether *anything* renders |

Revert this edit before moving on.

---

## Phase 3 — bisect the view tree (shape B)

One edit at a time: run, observe, **revert**. The file is
`App/ForgeCAD/ContentView.swift`.

### 3.1 Is it the viewport?

```swift
} detail: {
    Color.red                  // was: ViewportView()
        .ignoresSafeArea()
        .toolbar { toolbarContent }
}
```

- **Red + sidebar + toolbar** → `RealityView` is the culprit → Phase 5.
- **Still white** → the problem is above the viewport → 3.2.

### 3.2 Is it the sidebar?

Keep `Color.red` in detail, and:

```swift
NavigationSplitView {
    Text("sidebar")            // was: FeatureTreeView()
}
```

- **Renders now** → `FeatureTreeView` is at fault. Likeliest suspects, in order:
  `@Environment(DocumentStore.self)` resolving to nothing, the
  `ContentUnavailableView` overlay, or `List(selection:)` with `@Bindable`.
- **Still white** → 3.3.

### 3.3 Is it `NavigationSplitView` itself?

```swift
var body: some View {
    VStack { Text(store.document.name) }   // whole NavigationSplitView replaced
}
```

- **Renders** → `NavigationSplitView` isn't laying out on this iOS version. Test
  the fix: add `.navigationSplitViewStyle(.balanced)` and a
  `@State var columnVisibility: NavigationSplitViewVisibility = .all` passed to
  `NavigationSplitView(columnVisibility:)`.
- **Still white** → the `DocumentStore` environment object never arrives. Check
  that `.environment(store)` in `ForgeCADApp` is still attached, and that
  `DocumentStore.init` isn't hanging — put a `print` at the top and bottom of
  `init` and of `regenerate()`. If only the first prints, regeneration is
  looping, which would also explain a blocked main thread in 1.2.

---

## Phase 4 — instrument startup (if nothing above is conclusive)

Add temporary prints and read them with `simctl launch --console-pty`:

| Where | Line |
|---|---|
| `ForgeCADApp.body` | `let _ = print("APP body")` |
| `DocumentStore.init`, first + last line | `print("store init in/out")` |
| `DocumentStore.regenerate()`, first + last line | `print("regen in/out")` |
| `ContentView.body` | `let _ = print("CV body")` |
| `ViewportView.body` | `let _ = print("VP body")` |
| `RealityView`'s `make` closure, first + last line | `print("make in/out")` |

The last line printed names the stage that hangs. `store init in` with no
`store init out` means `Regenerator.regenerate` is spinning on an empty
document — a kernel bug, and the one scenario here that isn't about the UI at
all.

---

## Phase 5 — likely fixes, by cause

| Cause | Fix |
|---|---|
| RealityKit unusable in simulator | Wrap the viewport: `#if targetEnvironment(simulator)` show a placeholder (or a simple SwiftUI `Canvas` wireframe) `#else` `RealityView` `#endif`. Develop the 3D path on device |
| RealityKit fails only at `content.camera = .virtual` | Drop the virtual-camera line and rely on the default camera plus the explicit `PerspectiveCamera`; verify with a single `MeshResource.generateBox` before re-enabling the grid |
| Grid mesh generation fails | `makeGrid` swallows failure with `try?`. Make it `do`/`catch` + `print`, and shrink to `extent: 50, step: 10` to test |
| `NavigationSplitView` not laying out | Explicit `columnVisibility` + `.navigationSplitViewStyle(.balanced)` |
| Stale project or wedged simulator | Regenerate the project, erase the simulator, clear DerivedData (2.3) |
| Newer simulator vs iOS 18 deployment target | Bump `options.xcodeVersion` in `App/project.yml`, test against an iPad simulator running iOS 18.x |

Whatever the fix, it belongs in `App/ForgeCAD/*` or `App/project.yml`, plus a
line in `CONTRIBUTING.md` recording the trap (e.g. "the 3D viewport needs a
physical iPad; the simulator shows a placeholder") so it isn't rediscovered.

Land it as a pull request — see `CLAUDE.md`. Never commit to `main`.

---

## Verification

1. Launch on the **iPad simulator**: the sidebar reads "No features yet", the
   viewport is dark with a grid, the toolbar shows Undo / Redo / Add box.
2. Tap **Add box** → "Base sketch" and "Base extrude" appear in the tree, a grey
   solid frames itself in the viewport, **Export STL** appears.
3. Drag to orbit, pinch to zoom.
4. Undo → the box disappears. Redo → it returns.
5. Repeat 1–4 on a **physical iPad** — the real target, and the only place the
   RealityKit path is truly exercised.
6. CI stays green (`gh pr checks <n> --watch`): both the macOS package job and
   the iOS Simulator app build.

---

## What to send back after Phase 1

- Shape **(A)** or **(B)**, and the Thread 1 stack if you paused it
- Any `RealityKit` / `Metal` / `CoreRE` lines from the log stream
- `git branch --show-current`, `xcodebuild -version`, the simulator's iOS version
- Whether the app runs correctly on a physical iPad

That set is enough to skip straight to the fix.
