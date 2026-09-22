import Testing
import ForgeGeometry
@testable import ForgeKernel

@Suite struct ExtrudeTests {
    @Test func boxHasSharedTopology() throws {
        let box = try Primitives.box(size: Vec3(2, 3, 4))
        #expect(box.vertices.count == 8)
        #expect(box.edges.count == 12)
        #expect(box.faces.count == 6)
        #expect(box.satisfiesEulerFormula)
    }

    @Test func boxVolumeAndArea() throws {
        let box = try Primitives.box(size: Vec3(2, 3, 4))
        #expect(Tolerance.equal(try Measure.volume(of: box), 24))
        #expect(Tolerance.equal(try Measure.surfaceArea(of: box), 2 * (6 + 8 + 12)))
    }

    @Test func faceNormalsPointOutward() throws {
        let box = try Primitives.box(size: Vec3(1, 1, 1))
        let center = box.boundingBox.center
        for face in box.sortedFaces {
            let normal = try #require(face.normalIfPlanar)
            guard case .plane(let plane) = face.surface else { Issue.record("expected planar face"); return }
            #expect((plane.origin - center).dot(normal) > 0, "face \(face.id.raw) normal points inward")
        }
    }

    @Test func windingIsNormalised() throws {
        // Clockwise profile must give the same positive volume as counter-clockwise.
        let ccw = [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0), Vec3(0, 1, 0)]
        let a = try Extrude.extrude(profile: ccw, direction: .unitZ, distance: 2)
        let b = try Extrude.extrude(profile: ccw.reversed(), direction: .unitZ, distance: 2)
        #expect(Tolerance.equal(try Measure.volume(of: a), 2))
        #expect(Tolerance.equal(try Measure.volume(of: b), 2))
    }

    @Test func negativeDistanceExtrudesBackwards() throws {
        let profile = [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0), Vec3(0, 1, 0)]
        let solid = try Extrude.extrude(profile: profile, direction: .unitZ, distance: -3)
        #expect(Tolerance.equal(solid.boundingBox.min.z, -3))
        #expect(Tolerance.equal(solid.boundingBox.max.z, 0))
        #expect(Tolerance.equal(try Measure.volume(of: solid), 3))
    }

    @Test func concaveProfile() throws {
        let l = [Vec2(0, 0), Vec2(3, 0), Vec2(3, 1), Vec2(1, 1), Vec2(1, 3), Vec2(0, 3)]
        let solid = try Extrude.extrude(profile: l, on: .xy, distance: 2)
        #expect(Tolerance.equal(try Measure.volume(of: solid), 5 * 2))
    }

    @Test func rejectsDegenerateInput() {
        #expect(throws: KernelError.self) {
            try Extrude.extrude(profile: [Vec3(0, 0, 0), Vec3(1, 0, 0)], direction: .unitZ, distance: 1)
        }
        #expect(throws: KernelError.self) {
            try Extrude.extrude(
                profile: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0)], direction: .unitZ, distance: 0
            )
        }
        #expect(throws: KernelError.self) {
            try Extrude.extrude(
                profile: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0)], direction: .unitX, distance: 1
            )
        }
    }

    @Test func prismVolumeApproachesCylinder() throws {
        let prism = try Primitives.prism(radius: 10, height: 5, sides: 256)
        let cylinder = Double.pi * 100 * 5
        #expect(abs(try Measure.volume(of: prism) - cylinder) / cylinder < 1e-3)
    }
}

@Suite struct TransformSolidTests {
    @Test func translatedBoxKeepsVolume() throws {
        let box = try Primitives.box(size: Vec3(1, 2, 3))
        let moved = box.transformed(by: .translation(Vec3(10, 20, 30)) * .rotation(axis: .unitZ, angle: 0.4))
        #expect(Tolerance.equal(try Measure.volume(of: moved), 6, tol: 1e-9))
        #expect(moved.boundingBox.min.x > 9)
    }
}

@Suite struct BooleanTests {
    @Test func booleansAreNotImplementedYet() throws {
        let a = try Primitives.box(size: Vec3(1, 1, 1))
        #expect(throws: KernelError.notImplemented("boolean union")) {
            try Boolean.apply(.union, a, a)
        }
    }
}
