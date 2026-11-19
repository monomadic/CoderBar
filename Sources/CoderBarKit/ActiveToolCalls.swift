import Foundation

/// Tracks unfinished calls rather than retaining the last tool indefinitely.
public struct ActiveToolCalls: Equatable {
    private struct Call: Equatable { let id: String; let name: String; let startedAt: Date? }
    private var calls: [Call] = []
    public var currentTool: String? { calls.last?.name }
    public var currentStartedAt: Date? { calls.last?.startedAt }

    public init() {}
    public mutating func start(id: String?, name: String, at: Date? = nil) {
        let key = id ?? "unidentified:\(name)"
        if calls.contains(where: { $0.id == key }) { return }
        calls.removeAll { $0.id == key }
        calls.append(Call(id: key, name: name, startedAt: at))
    }
    public mutating func finish(id: String?, name: String? = nil) {
        if let id { calls.removeAll { $0.id == id } }
        else if let name, let index = calls.lastIndex(where: { $0.name == name }) {
            calls.remove(at: index)
        }
    }
    public mutating func reset() { calls.removeAll() }

    public static func timestamp(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    public static func elapsedText(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }
}
