/// Human-readable labels for known tool operations; unknown tool names remain intact.
public enum ToolActivityLabel {
    public static func label(for tool: String) -> String {
        let name = tool.lowercased().replacingOccurrences(of: "functions.", with: "")
        switch name {
        case "read", "read_file", "read_text_file", "read_multiple_files": return "Reading files…"
        case "write", "write_file", "create_file": return "Writing files…"
        case "edit", "multiedit", "notebookedit", "edit_file", "apply_patch": return "Editing files…"
        case "bash", "exec_command", "shell", "shell_command", "terminal": return "Executing a command…"
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
