import SwiftUI
import AppKit
import CoderBarKit

struct SessionDashboard: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var store: SessionStore
    @ObservedObject var island: NotchViewModel
    @State private var activationErrors: [String: String] = [:]

    private var activeSessions: [SessionStore.Session] {
        store.visibleActiveSessions
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(activeSessions) { session in
                    SessionRow(
                        session: session,
                        activationError: activationErrors[session.id],
                        onActivate: { activate(session) },
                        onRespond: { interaction, allow, answers in
                            model.respond(
                                sessionID: session.id,
                                interaction: interaction,
                                allow: allow,
                                answers: answers
                            )
                        },
                        responseError: model.interactionErrors[session.id],
                        showTasks: model.showTasks,
                        showSubagents: model.showSubagents,
                        showActivity: model.showActivity,
                        showProjectName: model.showProjectName,
                        showModel: model.showModel,
                        showReasoningEffort: model.showReasoningEffort,
                        contentFontSize: model.contentFontSize
                    )
                    .frame(height: IslandMetrics.rowHeight(
                        session,
                        showTasks: model.showTasks,
                        showSubagents: model.showSubagents
                    ))
                }
            }
            .padding(.top, IslandMetrics.expandedListTopInset)
            .padding(.bottom, IslandMetrics.expandedBottomInset)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            if activeSessions.reduce(0, {
                $0 + IslandMetrics.rowHeight(
                    $1,
                    showTasks: model.showTasks,
                    showSubagents: model.showSubagents
                )
            }) > model.maxPanelHeight - island.expandedHeaderHeight {
                Text("•••")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.28))
                    .padding(.bottom, 3)
                    .allowsHitTesting(false)
            }
        }
    }

    private func activate(_ session: SessionStore.Session) {
        let result = TerminalActivator.activate(
            session,
            allowCodexDeepLink: model.openAppServerSessionsInCodex
        )
        if result.succeeded {
            activationErrors[session.id] = nil
            island.collapse()
        } else {
            activationErrors[session.id] = result.message
            NSLog(
                "CoderBar row click could not activate session %@: %@",
                session.id,
                result.message
            )
        }
    }
}

private struct SessionRow: View {
    let session: SessionStore.Session
    let activationError: String?
    let onActivate: () -> Void
    let onRespond: (PendingInteraction, Bool, [String: [String]]) -> Void
    let responseError: String?
    let showTasks: Bool
    let showSubagents: Bool
    let showActivity: Bool
    let showProjectName: Bool
    let showModel: Bool
    let showReasoningEffort: Bool
    let contentFontSize: Double

    @State private var isHovering = false

