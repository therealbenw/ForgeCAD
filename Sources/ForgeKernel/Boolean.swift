public enum BooleanOperation: String, Codable, Sendable, CaseIterable {
    case union
    case subtract
    case intersect
}

/// Solid boolean operations. This is roadmap milestone M3 and the single
/// hardest piece of the kernel; the entry point exists now so the document
/// layer and UI can be wired against it.
public enum Boolean {
    public static func apply(_ op: BooleanOperation, _ a: Solid, _ b: Solid) throws -> Solid {
        throw KernelError.notImplemented("boolean \(op.rawValue)")
    }
}
