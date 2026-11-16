import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 176)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(selection.title, systemImage: selection.symbol)
                        .font(.system(size: 17, weight: .semibold))
                    selectedContent
                }
                .padding(26)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 680, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.primary) { sidebarButton($0) }
            Text("CoderBar")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.horizontal, 12)
            ForEach(SettingsSection.secondary) { sidebarButton($0) }
            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.7))
    }

    private func sidebarButton(_ section: SettingsSection) -> some View {
        Button { selection = section } label: {
            Label(section.title, systemImage: section.symbol)
                .font(.system(size: 12.5, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selection == section ? Color.primary.opacity(0.10) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selection {
        case .general: generalContent
        case .integrations: integrationsContent
        case .notifications: notificationsContent
        case .display: displayContent
        case .sound: soundContent
        case .usage: usageContent
        case .shortcuts: shortcutsContent
        case .labs: labsContent
        case .about: aboutContent
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("System") {
                Toggle("Open at login", isOn: $model.launchAtLogin)
            }
            settingsGroup("Expand") {
                Toggle("Expand panel on hover", isOn: $model.hoverToExpand)
                valueSlider(
                    title: "Hover delay",
                    value: $model.hoverDelaySeconds,
                    range: 0...0.8,
                    step: 0.05,
                    suffix: "s"
                )
            }
            settingsGroup("Collapse") {
                Toggle("Collapse when pointer leaves", isOn: $model.autoCollapseOnMouseLeave)
                valueSlider(
                    title: "Alert duration",
                    value: $model.alertDwellSeconds,
                    range: 2...15,
                    step: 1,
                    suffix: "s"
                )
                Text("Clicking outside the panel always collapses it immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var integrationsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Agent sessions") {
                Text("Codex / Claude desktop sessions found: \(model.desktopSessionCount)")
                Text("Desktop apps provide the session list. Hooks add live tool, approval, and question updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            settingsGroup("Hooks") {
                Label(
                    model.hooksConfigured ? "Hooks installed" : "Hooks not installed",
                    systemImage: model.hooksConfigured ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .foregroundStyle(model.hooksConfigured ? .green : .orange)
                HStack {
                    if model.hooksConfigured {
                        Button("Reinstall", action: model.configureHooks)
                        Button("Remove", action: model.deconfigureHooks).tint(.red)
                    } else {
                        Button("Install hooks", action: model.configureHooks)
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Button("Open data folder", action: model.openDataFolder)
                }
                Text("After upgrading, click Reinstall to update agent hooks with approval response support.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let warning = model.desktopDiscoveryWarning {
                settingsGroup("Diagnostics") {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var notificationsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Alerts") {
                Toggle("Notify when an agent needs attention", isOn: $model.notificationsEnabled)
                Toggle("Expand for approvals and questions", isOn: $model.autoExpandOnAlert)
                Picker("Completion alert", selection: $model.completionPresentation) {
                    Text("Brief alert (keep collapsed)").tag("glance")
                    Text("Expand panel").tag("expand")
                }
                .pickerStyle(.radioGroup)
                Button("Send test notification", action: model.testNotification)
            }
            settingsGroup("Codex approval alerts") {
                Picker("Behavior", selection: $model.codexApprovalMode) {
                    Text("Follow focus and expand").tag("followFocus")
                    Text("Notify only").tag("notify")
                    Text("Silent").tag("silent")
                }
                .pickerStyle(.radioGroup)
                Text("Silent mode hides CoderBar alerts. It does not automatically approve requests.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var displayContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Screen") {
                Picker("Display", selection: $model.displayTargetID) {
                    ForEach(model.displayTargetOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                Text("Main display keeps the panel on the primary screen, regardless of the active app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            settingsGroup("Size and font") {
                valueSlider(title: "Panel width", value: $model.panelWidth, range: 440...800, step: 10, suffix: "pt")
                valueSlider(title: "Maximum height", value: $model.maxPanelHeight, range: 280...720, step: 10, suffix: "pt")
                valueSlider(title: "Text size", value: $model.contentFontSize, range: 10...16, step: 0.5, suffix: "pt")
            }
            settingsGroup("Session cards") {
                Toggle("Show project", isOn: $model.showProjectName)
                Toggle("Show model", isOn: $model.showModel)
                Toggle("Show reasoning effort", isOn: $model.showReasoningEffort)
                Toggle("Show tasks", isOn: $model.showTasks)
                Toggle("Show subagents", isOn: $model.showSubagents)
                Toggle("Show current activity", isOn: $model.showActivity)
            }
        }
    }

    private var soundContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Sound") {
                Toggle("Enable sounds", isOn: $model.soundsEnabled)
                valueSlider(title: "Volume", value: $model.soundVolume, range: 0...1, step: 0.05, suffix: "")
                    .disabled(!model.soundsEnabled)
            }
            settingsGroup("Events") {
                Toggle("Session started", isOn: $model.soundOnStart)
                Toggle("Session completed", isOn: $model.soundOnCompletion)
                Toggle("Approvals, questions, and plan reviews", isOn: $model.soundOnApproval)
            }
        }
    }

    private var usageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Usage card") {
                Toggle("Show Codex usage at the top", isOn: $model.showUsage)
                Picker("Percentage", selection: $model.usageShowsRemaining) {
                    Text("Used").tag(false)
                    Text("Remaining").tag(true)
                }
                .pickerStyle(.segmented)
                Text("Usage comes directly from the 5-hour and 7-day rate limit windows in Codex sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Panel shortcuts") {
                Toggle("Enable panel keyboard shortcuts", isOn: $model.panelShortcutsEnabled)
                shortcutRow("Collapse panel", key: "Esc")
                shortcutRow("Allow request / Approve plan", key: "Y")
                shortcutRow("Deny request / Request changes", key: "N")
                shortcutRow("Select and submit a single-question answer", key: "⌘1…⌘9")
                shortcutRow("Open current session", key: "T")
                Text("For multiple questions or multiple selections, review and submit answers in the card.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var labsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Updates") {
                Toggle("Receive beta updates", isOn: $model.betaUpdates)
            }
            settingsGroup("Agent App") {
                Toggle("Handle Claude approvals and questions in the panel", isOn: $model.claudeNativeApprovals)
                Toggle("Prefer Codex App for app-server sessions", isOn: $model.openAppServerSessionsInCodex)
                Text("When disabled, hooks immediately return approvals and questions to Claude.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            settingsGroup("Protocol support") {
                Label("Claude/Codex hooks: allow or deny requests", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("Claude questions: choices, custom answers, and multiple questions", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("Codex App questions: read-only; open Codex to answer", systemImage: "info.circle.fill")
                    .foregroundStyle(.orange)
                Text("CoderBar only reports success for actions supported by the protocol.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("CoderBar").font(.title3.weight(.semibold))
            Text("v\(model.appVersion)").font(.caption).foregroundStyle(.secondary)
            Text("Agent sessions at the top of your screen").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Open data folder", action: model.openDataFolder)
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 92, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(formatted(value.wrappedValue, step: step) + suffix)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func formatted(_ value: Double, step: Double) -> String {
        step < 1 ? String(format: "%.2g", value) : String(Int(value.rounded()))
    }

    private func shortcutRow(_ title: String, key: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: 11) { content() }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, integrations, notifications, display, sound, usage, shortcuts, labs, about

    var id: String { rawValue }
    static let primary: [SettingsSection] = [
        .general, .integrations, .notifications, .display, .sound, .usage, .shortcuts
    ]
    static let secondary: [SettingsSection] = [.labs, .about]

    var title: String {
        switch self {
        case .general: return "General"
        case .integrations: return "Integrations"
        case .notifications: return "Notifications"
        case .display: return "Display"
        case .sound: return "Sound"
        case .usage: return "Usage"
        case .shortcuts: return "Shortcuts"
        case .labs: return "Labs"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .integrations: return "puzzlepiece.extension.fill"
        case .notifications: return "bell.fill"
        case .display: return "textformat.size"
        case .sound: return "speaker.wave.2.fill"
        case .usage: return "chart.bar.fill"
        case .shortcuts: return "keyboard.fill"
        case .labs: return "flask.fill"
        case .about: return "info.circle.fill"
        }
    }
}
