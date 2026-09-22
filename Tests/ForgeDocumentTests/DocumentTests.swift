import Foundation
import Testing
import ForgeGeometry
import ForgeKernel
import ForgeSketch
@testable import ForgeDocument

@Suite struct RegenerationTests {
    @Test func sketchPlusExtrudeMakesBody() throws {
        var doc = Document(name: "Block")
        let sketch = doc.addSketch(Sketch.rectangle(corner: .zero, width: 20, height: 10))
        doc.addExtrude(of: sketch, extent: .blind(5))

        let result = Regenerator.regenerate(doc)
        #expect(!result.hasErrors, "\(result.errors)")
        #expect(result.bodies.count == 1)
        let solid = try #require(result.bodies.first?.solid)
        #expect(Tolerance.equal(try Measure.volume(of: solid), 20 * 10 * 5))
    }

    @Test func symmetricExtrudeStraddlesPlane() throws {
        var doc = Document(name: "Plate")
        let sketch = doc.addSketch(Sketch.rectangle(corner: .zero, width: 2, height: 2))
        doc.addExtrude(of: sketch, extent: .symmetric(4))

        let solid = try #require(Regenerator.regenerate(doc).bodies.first?.solid)
        #expect(Tolerance.equal(solid.boundingBox.min.z, -2))
        #expect(Tolerance.equal(solid.boundingBox.max.z, 2))
    }

    @Test func flippedExtrudeGoesAgainstNormal() throws {
        var doc = Document(name: "Flip")
        let sketch = doc.addSketch(Sketch.rectangle(corner: .zero, width: 1, height: 1))
        doc.addExtrude(of: sketch, extent: .blind(3), flipped: true)

        let solid = try #require(Regenerator.regenerate(doc).bodies.first?.solid)
        #expect(Tolerance.equal(solid.boundingBox.min.z, -3))
    }

    @Test func brokenFeatureIsReportedNotFatal() throws {
        var doc = Document(name: "Broken")
        let good = doc.addSketch(Sketch.rectangle(corner: .zero, width: 1, height: 1))
        doc.addExtrude(of: good, extent: .blind(1))
        doc.addExtrude(of: FeatureID(), extent: .blind(1))            // dangling sketch reference
        doc.addExtrude(of: good, extent: .blind(1), operation: .cut) // booleans not implemented yet

        let result = Regenerator.regenerate(doc)
        #expect(result.bodies.count == 1)
        #expect(result.errors.count == 2)
    }
}

@Suite struct DocumentCodableTests {
    @Test func roundTripPreservesHistory() throws {
        var doc = Document(name: "RoundTrip", displayUnit: .inches)
        let sketch = doc.addSketch(Sketch.rectangle(corner: Vec2(1, 2), width: 3, height: 4))
        doc.addExtrude(of: sketch, extent: .symmetric(2.5), operation: .join, flipped: true)

        let data = try JSONEncoder().encode(doc)
        let back = try JSONDecoder().decode(Document.self, from: data)
        #expect(back == doc)
    }
}

@Suite struct UndoStackTests {
    // `#expect` captures its expression immutably, so mutating calls are
    // hoisted into `let`s before being asserted on.
    @Test func undoRedoWalksHistory() {
        var stack = UndoStack(0)
        stack.commit(1)
        stack.commit(2)
        stack.commit(2) // no-op
        #expect(stack.present == 2)

        let undid = stack.undo()
        #expect(undid)
        #expect(stack.present == 1)

        let redid = stack.redo()
        #expect(redid)
        #expect(stack.present == 2)

        let redidAgain = stack.redo()
        #expect(!redidAgain)

        stack.undo()
        stack.commit(5)
        #expect(!stack.canRedo)
        #expect(stack.present == 5)
    }

    @Test func limitDropsOldest() {
        var stack = UndoStack(0, limit: 2)
        for i in 1...5 { stack.commit(i) }
        let first = stack.undo()
        let second = stack.undo()
        let third = stack.undo()
        #expect(first)
        #expect(second)
        #expect(!third)
        #expect(stack.present == 3)
    }
}
