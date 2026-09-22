import Foundation
import Observation
import ForgeGeometry
import ForgeKernel
import ForgeSketch
import ForgeDocument
import ForgeRender
import ForgeIO

/// The app's single source of truth: the document, its undo history, and the
/// geometry regenerated from it. Every edit goes through `commit` so undo and
/// regeneration stay in sync.
@MainActor
@Observable
final class DocumentStore {
    private(set) var history: UndoStack<Document>
    private(set) var result = RegenerationResult()
    private(set) var renderMeshes: [RenderMesh] = []
    /// Bumped on every regeneration so the viewport knows when to rebuild.
    private(set) var revision = 0
    var selectedFeature: FeatureID?

    var document: Document { history.present }
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    init(document: Document = Document(name: "Untitled")) {
        history = UndoStack(document)
        regenerate()
    }

    // MARK: Editing

    func commit(_ edit: (inout Document) -> Void) {
        var copy = document
        edit(&copy)
        history.commit(copy)
        regenerate()
    }

    func undo() {
        if history.undo() { regenerate() }
    }

    func redo() {
        if history.redo() { regenerate() }
    }

    func load(_ document: Document) {
        history = UndoStack(document)
        selectedFeature = nil
        regenerate()
    }

    // MARK: Sample content

    /// Sketch a rectangle on XY and extrude it — the canonical first feature.
    func addSampleBox(width: Double = 60, depth: Double = 40, height: Double = 25) {
        commit { doc in
            let sketch = doc.addSketch(
                name: "Base sketch",
                Sketch.rectangle(corner: Vec2(-width / 2, -depth / 2), width: width, height: depth)
            )
            doc.addExtrude(name: "Base extrude", of: sketch, extent: .blind(height))
        }
    }

    // MARK: Export

    func stlData() -> Data? {
        var combined = Mesh()
        for body in result.bodies {
            guard let mesh = try? Tessellator.tessellate(body.solid) else { continue }
            combined.append(mesh)
        }
        return combined.isEmpty ? nil : STLWriter.binaryData(combined, name: document.name)
    }

    func forgeData() -> Data? {
        try? ForgeFileFormat.encode(document)
    }

    // MARK: Internals

    private func regenerate() {
        result = Regenerator.regenerate(document)
        renderMeshes = result.bodies.compactMap { body in
            (try? Tessellator.tessellate(body.solid)).map(RenderMesh.init)
        }
        revision += 1
    }
}
