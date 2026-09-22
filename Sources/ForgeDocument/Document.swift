import ForgeGeometry
import ForgeSketch

public enum LengthUnit: String, Codable, Sendable, CaseIterable {
    case millimeters
    case centimeters
    case inches

    /// Multiply a value in this unit by this to get model units (mm).
    public var toMillimeters: Double {
        switch self {
        case .millimeters: return 1
        case .centimeters: return 10
        case .inches: return 25.4
        }
    }
}

/// A ForgeCAD part: an ordered feature history plus metadata. Geometry is
/// never stored — it is regenerated from the features (see `Regenerator`).
public struct Document: Hashable, Codable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var name: String
    public var displayUnit: LengthUnit
    public var features: [Feature]

    public init(name: String, displayUnit: LengthUnit = .millimeters, features: [Feature] = []) {
        self.formatVersion = Self.currentFormatVersion
        self.name = name
        self.displayUnit = displayUnit
        self.features = features
    }

    // MARK: Feature access

    public func feature(_ id: FeatureID) -> Feature? {
        features.first { $0.id == id }
    }

    public func index(of id: FeatureID) -> Int? {
        features.firstIndex { $0.id == id }
    }

    public func sketchFeature(_ id: FeatureID) -> SketchFeature? {
        if case .sketch(let f) = feature(id) { return f }
        return nil
    }

    // MARK: Editing

    public mutating func append(_ feature: Feature) {
        features.append(feature)
    }

    public mutating func remove(_ id: FeatureID) {
        features.removeAll { $0.id == id }
    }

    public mutating func replace(_ feature: Feature) {
        guard let i = index(of: feature.id) else { return }
        features[i] = feature
    }

    @discardableResult
    public mutating func addSketch(name: String? = nil, _ sketch: Sketch) -> FeatureID {
        let f = SketchFeature(name: name ?? "Sketch \(features.count + 1)", sketch: sketch)
        append(.sketch(f))
        return f.id
    }

    @discardableResult
    public mutating func addExtrude(
        name: String? = nil,
        of sketch: FeatureID,
        extent: ExtrudeExtent,
        operation: FeatureOperation = .newBody,
        flipped: Bool = false
    ) -> FeatureID {
        let f = ExtrudeFeature(
            name: name ?? "Extrude \(features.count + 1)",
            sketch: sketch,
            extent: extent,
            operation: operation,
            flipped: flipped
        )
        append(.extrude(f))
        return f.id
    }
}
