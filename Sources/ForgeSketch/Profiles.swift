import Foundation
import ForgeGeometry

/// A closed region of a sketch that can be extruded or revolved.
public struct SketchProfile: Hashable, Codable, Sendable {
    /// Boundary in sketch (u, v) coordinates, no repeated closing point.
    public var points: [Vec2]
    /// Entities that contributed to the boundary.
    public var entities: [SketchEntityID]

    public init(points: [Vec2], entities: [SketchEntityID]) {
        self.points = points
        self.entities = entities
    }

    public var polygon: Polygon2D { Polygon2D(points) }
}

public extension Sketch {
    /// Finds closed regions bounded by line entities (chained through shared or
    /// coincident points) plus every circle as a polygonised region.
    ///
    /// Limitations at this milestone: arcs are ignored, overlapping regions are
    /// not split, and only one loop per connected component is returned.
    func closedProfiles(circleSegments: Int = 64) -> [SketchProfile] {
        var profiles: [SketchProfile] = []

        // Union-find over coincident points so chains connect across them.
        var parent: [SketchPointID: SketchPointID] = [:]
        func find(_ p: SketchPointID) -> SketchPointID {
            var root = p
            while let next = parent[root], next != root { root = next }
            var cur = p
            while let next = parent[cur], next != root {
                parent[cur] = root
                cur = next
            }
            return root
        }
        for p in points { parent[p.id] = p.id }
        for c in constraints {
            if case .coincident(let a, let b) = c { parent[find(a)] = find(b) }
        }

        // Adjacency: representative point → lines touching it.
        let lines = self.lines
        var adjacency: [SketchPointID: [Int]] = [:]
        for (i, l) in lines.enumerated() {
            adjacency[find(l.start), default: []].append(i)
            adjacency[find(l.end), default: []].append(i)
        }

        var visited = Set<Int>()
        for startIndex in lines.indices where !visited.contains(startIndex) {
            let origin = find(lines[startIndex].start)
            var current = find(lines[startIndex].end)
            var chain = [startIndex]
            visited.insert(startIndex)

            while current != origin {
                guard let nextIndex = adjacency[current]?.first(where: { !visited.contains($0) }) else { break }
                visited.insert(nextIndex)
                chain.append(nextIndex)
                let l = lines[nextIndex]
                current = find(l.start) == current ? find(l.end) : find(l.start)
            }

            guard current == origin, chain.count >= 3 else { continue }

            var pts: [Vec2] = []
            var cursor = origin
            for i in chain {
                let l = lines[i]
                let (from, to) = find(l.start) == cursor ? (l.start, l.end) : (l.end, l.start)
                if let p = position(of: from) { pts.append(p) }
                cursor = find(to)
            }
            profiles.append(SketchProfile(points: pts, entities: chain.map { lines[$0].id }))
        }

        for e in entities {
            guard case .circle(let id, let centerID, let radius) = e, let c = position(of: centerID) else { continue }
            let pts = (0..<circleSegments).map { i -> Vec2 in
                let t = 2 * Double.pi * Double(i) / Double(circleSegments)
                return c + Vec2(radius * cos(t), radius * sin(t))
            }
            profiles.append(SketchProfile(points: pts, entities: [id]))
        }

        return profiles
    }

    /// `closedProfiles()` lifted into model space through the sketch plane.
    func worldProfiles(circleSegments: Int = 64) -> [[Vec3]] {
        closedProfiles(circleSegments: circleSegments).map { $0.points.map(plane.toWorld) }
    }
}
