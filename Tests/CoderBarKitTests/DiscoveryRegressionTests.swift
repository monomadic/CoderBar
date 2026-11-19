import Foundation

@main
struct DiscoveryRegressionTests {
    static func main() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let codex = home.appendingPathComponent(".codex")
        let locks = codex.appendingPathComponent("thread-writer-locks")
        try FileManager.default.createDirectory(at: locks, withIntermediateDirectories: true)
        let liveID = UUID().uuidString.lowercased()
        let closedID = UUID().uuidString.lowercased()
        let liveLock = locks.appendingPathComponent(liveID + ".lock")
        try Data().write(to: liveLock)
        try Data().write(to: locks.appendingPathComponent(closedID + ".lock"))
        let handle = try FileHandle(forReadingFrom: liveLock)
        defer { try? handle.close() }
        let sql = """
        CREATE TABLE threads(id TEXT, title TEXT, cwd TEXT, model TEXT, reasoning_effort TEXT,
          rollout_path TEXT, created_at_ms INTEGER, updated_at_ms INTEGER, thread_source TEXT,
          preview TEXT, archived INTEGER, agent_nickname TEXT, agent_role TEXT);
        CREATE TABLE thread_spawn_edges(parent_thread_id TEXT, child_thread_id TEXT, status TEXT);
        INSERT INTO threads(id,title,created_at_ms,updated_at_ms,thread_source,preview,archived)
          VALUES('\(liveID)','Fresh chat without preview',1,1,'user','',0);
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [codex.appendingPathComponent("state_5.sqlite").path, sql]
        try process.run(); process.waitUntilExit()
        precondition(process.terminationStatus == 0)

        let claude = home.appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")
        let project = home.appendingPathComponent(".claude/projects/test")
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let cliID = UUID().uuidString.lowercased()
        let desktopID = "local_" + UUID().uuidString.lowercased()
        let record: [String: Any] = ["sessionId": desktopID, "cliSessionId": cliID,
            "createdAt": 1, "lastActivityAt": 1, "isArchived": false, "title": "Long running session"]
        try JSONSerialization.data(withJSONObject: record).write(to: claude.appendingPathComponent(desktopID + ".json"))
        try Data("{\"type\":\"assistant\",\"message\":{\"stop_reason\":\"tool_use\",\"content\":[]}}\n".utf8)
            .write(to: project.appendingPathComponent(cliID + ".jsonl"))

        let report = DesktopSessionDiscovery.scan(home: home)
        precondition(report.warnings.isEmpty, "\(report.warnings)")
        precondition(report.sessions.contains { $0.sessionID == liveID }, "Lost open lock when another lock is closed, preview empty, or timestamp old")
        precondition(!report.sessions.contains { $0.sessionID == closedID })
        let claudeSession = report.sessions.first { $0.sessionID == cliID }
        precondition(claudeSession?.conversationID == desktopID, "Must retain desktop ID independently of CLI ID")
        precondition(claudeSession?.statusText == "thinking", "Active transcript must override stale record timestamp")

        let rollout = codex.appendingPathComponent("activity.jsonl")
        let update = Process()
        update.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        update.arguments = [codex.appendingPathComponent("state_5.sqlite").path,
                            "UPDATE threads SET rollout_path='\(rollout.path)' WHERE id='\(liveID)';"]
        try update.run(); update.waitUntilExit()
        precondition(update.terminationStatus == 0)
        var events = Data()
        func event(_ type: String, _ payload: [String: String], expected: String?) throws {
            events.append(try JSONSerialization.data(withJSONObject: ["type":type,"payload":payload,"timestamp":"2026-11-20T00:00:00.123Z"]))
            events.append(10)
            try events.write(to: rollout)
            let current = DesktopSessionDiscovery.scan(home: home).sessions.first { $0.sessionID == liveID }
            precondition(current?.lastTool == expected, "Codex tool completion mismatch")
            precondition((current?.activityStartedAt != nil) == (expected != nil))
        }
        try event("event_msg", ["type":"task_started"], expected:nil)
        try event("response_item", ["type":"custom_tool_call","name":"exec","call_id":"a"], expected:"exec")
        try event("response_item", ["type":"function_call","name":"apply_patch","call_id":"b"], expected:"apply_patch")
        try event("response_item", ["type":"function_call_output","call_id":"b"], expected:"exec")
        try event("response_item", ["type":"custom_tool_call_output","call_id":"a"], expected:nil)
        try event("response_item", ["type":"function_call","name":"read_file","call_id":"c"], expected:"read_file")
        try event("event_msg", ["type":"task_complete"], expected:nil)
        for (tool, label) in [("exec","Running tools…"),("functions.exec_command","Executing a command…"),("apply_patch","Editing files…"),("read_file","Reading files…"),("write_file","Writing files…"),("CustomTool","CustomTool")] {
            precondition(ToolActivityLabel.label(for: tool) == label)
        }

        let url = SessionDeepLink.claudeCode(sessionID: desktopID)!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        precondition(components.path == "/continue")
        precondition(components.queryItems == [URLQueryItem(name: "session", value: desktopID)])
        precondition(SessionDeepLink.claudeCode(sessionID: cliID) == nil, "Do not guess a desktop target from a CLI ID")
        precondition(SessionDeepLink.codex(threadID: liveID)?.absoluteString == "codex://threads/\(liveID)")
        precondition(SessionDeepLink.codex(threadID: "id?prompt=oops") == nil)
        print("Passed discovery and session-link regression checks")
    }
}
