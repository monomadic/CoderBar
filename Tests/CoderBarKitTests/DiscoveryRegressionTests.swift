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

        func currentTitle() -> String? {
            DesktopSessionDiscovery.scan(home: home).sessions.first { $0.sessionID == liveID }?.title
        }
        precondition(currentTitle() == "Fresh chat without preview", "Missing index must use database title")
        let titleIndex = codex.appendingPathComponent("session_index.jsonl")
        func titleRecord(_ id: String, _ name: String) throws -> Data {
            var data = try JSONSerialization.data(withJSONObject: ["id": id, "thread_name": name])
            data.append(10)
            return data
        }
        var titles = try titleRecord(liveID, "Build and launch CoderBar")
        titles.append(try titleRecord(closedID, "Unrelated chat"))
        titles.append(try titleRecord(liveID, "Build and launch CoderBar (2)"))
        titles.append(Data("malformed record\n".utf8))
        titles.append(try titleRecord(liveID, "  "))
        try titles.write(to: titleIndex)
        precondition(currentTitle() == "Build and launch CoderBar (2)", "Latest valid indexed title must override initial prompt")
        titles.append(try titleRecord(liveID, "Renamed again"))
        try titles.write(to: titleIndex)
        precondition(currentTitle() == "Renamed again", "Cached titles must refresh on rename")
        try FileManager.default.removeItem(at: titleIndex)
        precondition(currentTitle() == "Fresh chat without preview", "Removed index must not retain stale title")

        let rollout = codex.appendingPathComponent("activity.jsonl")
        let update = Process()
        update.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        update.arguments = [codex.appendingPathComponent("state_5.sqlite").path,
                            "UPDATE threads SET rollout_path='\(rollout.path)' WHERE id='\(liveID)';"]
        try update.run(); update.waitUntilExit()
        precondition(update.terminationStatus == 0)
        var events = Data()
        func event(_ type: String, _ payload: [String: String], expected: String?, timestamp: String = "2026-11-20T00:00:00.123Z") throws {
            events.append(try JSONSerialization.data(withJSONObject: ["type":type,"payload":payload,"timestamp":timestamp]))
            events.append(10)
            try events.write(to: rollout)
            let current = DesktopSessionDiscovery.scan(home: home).sessions.first { $0.sessionID == liveID }
            precondition(current?.lastTool == expected, "Codex tool completion mismatch")
            precondition((current?.activityStartedAt != nil) == (current?.statusText == "thinking"))
        }
        try event("event_msg", ["type":"task_started"], expected:nil)
        try event("response_item", ["type":"custom_tool_call","name":"exec","call_id":"a"], expected:"exec")
        try event("response_item", ["type":"function_call","name":"apply_patch","call_id":"b"], expected:"apply_patch")
        try event("response_item", ["type":"function_call_output","call_id":"b"], expected:"exec")
        try event("response_item", ["type":"custom_tool_call_output","call_id":"a"], expected:nil)
        try event("response_item", ["type":"function_call","name":"read_file","call_id":"c"], expected:"read_file")
        try event("event_msg", ["type":"task_complete"], expected:nil)
        let promptTime = "2026-11-20T01:00:00.123Z"
        try event("event_msg", ["type":"task_started"], expected:nil, timestamp:promptTime)
        try event("event_msg", ["type":"user_message","message":"Check the UI"], expected:nil, timestamp:"2026-11-20T01:00:01.123Z")
        try event("response_item", ["type":"function_call","name":"js","call_id":"ui","arguments":#"{"title":"Checking model labels","code":"await app.getAXState()"}"#], expected:"js")
        func current() -> DesktopSessionDiscovery.Snapshot {
            DesktopSessionDiscovery.scan(home:home).sessions.first { $0.sessionID == liveID }!
        }
        precondition(current().activityDetail == "Checking model labels")
        precondition(current().activityStartedAt == ActiveToolCalls.timestamp(promptTime))
        try event("response_item", ["type":"function_call_output","call_id":"ui"], expected:nil)
        precondition(current().activityDetail == nil)
        precondition(current().activityStartedAt == ActiveToolCalls.timestamp(promptTime))
        // Force the turn start outside the activity tail, including on a cold cache read.
        events.append(Data((String(repeating:" ",count:600_000) + "\n").utf8))
        try event("response_item", ["type":"custom_tool_call","name":"exec","call_id":"build","input":#"await tools.exec_command({cmd:"swift build",justification:"Build the updated app"})"#], expected:"exec")
        precondition(current().activityDetail == "Build the updated app")
        precondition(current().activityStartedAt == ActiveToolCalls.timestamp(promptTime))
        let coldRollout = codex.appendingPathComponent("cold-activity.jsonl")
        try events.write(to:coldRollout)
        func selectRollout(_ path: URL) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath:"/usr/bin/sqlite3")
            process.arguments = [codex.appendingPathComponent("state_5.sqlite").path,
                                 "UPDATE threads SET rollout_path='\(path.path)' WHERE id='\(liveID)';"]
            try process.run(); process.waitUntilExit()
            precondition(process.terminationStatus == 0)
        }
        try selectRollout(coldRollout)
        precondition(current().activityStartedAt == ActiveToolCalls.timestamp(promptTime), "Cold scan must recover a turn outside the tail")
        try selectRollout(rollout)
        try event("event_msg", ["type":"turn_aborted"], expected:nil)
        precondition(current().activityStartedAt == nil)
        precondition(current().statusText == "waiting")
        precondition(ToolActivityLabel.codexDetail(for:"exec",arguments:#"await tools.exec_command({cmd:"git status\nignored second line"})"#) == "git status")
        precondition(ToolActivityLabel.codexDetail(for:"js",arguments:"malformed") == nil)
        precondition(ToolActivityLabel.label(for:"js") == "Running JavaScript…")

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