    private var style: AgentVisualStyle {
        .forSource(session.visualSource)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onActivate) {
                summary
                    .frame(height: IslandMetrics.sessionRowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let interaction = session.pendingInteraction {
                PendingInteractionCard(
                    interaction: interaction,
                    responseError: responseError,
                    onRespond: { allow, answers in
                        onRespond(interaction, allow, answers)
                    },
                    onOpenAgent: onActivate
                )
                .frame(height: IslandMetrics.interactionHeight(interaction))
            }

            if showTasks, session.hasOutstandingPlanItems {
                TaskPlanCard(items: session.planItems)
                    .frame(height: IslandMetrics.planHeight(itemCount: session.planItems.count))
            }

            if showSubagents, !session.childAgentDetails.isEmpty {
                ChildAgentsCard(items: session.childAgentDetails)
                    .frame(
                        height: IslandMetrics.childAgentsHeight(
                            itemCount: session.childAgentDetails.count
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(isHovering ? 0.06 : 0.02))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .help(jumpHelp)
        .accessibilityLabel(accessibilitySummary)
    }

    private var summary: some View {
        HStack(spacing: 5) {
            AgentActivityIndicator(
                source: session.visualSource,
                style: style,
                statusColor: statusColor,
                isWorking: session.statusText == "thinking"
            )
            .frame(width: 40, height: IslandMetrics.sessionRowHeight - 14, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(rowTitle)
                        .font(.system(size: contentFontSize + 0.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(durationText)
                        .font(.system(size: 8.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.42))
                        .monospacedDigit()
                        .fixedSize()

                    Spacer(minLength: 0)
                    badges
                }

                HStack(spacing: 6) {
                    if showProjectName, let projectName {
                        Text(projectName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(projectColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(projectBackground, in: RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(projectColor.opacity(0.49), lineWidth: 1)
                            }
                    }
                    if showActivity {
                        activityLine
                            .layoutPriority(1)
                    }
                    Spacer(minLength: 0)
                }

            }
        }
        .padding(.horizontal, 9)
    }

    private var badges: some View {
        HStack(spacing: 5) {
            badge(style.name, foreground: style.color, background: style.color.opacity(0.14), border: style.color.opacity(0.53))

            if !modelBadgeText.isEmpty {
                badge(
                    modelBadgeText,
                    foreground: CoderBarPalette.metadataText,
                    background: CoderBarPalette.metadataBackground
                )
            }

            if session.childAgents > 0 {
                badge(
                    "\(session.childAgents) Agent",
                    foreground: .purple.opacity(0.9),
                    background: .purple.opacity(0.13)
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var activityLine: some View {
        HStack(spacing: 5) {
            Text(activityText)
                .lineLimit(1)
                .truncationMode(.tail)
            if session.statusText == "thinking", session.pendingInteraction == nil,
               session.lastTool != nil, let started = session.activityStartedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(ActiveToolCalls.elapsedText(since: started, now: context.date))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.42))
                        .fixedSize()
                }
            }
        }
        .font(.system(size: 10, weight: .regular))
        .foregroundStyle(activityColor)
        .help(activityText)
    }

    private var activityColor: Color {
        if activationError != nil || session.statusText == "error" { return .red }
        if session.pendingInteraction != nil { return .orange }
        return CoderBarPalette.active
    }

    private var activityText: String {
        if let activationError { return activationError }
        if session.pendingInteraction != nil { return statusFallback }
        if session.statusText == "thinking", let tool = session.lastTool, !tool.isEmpty {
            return ToolActivityLabel.label(for: tool)
        }
        if isCompleted { return "Done" }
        return statusFallback
    }

    private var userMessage: String {
        session.lastUserMessage
            ?? session.firstPrompt
            ?? "Waiting for new input"
    }

    private var projectName: String? {
        guard let cwd = session.cwd, !cwd.isEmpty else { return nil }
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    // A stable hash (unlike Swift's randomized Hasher) keeps each project's
    // color the same across sessions, row ordering, and application launches.
    private var projectHue: Double {
        let key = (projectName ?? "").precomposedStringWithCanonicalMapping.lowercased()
        let hash = key.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return Double(hash % 3600) / 3600
    }

    private var projectColor: Color {
        Color(hue: projectHue, saturation: 0.58, brightness: 1)
    }

    private var projectBackground: Color {
        Color(hue: projectHue, saturation: 1, brightness: 1).opacity(0.24)
    }

    private var rowTitle: String {
        let title = session.displayTitle
        if let projectName, title.hasPrefix(projectName + " · ") {
            return String(title.dropFirst(projectName.count + 3))
        }
        return title
    }

    private var statusFallback: String {
        if let interaction = session.pendingInteraction {
            switch interaction.kind {
            case .approval: return "Waiting for your approval"
            case .question: return "Waiting for your answer"
            case .planReview: return "Waiting for plan approval"
            }
        }
        if session.statusText == "error" { return "Failed" }
        return session.statusText == "thinking" ? "Working…" : "Waiting for input"
    }

    private var statusColor: Color {
        if session.pendingInteraction != nil { return .orange }
        if session.statusText == "error" { return .red }
        return CoderBarPalette.active
    }

    private var isCompleted: Bool {
        guard session.pendingInteraction == nil,
              session.statusText == "waiting" || session.statusText == "done"
        else { return false }
        return session.lastAssistantMessage?.isEmpty == false
    }

    private var terminalName: String {
        TerminalActivator.targetDisplayName(for: session)
    }

    private var jumpHelp: String {
        if TerminalActivator.hasPreciseJumpTarget(session) {
            return "Return to this session in \(terminalName)"
        }
        return "Open \(terminalName); the protocol does not identify the tab or split"
    }

    private var modelBadgeText: String {
        [showModel ? formattedModel : nil, showReasoningEffort ? formattedEffort : nil]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    private var formattedModel: String? {
        guard var model = session.model?.trimmingCharacters(in: .whitespacesAndNewlines),
              !model.isEmpty
        else { return nil }

        if model.lowercased().hasPrefix("claude-") {
            model.removeFirst("claude-".count)
        }
        return model
            .split(separator: "-")
            .map { part in
                let value = String(part)
                if value.lowercased() == "gpt" { return "GPT" }
                return value.prefix(1).uppercased() + value.dropFirst()
            }
            .joined(separator: "-")
    }

    private var formattedEffort: String? {
        guard let effort = session.reasoningEffort, !effort.isEmpty else { return nil }
        switch effort.lowercased() {
        case "xhigh": return "XHigh"
        case "xlow": return "XLow"
        default: return effort.prefix(1).uppercased() + effort.dropFirst()
        }
    }

    private var durationText: String {
        let seconds = max(0, Date().timeIntervalSince(session.lastActivityAt))
        if seconds < 60 { return "<1m" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600))h" }
        return "\(Int(seconds / 86_400))d"
    }

    private var accessibilitySummary: String {
        [
            session.displayTitle,
            style.name,
            terminalName,
            modelBadgeText,
            durationText,
            "You: \(userMessage)",
        ]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func badge(_ text: String, foreground: Color, background: Color, border: Color = .clear) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(background)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
    }
}

private struct PendingInteractionCard: View {
    let interaction: PendingInteraction
    let responseError: String?
    let onRespond: (Bool, [String: [String]]) -> Void
    let onOpenAgent: () -> Void

    @State private var selections: [String: Set<String>] = [:]
    @State private var customAnswers: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .foregroundStyle(accent)
                Text(interaction.title)
                    .font(.system(size: 10.8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(stateLabel)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(accent.opacity(0.94))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.13), in: Capsule())
            }

            switch interaction.kind {
            case .approval:
                approvalContent
            case .planReview:
                planContent
            case .question:
                questionContent
            }

            if let responseError {
                Text(responseError)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.red.opacity(0.86))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.075))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 0.7)
                }
        )
        .padding(.horizontal, 34)
        .padding(.bottom, 8)
    }

