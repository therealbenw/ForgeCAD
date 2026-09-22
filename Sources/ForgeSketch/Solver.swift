import ForgeGeometry

public struct SolveResult: Hashable, Sendable {
    public var iterations: Int
    /// Largest remaining constraint violation (mm).
    public var residual: Double
    public var converged: Bool
}

/// A simple iterative-projection ("relaxation") constraint solver.
///
/// Every supported constraint is expressed as a residual vector between two
/// points; each iteration nudges the points to cancel it, splitting the
/// correction between them unless one is fixed. This converges quickly for the
/// well-determined sketches a rectangle-and-extrude workflow produces and is
/// deliberately simple. Roadmap M4 replaces it with a Gauss-Newton /
/// Levenberg-Marquardt solver over the full constraint Jacobian.
public struct RelaxationSolver: Sendable {
    public var maxIterations: Int
    public var tolerance: Double

    public init(maxIterations: Int = 500, tolerance: Double = 1e-9) {
        self.maxIterations = maxIterations
        self.tolerance = tolerance
    }

    public func solve(_ sketch: inout Sketch) -> SolveResult {
        var positions: [SketchPointID: Vec2] = [:]
        for p in sketch.points { positions[p.id] = p.position }
        let fixed = Set(sketch.constraints.compactMap { c -> SketchPointID? in
            if case .fixed(let id) = c { return id }
            return nil
        })

        var iterations = 0
        var converged = false
        while iterations < maxIterations {
            iterations += 1
            var maxMove = 0.0
            for c in sketch.constraints {
                guard let (a, b, residual) = residual(of: c, in: sketch, positions: positions) else { continue }
                let (wa, wb) = weights(a: fixed.contains(a), b: fixed.contains(b))
                positions[a]! -= residual * wa
                positions[b]! += residual * wb
                maxMove = max(maxMove, residual.length * max(wa, wb))
            }
            if maxMove <= tolerance {
                converged = true
                break
            }
        }

        for (id, p) in positions { sketch.setPosition(p, of: id) }
        return SolveResult(iterations: iterations, residual: self.residual(of: sketch), converged: converged)
    }

    /// Largest constraint violation in the sketch as it stands.
    public func residual(of sketch: Sketch) -> Double {
        var positions: [SketchPointID: Vec2] = [:]
        for p in sketch.points { positions[p.id] = p.position }
        return sketch.constraints.reduce(0.0) { acc, c in
            guard let (_, _, r) = residual(of: c, in: sketch, positions: positions) else { return acc }
            return max(acc, r.length)
        }
    }

    // MARK: Internals

    /// Fraction of the correction each point absorbs.
    private func weights(a aFixed: Bool, b bFixed: Bool) -> (Double, Double) {
        switch (aFixed, bFixed) {
        case (true, true): return (0, 0)
        case (true, false): return (0, 1)
        case (false, true): return (1, 0)
        case (false, false): return (0.5, 0.5)
        }
    }

    /// Expresses a constraint as `(a, b, r)` where `r == (a − b) − desired`.
    /// Moving `a` by `−r` (or `b` by `+r`) satisfies it exactly.
    private func residual(
        of constraint: SketchConstraint,
        in sketch: Sketch,
        positions: [SketchPointID: Vec2]
    ) -> (SketchPointID, SketchPointID, Vec2)? {
        func endpoints(_ e: SketchEntityID) -> (SketchPointID, SketchPointID)? {
            if case .line(_, let s, let t) = sketch.entity(e) { return (s, t) }
            return nil
        }

        switch constraint {
        case .fixed:
            return nil

        case .coincident(let a, let b):
            guard let pa = positions[a], let pb = positions[b] else { return nil }
            return (a, b, pa - pb)

        case .horizontal(let e):
            guard let (a, b) = endpoints(e), let pa = positions[a], let pb = positions[b] else { return nil }
            return (a, b, Vec2(0, pa.y - pb.y))

        case .vertical(let e):
            guard let (a, b) = endpoints(e), let pa = positions[a], let pb = positions[b] else { return nil }
            return (a, b, Vec2(pa.x - pb.x, 0))

        case .distance(let a, let b, let d):
            guard let pa = positions[a], let pb = positions[b] else { return nil }
            var v = pa - pb
            if v.isNearlyZero { v = .unitX }   // coincident points: push apart along u
            return (a, b, v - v.normalized * d)

        case .horizontalDistance(let a, let b, let d):
            guard let pa = positions[a], let pb = positions[b] else { return nil }
            return (a, b, Vec2((pa.x - pb.x) + d, 0))

        case .verticalDistance(let a, let b, let d):
            guard let pa = positions[a], let pb = positions[b] else { return nil }
            return (a, b, Vec2(0, (pa.y - pb.y) + d))
        }
    }
}
