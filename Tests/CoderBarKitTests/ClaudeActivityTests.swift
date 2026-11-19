import Foundation

@main
struct ClaudeActivityTests {
    @MainActor static func main() throws {
        var timer = ActiveToolCalls()
        let start = Date(timeIntervalSince1970: 100)
        timer.start(id: "a", name: "Read", at: start)
        timer.start(id: "a", name: "Read", at: start.addingTimeInterval(9))
        precondition(timer.currentStartedAt == start, "Polling/repeated events must not reset time")
        timer.start(id: "b", name: "Read", at: start.addingTimeInterval(10))
        precondition(timer.currentStartedAt == start.addingTimeInterval(10), "New call resets even for the same tool")
        timer.finish(id: "b")
        precondition(timer.currentStartedAt == start)
        timer.finish(id: "a")
        precondition(timer.currentStartedAt == nil)
        precondition(ActiveToolCalls.elapsedText(since: start, now: start.addingTimeInterval(32)) == "32s")
        precondition(ActiveToolCalls.elapsedText(since: start, now: start.addingTimeInterval(92)) == "1m 32s")
        precondition(ActiveToolCalls.timestamp("2026-11-20T00:00:00.123Z") != nil)
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let records = home.appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")
        let project = home.appendingPathComponent(".claude/projects/test")
        try FileManager.default.createDirectory(at: records, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let id = UUID().uuidString.lowercased()
        let desktop = "local_" + UUID().uuidString.lowercased()
        let record: [String: Any] = ["sessionId":desktop,"cliSessionId":id,"createdAt":1,"lastActivityAt":1,"isArchived":false,"title":"Activity test"]
        try JSONSerialization.data(withJSONObject:record).write(to:records.appendingPathComponent(desktop+".json"))
        let transcript = project.appendingPathComponent(id+".jsonl")
        var log = Data()
        func append(_ row: [String: Any]) throws {
            var timestamped = row; timestamped["timestamp"] = "2026-11-20T00:00:00.123Z"
            log.append(try JSONSerialization.data(withJSONObject:timestamped)); log.append(10)
            try log.write(to:transcript)
        }
        func tool(_ id: String, _ name: String) throws {
            try append(["type":"assistant","message":["stop_reason":"tool_use","content":[["type":"tool_use","id":id,"name":name,"input":[:]]]]])
        }
        func result(_ id: String, error: Bool = false) throws {
            try append(["type":"user","message":["content":[["type":"tool_result","tool_use_id":id,"is_error":error,"content":"result"]]]])
        }
        func check(_ tool: String?, status: String = "thinking") {
            let session = DesktopSessionDiscovery.scan(home:home).sessions.first { $0.sessionID == id }
            precondition(session != nil)
            precondition(session?.lastTool == tool,"Expected \(String(describing:tool)), got \(String(describing:session?.lastTool))")
            precondition(session?.statusText == status)
            precondition((session?.activityStartedAt != nil) == (tool != nil))
        }
        try tool("a","Read"); check("Read")
        try tool("b","Bash"); check("Bash")
        try result("b"); check("Read")
        try result("unknown"); check("Read")
        try result("a",error:true); check(nil)
        try tool("c","Write"); check("Write")
        try append(["type":"assistant","message":["stop_reason":"end_turn","content":[]]])
        check(nil,status:"waiting")
        try tool("d","Edit")
        try append(["type":"user","message":["content":"new turn"]]); check(nil)
        for (name,label) in [("Read","Reading files…"),("Bash","Executing a command…"),("Write","Writing files…"),("Edit","Editing files…"),("CustomTool","CustomTool")] {
            precondition(ToolActivityLabel.label(for:name)==label)
        }
        let store = try SessionStore(dataDir:home.appendingPathComponent("store"),replayOnStart:false)
        func hook(_ event: String, _ id: String? = nil, _ name: String? = nil) {
            var p = HookPayload(); p.source="claude";p.sessionId="hook-session";p.hookEventName=event;p.toolUseId=id;p.toolName=name
            store.ingest(p)
        }
        hook("PreToolUse","a","Read"); hook("PreToolUse","b","Bash")
        precondition(store.sessions.first?.lastTool == "Bash")
        hook("PostToolUse","b","Bash");precondition(store.sessions.first?.lastTool == "Read")
        hook("PostToolUseFailure","a","Read");precondition(store.sessions.first?.lastTool == nil)
        hook("PreToolUse","c","Write");hook("Stop");precondition(store.sessions.first?.lastTool == nil)
        print("PASS: Claude transcript and hook completion, parallel calls, failed results, turn reset, and labels")
    }
}