    private var approvalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let path = approvalFilePath {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                    Text(path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let toolName = interaction.toolName {
                        Spacer(minLength: 8)
                        Text(toolName)
                            .foregroundStyle(accent.opacity(0.8))
                    }
                }
                .font(.system(size: 9.3, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            } else {
                Text(interaction.detail ?? interaction.toolName ?? "Waiting for your decision")
                    .font(.system(size: 9.7, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            if !approvalDiffLines.isEmpty {
                ApprovalDiffPreview(lines: approvalDiffLines)
            }

            actionButtons(approveTitle: "Allow", rejectTitle: "Deny")
        }
    }

    private var planContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(interaction.detail ?? "The agent has prepared a plan and is waiting for your decision.")
                .font(.system(size: 9.7, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(2)
            actionButtons(approveTitle: "Approve plan", rejectTitle: "Request changes")
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        if interaction.canRespond {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(interaction.questions) { question in
                        questionRow(question)
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack {
                Spacer()
                Button("Submit answers") { onRespond(true, resolvedAnswers) }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)
                    .disabled(!hasCompleteAnswers)
                    .keyboardShortcut(.return, modifiers: [])
            }
        } else {
            Text(firstQuestionText)
                .font(.system(size: 9.8, weight: .medium))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(3)
            HStack {
                Text("The desktop protocol currently provides read-only status")
                    .font(.system(size: 8.8))
                    .foregroundStyle(.white.opacity(0.34))
                Spacer()
                Button("Answer in agent app", action: onOpenAgent)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)
            }
        }
    }

    private func questionRow(_ question: PendingInteraction.Question) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let header = question.header, !header.isEmpty {
                    Text(header)
                        .foregroundStyle(accent.opacity(0.86))
                }
                Text(question.text)
                    .foregroundStyle(.white.opacity(0.84))
            }
            .font(.system(size: 10.2, weight: .semibold))
            .lineLimit(2)

            if !question.options.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                        let isSelected = selections[question.id, default: []]
                            .contains(option.label)
                        Button {
                            select(option.label, for: question)
                        } label: {
                            HStack(spacing: 8) {
                                Text(optionShortcut(index, for: question))
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isSelected ? .black.opacity(0.68) : accent)
                                    .frame(width: 26)
                                Text(option.label)
                                    .font(.system(size: 9.6, weight: .semibold))
                                    .lineLimit(1)
                                if let description = option.description, !description.isEmpty {
                                    Text(description)
                                        .font(.system(size: 8.7, weight: .regular))
                                        .foregroundStyle(isSelected
                                            ? Color.black.opacity(0.55) : Color.white.opacity(0.36))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: isSelected
                                    ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 7)
                            .frame(height: 27)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.72))
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? accent : accent.opacity(0.11))
                        )
                        .help(option.description ?? option.label)
                    }
                }
            }

            TextField(
                question.options.isEmpty ? "Enter your answer" : "Custom answer (optional)",
                text: Binding(
                    get: { customAnswers[question.id, default: ""] },
                    set: { customAnswers[question.id] = $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 9.3))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private func actionButtons(approveTitle: String, rejectTitle: String) -> some View {
        HStack(spacing: 7) {
            if interaction.canRespond {
                Button {
                    onRespond(false, [:])
                } label: {
                    HStack {
                        Text(rejectTitle)
                        Spacer()
                        Text("⌘N").opacity(0.56)
                    }
                    .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button {
                    onRespond(true, [:])
                } label: {
                    HStack {
                        Text(approveTitle)
                        Spacer()
                        Text("⌘Y").opacity(0.68)
                    }
                    .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)
            } else {
                Button("Open in agent app", action: onOpenAgent)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func optionShortcut(
        _ index: Int,
        for question: PendingInteraction.Question
    ) -> String {
        guard index < 9 else { return "" }
        let isDirectShortcut = interaction.questions.count == 1 && !question.isMultiSelect
        return isDirectShortcut ? "⌘\(index + 1)" : "\(index + 1)"
    }

    private func select(_ label: String, for question: PendingInteraction.Question) {
        if question.isMultiSelect {
            var values = selections[question.id, default: []]
            if values.contains(label) { values.remove(label) } else { values.insert(label) }
            selections[question.id] = values
        } else {
            selections[question.id] = [label]
        }
    }

    private var resolvedAnswers: [String: [String]] {
        Dictionary(uniqueKeysWithValues: interaction.questions.map { question in
            var values = Array(selections[question.id, default: []]).sorted()
            let custom = customAnswers[question.id, default: ""]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !custom.isEmpty { values.append(custom) }
            return (question.id, values)
        })
    }

    private var hasCompleteAnswers: Bool {
        interaction.questions.allSatisfy { !resolvedAnswers[$0.id, default: []].isEmpty }
    }

    private var firstQuestionText: String {
        interaction.questions.first?.text ?? interaction.detail ?? "The agent is waiting for your answer."
    }

    private var approvalFilePath: String? {
        interaction.originalToolInput?["file_path"]?.stringValue
    }

    private var approvalDiffLines: [ApprovalDiffLine] {
        ApprovalDiffLine.make(from: interaction.originalToolInput)
    }

    private var accent: Color {
        switch interaction.kind {
        case .approval: return .orange
        case .question: return .cyan
        case .planReview: return .purple
        }
    }

    private var symbol: String {
        switch interaction.kind {
        case .approval: return "checkmark.shield.fill"
        case .question: return "questionmark.bubble.fill"
        case .planReview: return "list.bullet.clipboard.fill"
        }
    }

    private var stateLabel: String {
        switch interaction.kind {
        case .approval: return "APPROVE"
        case .question: return "ASK"
        case .planReview: return "PLAN"
        }
    }
}

private struct ApprovalDiffLine: Identifiable {
    enum Kind {
        case context
        case removed
        case added
    }

    let id: Int
    let lineNumber: Int?
    let kind: Kind
    let text: String

    static func make(from input: [String: AnyValue]?) -> [ApprovalDiffLine] {
        guard let input else { return [] }
        if let patch = input["patch"]?.stringValue, !patch.isEmpty {
            return makePatch(patch)
        }
        if let oldText = input["old_string"]?.stringValue,
           let newText = input["new_string"]?.stringValue {
            return makeReplacement(old: oldText, new: newText)
        }
        if let content = input["content"]?.stringValue, !content.isEmpty {
            return Array(content.components(separatedBy: "\n").prefix(8).enumerated()).map {
                ApprovalDiffLine(id: $0.offset, lineNumber: $0.offset + 1, kind: .added, text: $0.element)
            }
        }
        return []
    }

    private static func makePatch(_ patch: String) -> [ApprovalDiffLine] {
        patch.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("@@") && !$0.hasPrefix("+++") && !$0.hasPrefix("---") }
            .prefix(8)
            .enumerated()
            .map { index, raw in
                let kind: Kind
                let text: String
                if raw.hasPrefix("+") {
                    kind = .added
                    text = String(raw.dropFirst())
                } else if raw.hasPrefix("-") {
                    kind = .removed
                    text = String(raw.dropFirst())
                } else {
                    kind = .context
                    text = raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw
                }
                return ApprovalDiffLine(id: index, lineNumber: nil, kind: kind, text: text)
            }
    }

    private static func makeReplacement(old: String, new: String) -> [ApprovalDiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        var prefix = 0
        while prefix < min(oldLines.count, newLines.count), oldLines[prefix] == newLines[prefix] {
            prefix += 1
        }

        var suffix = 0
        while suffix < min(oldLines.count - prefix, newLines.count - prefix),
              oldLines[oldLines.count - suffix - 1] == newLines[newLines.count - suffix - 1] {
            suffix += 1
        }

        var result: [ApprovalDiffLine] = []
        if prefix > 0 {
            result.append(.init(
                id: result.count,
                lineNumber: prefix,
                kind: .context,
                text: oldLines[prefix - 1]
            ))
        }

        let oldEnd = oldLines.count - suffix
        if prefix < oldEnd {
            for index in prefix..<oldEnd {
                result.append(.init(
                    id: result.count,
                    lineNumber: index + 1,
                    kind: .removed,
                    text: oldLines[index]
                ))
            }
        }

        let newEnd = newLines.count - suffix
        if prefix < newEnd {
            for index in prefix..<newEnd {
                result.append(.init(
                    id: result.count,
                    lineNumber: index + 1,
                    kind: .added,
                    text: newLines[index]
                ))
            }
        }

        if suffix > 0 {
            result.append(.init(
                id: result.count,
                lineNumber: oldEnd + 1,
                kind: .context,
                text: oldLines[oldEnd]
            ))
        }
        return Array(result.prefix(8))
    }
}

private struct ApprovalDiffPreview: View {
    let lines: [ApprovalDiffLine]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(lines) { line in
                HStack(spacing: 7) {
                    Text(line.lineNumber.map(String.init) ?? "·")
                        .foregroundStyle(.white.opacity(0.24))
                        .frame(width: 20, alignment: .trailing)
                    Text(marker(for: line.kind))
                        .foregroundStyle(color(for: line.kind))
                        .frame(width: 8)
                    Text(line.text.isEmpty ? " " : line.text)
                        .foregroundStyle(color(for: line.kind).opacity(0.88))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 8.6, weight: .medium, design: .monospaced))
                .frame(height: 13)
                .padding(.horizontal, 6)
                .background(background(for: line.kind))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
        }
    }

    private func marker(for kind: ApprovalDiffLine.Kind) -> String {
        switch kind {
        case .context: return " "
        case .removed: return "−"
        case .added: return "+"
        }
    }

    private func color(for kind: ApprovalDiffLine.Kind) -> Color {
        switch kind {
        case .context: return .white.opacity(0.56)
        case .removed: return .red.opacity(0.92)
        case .added: return .green.opacity(0.92)
        }
    }

    private func background(for kind: ApprovalDiffLine.Kind) -> Color {
        switch kind {
        case .context: return .white.opacity(0.025)
        case .removed: return .red.opacity(0.08)
        case .added: return .green.opacity(0.08)
        }
    }
}

private struct TaskPlanCard: View {
    let items: [DesktopSessionDiscovery.PlanItem]

    private var completed: Int { items.filter { $0.status == "completed" }.count }
    private var inProgress: Int { items.filter { $0.status == "in_progress" }.count }
    private var pending: Int { items.filter { $0.status == "pending" }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Tasks (\(completed) done, \(inProgress) in progress, \(pending) pending)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Image(systemName: planSymbol(item.status))
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(planColor(item.status))
                        .frame(width: 11)

                    Text(item.title)
                        .font(.system(size: 10.3, weight: .medium))
                        .foregroundStyle(
                            item.status == "completed"
                                ? .white.opacity(0.32)
                                : .white.opacity(0.68)
                        )
                        .strikethrough(item.status == "completed", color: .white.opacity(0.2))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.018))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 34)
        .padding(.bottom, 8)
    }

    private func planSymbol(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.square.fill"
        case "in_progress": return "circle.fill"
        default: return "circle"
        }
    }

    private func planColor(_ status: String) -> Color {
        switch status {
        case "completed": return .white.opacity(0.3)
        case "in_progress": return .blue.opacity(0.9)
        default: return .white.opacity(0.24)
        }
    }
}

