import Foundation
import ForgeKernel
import ForgeSketch

public struct FeatureID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}

public struct SketchFeature: Hashable, Codable, Sendable {
    public let id: FeatureID
    public var name: String
    public var sketch: Sketch

    public init(id: FeatureID = FeatureID(), name: String, sketch: Sketch) {
        self.id = id
        self.name = name
        self.sketch = sketch
    }
}

public enum ExtrudeExtent: Hashable, Codable, Sendable {
    /// A fixed distance along the sketch normal.
    case blind(Double)
    /// Half the distance on each side of the sketch plane.
    case symmetric(Double)
}

public enum FeatureOperation: String, Codable, Sendable, CaseIterable {
    case newBody
    case join
    case cut
    case intersect
}

public struct ExtrudeFeature: Hashable, Codable, Sendable {
    public let id: FeatureID
    public var name: String
    /// The `SketchFeature` supplying the profiles. Must precede this feature.
    public var sketch: FeatureID
    public var extent: ExtrudeExtent
    public var operation: FeatureOperation
    /// Extrude against the sketch normal instead of along it.
    public var flipped: Bool

    public init(
        id: FeatureID = FeatureID(),
        name: String,
        sketch: FeatureID,
        extent: ExtrudeExtent,
        operation: FeatureOperation = .newBody,
        flipped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sketch = sketch
        self.extent = extent
        self.operation = operation
        self.flipped = flipped
    }
}

/// One node of the parametric history. Adding a feature kind means adding a
/// case here, a `Regenerator` step, and a row in the app's feature tree.
public enum Feature: Hashable, Codable, Sendable {
    case sketch(SketchFeature)
    case extrude(ExtrudeFeature)

    public var id: FeatureID {
        switch self {
        case .sketch(let f): return f.id
        case .extrude(let f): return f.id
        }
    }

    public var name: String {
        get {
            switch self {
            case .sketch(let f): return f.name
            case .extrude(let f): return f.name
            }
        }
        set {
            switch self {
            case .sketch(var f): f.name = newValue; self = .sketch(f)
            case .extrude(var f): f.name = newValue; self = .extrude(f)
            }
        }
    }
}
