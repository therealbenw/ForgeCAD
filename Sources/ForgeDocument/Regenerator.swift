import ForgeGeometry
import ForgeKernel
import ForgeSketch

/// A solid produced by regeneration, tagged with the feature that created it.
public struct Body: Hashable, Sendable {
    public var solid: Solid
    public var sourceFeature: FeatureID

    public init(solid: Solid, sourceFeature: FeatureID) {
        self.solid = solid
        self.sourceFeature = sourceFeature
    }
}

public struct FeatureError: Hashable, Sendable {
    public var feature: FeatureID
    public var message: String
}

public struct RegenerationResult: Sendable {
    public var bodies: [Body] = []
    /// Sketches after constraint solving, keyed by their feature id.
    public var solvedSketches: [FeatureID: Sketch] = [:]
    public var errors: [FeatureError] = []

    public var hasErrors: Bool { !errors.isEmpty }

    public init() {}
}

/// Replays a document's feature history to produce geometry.
///
/// Regeneration never throws: a failing feature records an error and is
/// skipped so the rest of the model still appears, mirroring how desktop CAD
/// marks a broken feature in the tree.
public enum Regenerator {
    public static func regenerate(_ document: Document) -> RegenerationResult {
        var result = RegenerationResult()
        let solver = RelaxationSolver()

        for feature in document.features {
            switch feature {
            case .sketch(let f):
                var sketch = f.sketch
                let solve = solver.solve(&sketch)
                if !solve.converged {
                    result.errors.append(FeatureError(
                        feature: f.id,
                        message: "Sketch did not converge (residual \(solve.residual))"
                    ))
                }
                result.solvedSketches[f.id] = sketch

            case .extrude(let f):
                do {
                    try regenerateExtrude(f, into: &result)
                } catch {
                    result.errors.append(FeatureError(feature: f.id, message: "\(error)"))
                }
            }
        }
        return result
    }

    private static func regenerateExtrude(_ f: ExtrudeFeature, into result: inout RegenerationResult) throws {
        guard let sketch = result.solvedSketches[f.sketch] else {
            throw RegenerationError.missingSketch
        }
        let profiles = sketch.worldProfiles()
        guard !profiles.isEmpty else { throw RegenerationError.noClosedProfile }

        let direction = f.flipped ? -sketch.plane.normal : sketch.plane.normal
        let (start, distance): (Double, Double) = {
            switch f.extent {
            case .blind(let d): return (0, d)
            case .symmetric(let d): return (-d / 2, d)
            }
        }()

        for profile in profiles {
            let shifted = profile.map { $0 + direction * start }
            let solid = try Extrude.extrude(profile: shifted, direction: direction, distance: distance)
            try combine(solid, using: f.operation, from: f.id, into: &result)
        }
    }

    private static func combine(
        _ solid: Solid,
        using operation: FeatureOperation,
        from feature: FeatureID,
        into result: inout RegenerationResult
    ) throws {
        switch operation {
        case .newBody:
            result.bodies.append(Body(solid: solid, sourceFeature: feature))
        case .join, .cut, .intersect:
            guard let targetIndex = result.bodies.indices.last else {
                if operation == .join {
                    result.bodies.append(Body(solid: solid, sourceFeature: feature))
                    return
                }
                throw RegenerationError.noTargetBody
            }
            let op: BooleanOperation = switch operation {
            case .join: .union
            case .cut: .subtract
            case .intersect: .intersect
            case .newBody: .union
            }
            result.bodies[targetIndex].solid = try Boolean.apply(op, result.bodies[targetIndex].solid, solid)
        }
    }
}

public enum RegenerationError: Error, Hashable, Sendable, CustomStringConvertible {
    case missingSketch
    case noClosedProfile
    case noTargetBody

    public var description: String {
        switch self {
        case .missingSketch: return "Referenced sketch is missing or comes later in the history"
        case .noClosedProfile: return "Sketch has no closed profile to extrude"
        case .noTargetBody: return "No existing body to combine with"
        }
    }
}