private struct ChildAgentsCard: View {
    let items: [DesktopSessionDiscovery.ChildAgent]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.purple.opacity(0.88))
                Text("Agent (\(items.count))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
            }

            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    AgentStatusDot(isWorking: item.statusText == "thinking")
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(agentTitle(item))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if !agentModel(item).isEmpty {
                                Text(agentModel(item))
                            }
                            if let tool = item.lastTool, !tool.isEmpty {
                                Text("⎿ \(ToolActivityLabel.label(for: tool))")
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                        }
                        .font(.system(size: 9.2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.34))
                        .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(agentStatus(item))
                        .font(.system(size: 9.2, weight: .medium))
                        .foregroundStyle(
                            item.statusText == "thinking"
                                ? Color.purple.opacity(0.78)
                                : Color.white.opacity(0.34)
                        )
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.018))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.purple.opacity(0.10), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 34)
        .padding(.bottom, 8)
    }

    private func agentTitle(_ item: DesktopSessionDiscovery.ChildAgent) -> String {
        let name = item.nickname ?? item.role ?? "Sub Agent"
        guard let task = item.task, !task.isEmpty else { return name }
        return "\(name) (\(task))"
    }

    private func agentModel(_ item: DesktopSessionDiscovery.ChildAgent) -> String {
        var parts: [String] = []
        if var model = item.model, !model.isEmpty {
            if model.lowercased().hasPrefix("gpt-") {
                model = "GPT-" + model.dropFirst("gpt-".count)
            }
            parts.append(model)
        }
        if let effort = item.reasoningEffort, !effort.isEmpty {
            parts.append(effort.lowercased() == "xhigh" ? "XHigh" : effort.capitalized)
        }
        return parts.joined(separator: " · ")
    }

    private func agentStatus(_ item: DesktopSessionDiscovery.ChildAgent) -> String {
        guard item.statusText == "thinking" else { return "Done" }
        let seconds = max(0, Date().timeIntervalSince(item.startedAt))
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m" }
        return "\(Int(seconds / 3_600))h"
    }
}

