/// Snapshot-based undo/redo. Documents are small values, so keeping whole
/// copies is simpler and safer than inverse operations.
public struct UndoStack<State: Equatable & Sendable>: Sendable {
    public private(set) var present: State
    private var past: [State] = []
    private var future: [State] = []
    public var limit: Int

    public init(_ initial: State, limit: Int = 200) {
        self.present = initial
        self.limit = limit
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    /// Records `new` as the current state. No-op if nothing changed.
    public mutating func commit(_ new: State) {
        guard new != present else { return }
        past.append(present)
        if past.count > limit { past.removeFirst(past.count - limit) }
        future.removeAll()
        present = new
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard let previous = past.popLast() else { return false }
        future.append(present)
        present = previous
        return true
    }

    @discardableResult
    public mutating func redo() -> Bool {
        guard let next = future.popLast() else { return false }
        past.append(present)
        present = next
        return true
    }
}
