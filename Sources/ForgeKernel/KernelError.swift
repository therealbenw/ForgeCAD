public enum KernelError: Error, Hashable, Sendable, CustomStringConvertible {
    case degenerateGeometry(String)
    case nonPlanarProfile
    case invalidTopology(String)
    case unsupported(String)
    case notImplemented(String)

    public var description: String {
        switch self {
        case .degenerateGeometry(let why): return "Degenerate geometry: \(why)"
        case .nonPlanarProfile: return "Profile points are not coplanar"
        case .invalidTopology(let why): return "Invalid topology: \(why)"
        case .unsupported(let what): return "Unsupported: \(what)"
        case .notImplemented(let what): return "Not implemented yet: \(what)"
        }
    }
}