private struct AgentActivityIndicator: View {
    let source: String
    let style: AgentVisualStyle
    let statusColor: Color
    let isWorking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isWorking && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate / 0.84
                let opacity = 0.79 + 0.21 * cos(phase * 2 * .pi)
                indicator(dimmed: false)
                    .opacity(opacity)
            }
            // Pulse only opacity; never interpolate icon placement during window resizing.
            .transaction { $0.animation = nil }
        } else {
            indicator(dimmed: false)
        }
    }

    private func indicator(dimmed: Bool) -> some View {
        HStack(alignment: .top, spacing: 3) {
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(0..<3) { index in
                    Rectangle()
                        .fill(statusColor.opacity(0.56 + Double(index) * 0.22))
                        .frame(width: 3, height: [3.0, 4.0, 7.0][index])
                }
            }
            .frame(width: 11, height: 13, alignment: .bottom)
            AgentApplicationIcon(source: source, style: style)
                .frame(width: 15, height: 15)
        }
        .opacity(dimmed ? 0.58 : 1)
    }

}

private struct AgentStatusDot: View {
    let isWorking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isWorking && !reduceMotion {
            PhaseAnimator([false, true]) { dimmed in
                dot(opacity: dimmed ? 0.18 : 1)
            } animation: { _ in
                .easeInOut(duration: 0.42)
            }
        } else {
            dot(opacity: 1)
        }
    }

    private func dot(opacity: Double) -> some View {
        Circle()
            .fill(isWorking ? Color.purple : Color.white.opacity(0.24))
            .frame(width: 6, height: 6)
            .opacity(opacity)
            .shadow(
                color: isWorking ? Color.purple.opacity(0.65 * opacity) : .clear,
                radius: isWorking ? 3 : 0
            )
    }
}
