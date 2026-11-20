import Foundation

/// Human-readable labels for known tool operations; unknown tool names remain intact.
public enum ToolActivityLabel {
    /// Prefer agent-authored operation metadata; use a short command summary when absent.
    public static func detail(for tool: String, input: [String: AnyValue]?) -> String? {
        if tool != "Bash" {
            for key in ["title", "description", "justification", "completion_summary"] {
                if let value = input?[key]?.stringValue, let text = summary(value) { return text }
            }
            if let command = (input?["cmd"] ?? input?["command"])?.stringValue { return commandSummary(command) }
            return nil
        }
        guard let description = input?["description"]?.stringValue else { return nil }
        let text = description.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return text.isEmpty ? nil : String(text.prefix(300))
    }

    public static func codexDetail(for tool: String, arguments: String?) -> String? {
        guard let arguments else { return nil }
        if let data = arguments.data(using: .utf8),
           let input = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["title", "description", "justification", "completion_summary"] {
                if let value = input[key] as? String, let text = summary(value) { return text }
            }
            if let command = (input["cmd"] ?? input["command"]) as? String {
                return commandSummary(command)
            }
        }
        // exec wraps tool calls in JavaScript. Read literal metadata only; never evaluate it.
        if tool == "exec" || tool == "functions.exec" {
            for key in ["title", "description", "justification", "cmd", "command"] {
                let pattern = #"(?<![\\\w])"# + key + #"\s*:\s*("(?:\\.|[^"\\])*")"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: arguments, range: NSRange(arguments.startIndex..., in: arguments)),
                      let range = Range(match.range(at: 1), in: arguments),
                      let data = String(arguments[range]).data(using: .utf8),
                      let value = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? String
                else { continue }
                if key == "cmd" || key == "command" { return commandSummary(value) }
                if let text = summary(value) { return text }
            }
        }
        return nil
    }

    private static func summary(_ value: String) -> String? {
        let text = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return text.isEmpty ? nil : String(text.prefix(200))
    }

    private static func commandSummary(_ command: String) -> String? {
        guard let line = command.split(separator: "\n").first else { return nil }
        return summary(String(line))
    }

    public static func label(for tool: String) -> String {
        let name = tool.lowercased().replacingOccurrences(of: "functions.", with: "")
        switch name {
        case "read", "read_file", "read_text_file", "read_multiple_files": return "Reading files…"
        case "write", "write_file", "create_file": return "Writing files…"
        case "edit", "multiedit", "notebookedit", "edit_file", "apply_patch": return "Editing files…"
        case "bash", "exec_command", "shell", "shell_command", "terminal": return "Executing a command…"
        case "js", "mcp__cua_repl.js": return "Running JavaScript…"
        case "exec", "parallel", "multi_tool_use.parallel": return "Running tools…"
        case "write_stdin": return "Checking command output…"
        case "wait", "wait_agent", "yield_control": return "Waiting for tools…"
        case "update_plan": return "Updating plan…"
        case "request_user_input", "request_user_input_async": return "Waiting for your input"
        case "spawn_agent": return "Starting an agent…"
        case "send_message", "followup_task": return "Coordinating agents…"
        case "view_image": return "Viewing an image…"
        case "web.run", "web__run": return "Browsing the web…"
        case "glob", "grep", "search_files", "list_directory": return "Searching files…"
        default: return tool
        }
    }
}
