import Foundation
import Observation
import SwiftUI
import ForgeGeometry
import ForgeKernel
import ForgeSketch
import ForgeDocument
import ForgeRender
import ForgeIO

/// Per-document editing session. The `Document` itself is owned by SwiftUI's
/// `DocumentGroup` (see `ForgeFileDocument`); this object holds only what is
/// derived from it — regenerated geometry, render buffers, selection — and
/// routes edits through the system `UndoManager`.
@MainActor
@Observable
final class PartSession {
    private(set) var result = RegenerationResult()
    private(set) var renderMeshes: [RenderMesh] = []
    /// Bumped on every regeneration so the viewport knows when to rebuild.
    private(set) var revision = 0
    var selectedFeature: FeatureID?

    private var regeneratedFrom: Document?

    // MARK: Regeneration

    /// Rebuilds geometry when the document changed. Safe to call repeatedly.
    func regenerate(_ document: Document) {
        guard document != regeneratedFrom else { return }
        regeneratedFrom = document
        result = Regenerator.regenerate(document)
        renderMeshes = result.bodies.compactMap { body in
            (try? Tessellator.tessellate(body.solid)).map(RenderMesh.init)
        }
        revision += 1
    }

    // MARK: Editing

    /// Applies `edit` to the bound document and registers the inverse with the
    /// system undo manager. `Document` is a value type, so undo/redo are
    /// snapshot swaps; no-op edits register nothing.
    func commit(
        _ actionName: String,
        on document: Binding<Document>,
        undoManager: UndoManager?,
        _ edit: (inout Document) -> Void
    ) {
        let previous = document.wrappedValue
        var updated = previous
        edit(&updated)
        guard updated != previous else { return }
        replace(document, with: updated, restoring: previous, actionName: actionName, undoManager: undoManager)
    }

    private func replace(
        _ document: Binding<Document>,
        with new: Document,
        restoring old: Document,
        actionName: String,
        undoManager: UndoManager?
    ) {
        document.wrappedValue = new
        undoManager?.registerUndo(withTarget: self) { session in
            session.replace(document, with: old, restoring: new, actionName: actionName, undoManager: undoManager)
        }
        undoManager?.setActionName(actionName)
    }

    // MARK: Sample content

    /// Sketch a rectangle on XY and extrude it — the canonical first feature.
    func addSampleBox(
        on document: Binding<Document>,
        undoManager: UndoManager?,
        width: Double = 60,
        depth: Double = 40,
        height: Double = 25
    ) {
        commit("Add Box", on: document, undoManager: undoManager) { doc in
            let sketch = doc.addSketch(
                name: "Base sketch",
                Sketch.rectangle(corner: Vec2(-width / 2, -depth / 2), width: width, height: depth)
            )
            doc.addExtrude(name: "Base extrude", of: sketch, extent: .blind(height))
        }
    }

    // MARK: Export

    /// Binary STL of every regenerated body, or `nil` when there is no geometry.
    func stlData(name: String) -> Data? {
        var combined = Mesh()
        for body in result.bodies {
            guard let mesh = try? Tessellator.tessellate(body.solid) else { continue }
            combined.append(mesh)
        }
        return combined.isEmpty ? nil : STLWriter.binaryData(combined, name: name)
    }
}
