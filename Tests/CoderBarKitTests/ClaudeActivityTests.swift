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
        var record: [String: Any] = ["sessionId":desktop,"cliSessionId":id,"createdAt":1,"lastActivityAt":1,"isArchived":false,"title":"Activity test"]
        try JSONSerialization.data(withJSONObject:record).write(to:records.appendingPathComponent(desktop+".json"))
        let transcript = project.appendingPathComponent(id+".jsonl")
        var log = Data()
        func append(_ row: [String: Any]) throws {
            var timestamped = row; if timestamped["timestamp"] == nil { timestamped["timestamp"] = "2026-11-20T00:00:00.123Z" }
            log.append(try JSONSerialization.data(withJSONObject:timestamped)); log.append(10)
            try log.write(to:transcript)
        }
        func tool(_ id: String, _ name: String, description: String = "") throws {
            try append(["type":"assistant","message":["stop_reason":"tool_use","content":[["type":"tool_use","id":id,"name":name,"input":["description":description]]]]])
        }
        func result(_ id: String, error: Bool = false) throws {
            try append(["type":"user","message":["content":[["type":"tool_result","tool_use_id":id,"is_error":error,"content":"result"]]]])
        }
        func check(_ tool: String?, status: String = "thinking") {
            let session = DesktopSessionDiscovery.scan(home:home).sessions.first { $0.sessionID == id }
            precondition(session != nil)
            precondition(session?.lastTool == tool,"Expected \(String(describing:tool)), got \(String(describing:session?.lastTool))")
            precondition(session?.statusText == status)
            precondition((session?.activityStartedAt != nil) == (status == "thinking"))
        }
        let promptTime = "2026-11-19T23:45:00.123Z"
        try append(["type":"user","timestamp":promptTime,"message":["content":"Start export"]])
        func snapshot() -> DesktopSessionDiscovery.Snapshot {
            DesktopSessionDiscovery.scan(home:home).sessions.first { $0.sessionID == id }!
        }
        precondition(snapshot().title == "Activity test")
        record["title"] = "Renamed Claude session"
        try JSONSerialization.data(withJSONObject:record).write(to:records.appendingPathComponent(desktop+".json"))
        precondition(snapshot().title == "Renamed Claude session", "Renames must invalidate the record cache")
        try tool("a","Read"); check("Read")
        try tool("b","Bash", description:"Run in-app export with --export-run OUT"); check("Bash")
        precondition(snapshot().activityDetail == "Run in-app export with --export-run OUT")
        precondition(snapshot().activityStartedAt == ActiveToolCalls.timestamp(promptTime), "Tool changes must retain prompt time")
        try append(["type":"user","isMeta":true,"message":["content":"Image metadata"]])
        precondition(snapshot().activityDetail != nil, "Metadata must not clear running tools")
        precondition(snapshot().activityStartedAt == ActiveToolCalls.timestamp(promptTime))
        try result("b"); check("Read"); precondition(snapshot().activityDetail == nil)
        try result("unknown"); check("Read")
        try result("a",error:true); check(nil)
        try tool("c","Write"); check("Write")
        try append(["type":"assistant","message":["stop_reason":"end_turn","content":[]]])
        check(nil,status:"waiting")
        try append(["type":"user","message":["content":"Next prompt"]])
        try tool("d","Edit")
        try append(["type":"user","message":["content":"new turn"]]); check(nil)
        for (name,label) in [("Read","Reading files…"),("Bash","Executing a command…"),("Write","Writing files…"),("Edit","Editing files…"),("CustomTool","CustomTool")] {
            precondition(ToolActivityLabel.label(for:name)==label)
        }
        // A long turn can push its prompt outside the bounded transcript tail.
        record["latestUserFrameAt"] = 1795132589275 as Int64
        try JSONSerialization.data(withJSONObject:record).write(to:records.appendingPathComponent(desktop+".json"))
        log = Data()
        try tool("long", "Bash", description:"Long command")
        precondition(snapshot().activityStartedAt == Date(timeIntervalSince1970:1795132589.275))
        try result("long")
        precondition(snapshot().activityDetail == nil)
        precondition(snapshot().activityStartedAt != nil, "Timer continues between tools")
        try append(["type":"assistant","message":["stop_reason":"end_turn","content":[]]])
        precondition(snapshot().activityStartedAt == nil)
        // Progress survives tool results, but never leaks into the next turn.
        try append(["type":"user","message":["content":"Apply frame changes"]])
        try append(["type":"assistant","message":["content":[["type":"text","text":"Applying the frame changes"]]]])
        try append(["type":"assistant","message":["stop_reason":"tool_use","content":[
            ["type":"tool_use","id":"todos","name":"TodoWrite","input":["todos":[
                ["content":"Read editor code","status":"completed"],
                ["content":"Add mask inspector","status":"in_progress"],
                ["content":"Build and test","status":"pending"]
            ]]]
        ]]])
        try result("todos")
        precondition(snapshot().planItems.count == 3)
        precondition(snapshot().activityDetail == "Add mask inspector")
        try tool("frame", "Bash", description:"Build the editor")
        precondition(snapshot().activityDetail == "Build the editor")
        try result("frame")
        precondition(snapshot().activityDetail == "Add mask inspector")
        try append(["type":"assistant","message":["stop_reason":"tool_use","content":[
            ["type":"tool_use","id":"clear","name":"TodoWrite","input":["todos":[]]]
        ]]])
        try result("clear")
        precondition(snapshot().planItems.isEmpty)
        precondition(snapshot().activityDetail == "Applying the frame changes")
        try append(["type":"assistant","message":["stop_reason":"end_turn","content":[]]])
        precondition(snapshot().activityDetail == nil)
        try append(["type":"user","message":["content":"Another task"]])
        precondition(snapshot().activityDetail == nil)
        precondition(snapshot().planItems.isEmpty)
        let store = try SessionStore(dataDir:home.appendingPathComponent("store"),replayOnStart:false)
        func hook(_ event: String, _ id: String? = nil, _ name: String? = nil) {
            var p = HookPayload(); p.source="claude";p.sessionId="hook-session";p.hookEventName=event;p.toolUseId=id;p.toolName=name
            store.ingest(p)
        }
        hook("UserPromptSubmit")
        let hookStart = store.sessions.first?.activityStartedAt
        precondition(hookStart != nil)
        hook("PreToolUse","a","Read"); hook("PreToolUse","b","Bash")
        precondition(store.sessions.first?.lastTool == "Bash")
        precondition(store.sessions.first?.activityStartedAt == hookStart)
        hook("PostToolUse","b","Bash");precondition(store.sessions.first?.lastTool == "Read")
        hook("PostToolUseFailure","a","Read");precondition(store.sessions.first?.lastTool == nil)
        precondition(store.sessions.first?.activityStartedAt == hookStart)
        hook("PreToolUse","c","Write");hook("Stop");precondition(store.sessions.first?.lastTool == nil)
        var codexHook = HookPayload()
        codexHook.source = "codex"; codexHook.sessionId = "codex-hook"
        codexHook.hookEventName = "BeforeAgent"
        store.ingest(codexHook)
        let codexStart = store.sessions.first { $0.sessionId == "codex-hook" }?.activityStartedAt
        precondition(codexStart != nil)
        codexHook.hookEventName = "BeforeTool"; codexHook.toolName = "js"; codexHook.toolUseId = "ui"
        codexHook.toolInput = ["title": .string("Checking the updated UI")]
        store.ingest(codexHook)
        let codexSession = store.sessions.first { $0.sessionId == "codex-hook" }
        precondition(codexSession?.activityDetail == "Checking the updated UI")
        precondition(codexSession?.activityStartedAt == codexStart)
        codexHook.hookEventName = "AfterTool"; store.ingest(codexHook)
        precondition(store.sessions.first { $0.sessionId == "codex-hook" }?.activityStartedAt == codexStart)
        codexHook.hookEventName = "AfterAgent"; store.ingest(codexHook)
        precondition(store.sessions.first { $0.sessionId == "codex-hook" }?.activityStartedAt == nil)
        print("PASS: Claude transcript and hook completion, parallel calls, failed results, turn reset, and labels")
    }
}
