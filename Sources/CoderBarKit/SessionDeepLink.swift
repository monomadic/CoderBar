import Foundation

/// Only build links for validated session identifiers, never a title or CLI fallback.
enum SessionDeepLink {
    static func codex(threadID: String) -> URL? {
        guard UUID(uuidString: threadID) != nil else { return nil }
        return URL(string: "codex://threads/\(threadID)")
    }

    static func claudeCode(sessionID: String) -> URL? {
        guard sessionID.hasPrefix("local_"),
              UUID(uuidString: String(sessionID.dropFirst(6))) != nil else { return nil }
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/continue"
        components.queryItems = [URLQueryItem(name: "session", value: sessionID)]
        return components.url
    }
}
