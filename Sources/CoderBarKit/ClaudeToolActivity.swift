import Foundation

/// Tracks unfinished calls rather than retaining the last tool indefinitely.
public struct ClaudeToolActivity: Equatable {
    private struct Call: Equatable { let id: String; let name: String }
    private var calls: [Call] = []
    public var currentTool: String? { calls.last?.name }

    public init() {}
    public mutating func start(id: String?, name: String) {
        let key = id ?? "unidentified:\(name)"
        calls.removeAll { $0.id == key }
        calls.append(Call(id: key, name: name))
    }
    public mutating func finish(id: String?, name: String? = nil) {
        if let id { calls.removeAll { $0.id == id } }
        else if let name, let index = calls.lastIndex(where: { $0.name == name }) {
            calls.remove(at: index)
        }
    }
    public mutating func reset() { calls.removeAll() }

    public static func label(for tool: String) -> String {
        switch tool.lowercased() {
        case "read": return "Reading"
        case "bash": return "Executing a command"
        case "write": return "Writing"
        case "edit", "multiedit", "notebookedit": return "Editing"
        default: return tool
        }
    }
}
