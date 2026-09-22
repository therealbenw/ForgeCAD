import Foundation
import Testing
@testable import ForgeGeometry

@Suite struct PlaneTests {
    @Test func basisIsRightHanded() {
        for plane in [Plane.xy, .xz, .yz, Plane(origin: Vec3(1, 2, 3), normal: Vec3(1, 1, 1))] {
            #expect(Tolerance.equal(plane.uAxis.cross(plane.vAxis), plane.normal))
            #expect(Tolerance.equal(plane.uAxis.length, 1))
            #expect(Tolerance.equal(plane.vAxis.length, 1))
            #expect(Tolerance.isZero(plane.uAxis.dot(plane.normal)))
        }
    }

    @Test func localWorldRoundTrip() {
        let plane = Plane(origin: Vec3(5, -2, 1), normal: Vec3(0.3, 0.8, -0.5), uHint: .unitX)
        let p = Vec2(3.5, -7.25)
        #expect(Tolerance.equal(plane.toLocal(plane.toWorld(p)), p))
        #expect(plane.contains(plane.toWorld(p)))
    }

    @Test func standardPlanes() {
        #expect(Tolerance.equal(Plane.xy.toWorld(Vec2(1, 2)), Vec3(1, 2, 0)))
        #expect(Tolerance.equal(Plane.xz.toWorld(Vec2(1, 2)), Vec3(1, 0, 2)))
        #expect(Tolerance.equal(Plane.yz.toWorld(Vec2(1, 2)), Vec3(0, 1, 2)))
    }
}

@Suite struct RayTests {
    @Test func hitsPlane() {
        let ray = Ray(origin: Vec3(0, 0, 10), direction: Vec3(0, 0, -1))
        let t = ray.intersect(.xy)
        #expect(t != nil)
        #expect(Tolerance.equal(t ?? -1, 10))
    }

    @Test func missesParallelAndBehind() {
        #expect(Ray(origin: Vec3(0, 0, 10), direction: .unitX).intersect(.xy) == nil)
        #expect(Ray(origin: Vec3(0, 0, 10), direction: .unitZ).intersect(.xy) == nil)
    }
}

@Suite struct TransformTests {
    @Test func rotationAboutZ() {
        let r = Transform.rotation(axis: .unitZ, angle: .pi / 2)
        #expect(Tolerance.equal(r.applying(point: .unitX), .unitY, tol: 1e-12))
    }

    @Test func composeAppliesRightFirst() {
        let t = Transform.translation(Vec3(10, 0, 0))
        let r = Transform.rotation(axis: .unitZ, angle: .pi / 2)
        // (t * r): rotate, then translate.
        #expect(Tolerance.equal((t * r).applying(point: .unitX), Vec3(10, 1, 0), tol: 1e-12))
        // (r * t): translate, then rotate.
        #expect(Tolerance.equal((r * t).applying(point: .unitX), Vec3(0, 11, 0), tol: 1e-12))
    }

    @Test func codableRoundTrip() throws {
        let t = Transform.translation(Vec3(1, 2, 3)) * Transform.rotation(axis: Vec3(1, 1, 0), angle: 0.7)
        let data = try JSONEncoder().encode(t)
        let back = try JSONDecoder().decode(Transform.self, from: data)
        #expect(back == t)
    }
}

@Suite struct Polygon2DTests {
    @Test func areaAndWinding() {
        let square = Polygon2D([Vec2(0, 0), Vec2(2, 0), Vec2(2, 2), Vec2(0, 2)])
        #expect(Tolerance.equal(square.signedArea, 4))
        #expect(square.isCounterClockwise)
        #expect(!Polygon2D(square.points.reversed()).isCounterClockwise)
    }

    @Test func triangulatesConcaveShape() {
        // An "L" shape: 6 vertices → 4 triangles whose areas sum to the polygon area.
        let l = Polygon2D([Vec2(0, 0), Vec2(3, 0), Vec2(3, 1), Vec2(1, 1), Vec2(1, 3), Vec2(0, 3)])
        let tris = l.triangulate()
        #expect(tris.count == 4)
        let area = tris.reduce(0.0) { acc, t in
            let a = l.points[t.a], b = l.points[t.b], c = l.points[t.c]
            return acc + (b - a).cross(c - a) * 0.5
        }
        #expect(Tolerance.equal(area, l.area))
    }
}
