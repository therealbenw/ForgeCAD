import Testing
import ForgeGeometry
@testable import ForgeSketch

@Suite struct SolverTests {
    @Test func rectangleIsAlreadySatisfied() {
        var sketch = Sketch.rectangle(corner: .zero, width: 10, height: 5)
        let result = RelaxationSolver().solve(&sketch)
        #expect(result.converged)
        #expect(result.residual < 1e-9)
    }

    @Test func horizontalAndVerticalSnapSkewedRectangle() {
        var sketch = Sketch.rectangle(corner: .zero, width: 10, height: 5)
        // Nudge a corner off-axis; the H/V constraints must pull it back.
        let p2 = sketch.points[2].id
        sketch.setPosition(Vec2(10.4, 4.7), of: p2)

        let result = RelaxationSolver().solve(&sketch)
        #expect(result.converged)
        #expect(result.residual < 1e-9)

        let profile = sketch.closedProfiles().first
        #expect(profile != nil)
        #expect(Tolerance.equal(profile?.polygon.area ?? 0, 10 * 5, tol: 1))
        // Fixed corner stayed put.
        #expect(Tolerance.equal(sketch.points[0].position, .zero))
    }

    @Test func distanceConstraintWithFixedAnchor() {
        var sketch = Sketch(plane: .xy)
        let a = sketch.addPoint(.zero)
        let b = sketch.addPoint(Vec2(1, 1))
        sketch.add(.fixed(a))
        sketch.add(.distance(a, b, 5))

        let result = RelaxationSolver().solve(&sketch)
        #expect(result.converged)
        #expect(Tolerance.equal(sketch.position(of: a) ?? Vec2(9, 9), .zero))
        #expect(Tolerance.equal(sketch.position(of: b)?.length ?? 0, 5, tol: 1e-8))
    }

    @Test func dimensionedRectangleResizes() {
        var sketch = Sketch.rectangle(corner: .zero, width: 10, height: 5)
        let p0 = sketch.points[0].id, p1 = sketch.points[1].id, p3 = sketch.points[3].id
        sketch.add(.horizontalDistance(p0, p1, 20))
        sketch.add(.verticalDistance(p0, p3, 8))

        let result = RelaxationSolver().solve(&sketch)
        #expect(result.converged, "residual \(result.residual) after \(result.iterations) iterations")
        let area = sketch.closedProfiles().first?.polygon.area ?? 0
        #expect(Tolerance.equal(area, 20 * 8, tol: 1e-6))
    }
}

@Suite struct ProfileTests {
    @Test func rectangleYieldsOneProfile() {
        let sketch = Sketch.rectangle(corner: Vec2(1, 1), width: 4, height: 2)
        let profiles = sketch.closedProfiles()
        #expect(profiles.count == 1)
        #expect(profiles.first?.points.count == 4)
        #expect(Tolerance.equal(profiles.first?.polygon.area ?? 0, 8))
    }

    @Test func openChainYieldsNothing() {
        var sketch = Sketch()
        sketch.addLine(Vec2(0, 0), Vec2(1, 0))
        sketch.addLine(Vec2(1, 0), Vec2(1, 1))
        #expect(sketch.closedProfiles().isEmpty)
    }

    @Test func coincidentConstraintClosesChain() {
        var sketch = Sketch()
        let a = sketch.addPoint(Vec2(0, 0))
        let b = sketch.addPoint(Vec2(1, 0))
        let c = sketch.addPoint(Vec2(1, 1))
        let cPrime = sketch.addPoint(Vec2(1, 1))
        sketch.addLine(from: a, to: b)
        sketch.addLine(from: b, to: c)
        sketch.addLine(from: cPrime, to: a)
        sketch.add(.coincident(c, cPrime))
        #expect(sketch.closedProfiles().count == 1)
    }

    @Test func circleBecomesPolygon() {
        var sketch = Sketch()
        sketch.addCircle(center: Vec2(3, 3), radius: 2)
        let profiles = sketch.closedProfiles(circleSegments: 128)
        #expect(profiles.count == 1)
        let area = profiles.first?.polygon.area ?? 0
        #expect(abs(area - .pi * 4) / (.pi * 4) < 1e-3)
    }

    @Test func worldProfilesUseSketchPlane() {
        let sketch = Sketch.rectangle(on: .xz, corner: .zero, width: 1, height: 1)
        let world = sketch.worldProfiles().first ?? []
        #expect(world.count == 4)
        #expect(world.allSatisfy { Tolerance.isZero($0.y) })
    }
}
