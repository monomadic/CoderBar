import SwiftUI
import AppKit
import CoderBarKit

enum IslandMetrics {
    static let expandedWidth: CGFloat = 528
    static let expandedTopBarHeight: CGFloat = 24
    static let sessionRowHeight: CGFloat = 50
    static let expandedBottomInset: CGFloat = 0
    static let expandedListTopInset: CGFloat = 5
    static let idleHeight: CGFloat = 132
    static let maxExpandedHeight: CGFloat = 482

    static func interactionHeight(_ interaction: PendingInteraction?) -> CGFloat {
        guard let interaction else { return 0 }
        switch interaction.kind {
        case .approval:
            let input = interaction.originalToolInput
            let hasDiff = input?["old_string"]?.stringValue != nil
                || input?["new_string"]?.stringValue != nil
                || input?["content"]?.stringValue != nil
                || input?["patch"]?.stringValue != nil
            return hasDiff ? 198 : 126
        case .planReview:
            return 132
        case .question:
            let questionsHeight = interaction.questions.reduce(CGFloat.zero) { total, question in
                total + 50 + CGFloat(min(question.options.count, 5)) * 31
            }
            return min(360, max(166, 82 + questionsHeight))
        }
    }

    static func planHeight(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        return 34 + CGFloat(itemCount) * 22
    }

    static func childAgentsHeight(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        return 34 + CGFloat(itemCount) * 43
    }

    static func rowHeight(
        _ session: SessionStore.Session,
        showTasks: Bool = true,
        showSubagents: Bool = true
    ) -> CGFloat {
        sessionRowHeight
            + interactionHeight(session.pendingInteraction)
            + (showTasks && session.hasOutstandingPlanItems
                ? planHeight(itemCount: session.planItems.count)
                : 0)
            + (showSubagents ? childAgentsHeight(itemCount: session.childAgentDetails.count) : 0)
    }

    static func expandedHeight(
        sessions: [SessionStore.Session],
        showTasks: Bool = true,
        showSubagents: Bool = true,
        headerHeight: CGFloat = expandedTopBarHeight,
        maxHeight: CGFloat = maxExpandedHeight
    ) -> CGFloat {
        guard !sessions.isEmpty else { return idleHeight + headerHeight - expandedTopBarHeight }
        let contentHeight = headerHeight
            + sessions.reduce(0) {
                $0 + rowHeight($1, showTasks: showTasks, showSubagents: showSubagents)
            }
            + expandedBottomInset + expandedListTopInset
        return min(contentHeight, maxHeight)
    }
}

struct IslandView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var island: NotchViewModel

    private var activeSessions: [SessionStore.Session] {
        (model.store?.visibleActiveSessions ?? [])
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    var body: some View {
        ZStack(alignment: .top) {
            panelBackground(
                topRadius: 0,
                bottomRadius: surfaceRadius
            )

            if island.isExpanded {
                expandedPanel
                    .frame(width: model.panelWidth)
                    .transition(expandedContentTransition)
            } else {
                collapsedIsland
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(
            TopAttachedPanelShape(
                topRadius: 0,
                bottomRadius: surfaceRadius
            )
        )
        .contentShape(
            TopAttachedPanelShape(
                topRadius: 0,
                bottomRadius: surfaceRadius
            )
        )
    }

    private var surfaceRadius: CGFloat {
        island.isExpanded ? 20 : 12
    }

    private var expandedContentTransition: AnyTransition {
        .opacity
    }

    @ViewBuilder
    private func panelBackground(topRadius: CGFloat, bottomRadius: CGFloat) -> some View {
        if island.isExpanded {
            TopAttachedPanelShape(topRadius: topRadius, bottomRadius: bottomRadius)
                .fill(Color(white: 4.0 / 255.0))
        } else {
            TopAttachedPanelShape(topRadius: topRadius, bottomRadius: bottomRadius)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    TopAttachedPanelShape(topRadius: topRadius, bottomRadius: bottomRadius)
                        .fill(Color.black.opacity(0.35))
                }
        }
    }

    private var expandedPanel: some View {
        VStack(spacing: 0) {
            panelTopBar
                .frame(height: island.expandedHeaderHeight)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.22)).frame(height: 1)
                }

            if let store = model.store, !activeSessions.isEmpty {
                SessionDashboard(store: store, island: island)
            } else {
                idleState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panelTopBar: some View {
        HStack(spacing: 6) {
            topBarAgentIcon

            if model.showUsage {
                if codexRateLimitWindows.isEmpty {
                    Text("7d —")
                        .foregroundStyle(.white.opacity(0.28))
                } else {
                    ForEach(Array(codexRateLimitWindows.enumerated()), id: \.offset) { index, window in
                        if index > 0 {
                            Text("|")
                                .foregroundStyle(.white.opacity(0.26))
                        }
                        Text(rateLimitLabel(window.windowMinutes))
                            .foregroundStyle(.white.opacity(0.88))
                        Text("\(usagePercent(window))%")
                            .foregroundStyle(rateLimitColor(window.usedPercent))
                    }
                }
            }

            Spacer(minLength: 16)

            Button {
                model.soundsEnabled.toggle()
            } label: {
                Image(systemName: model.soundsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .frame(width: 18, height: 18)
            }
            .help(model.soundsEnabled ? "Mute sounds" : "Enable sounds")

            Button {
                SettingsWindowController.shared.show(model: model)
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 18, height: 18)
            }
            .help("Settings")
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.68))
        .padding(.horizontal, 15)
    }

    private var topBarAgentIcon: some View {
        let style = AgentVisualStyle.forSource(activeSessions.first?.visualSource)
        return AgentApplicationIcon(
            source: activeSessions.first?.visualSource,
            style: style
        )
        .frame(width: 15, height: 15)
    }

    private var codexRateLimitWindows: [DesktopSessionDiscovery.RateLimitWindow] {
        activeSessions
            .first(where: { $0.source == "codex" })?
            .rateLimitWindows ?? []
    }

    private func rateLimitLabel(_ minutes: Int) -> String {
        if minutes % (24 * 60) == 0 { return "\(minutes / (24 * 60))d" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    private func rateLimitColor(_ percent: Double) -> Color {
        switch percent {
        case 90...: return .red
        case 70...: return .orange
        default: return Color(red: 0.12, green: 0.95, blue: 0.34)
        }
    }

    private func usagePercent(_ window: DesktopSessionDiscovery.RateLimitWindow) -> Int {
        let used = min(max(window.usedPercent, 0), 100)
        return Int((model.usageShowsRemaining ? 100 - used : used).rounded())
    }

    private var idleState: some View {
        VStack(spacing: 7) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(.white.opacity(0.28))

            Text("Waiting for sessions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.43))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 9)
    }

    private var collapsedIsland: some View {
        Button {
            if NSEvent.modifierFlags.contains(.option) {
                island.cycle()
            } else {
                island.toggle()
            }
        } label: {
            collapsedIslandContent
                .frame(
                    width: island.compactWidth,
                    height: island.compactHeight
                )
                .contentShape(
                    TopAttachedPanelShape(topRadius: 0, bottomRadius: 12)
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .simultaneousGesture(dragGesture)
        .contextMenu { islandMenu }
        .help("Expand CoderBar")
    }

    private var collapsedIslandContent: some View {
        HStack(spacing: 0) {
            collapsedAgentMarks
                .padding(.horizontal, 8)
                .frame(width: island.compactLeftWidth)

            Color.clear
                .frame(width: island.compactNotchWidth)
                .accessibilityHidden(true)

            Text("\(activeSessions.count)")
                .font(.system(size: 10, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(white: 0.20), in: Capsule())
                .padding(.horizontal, 8)
                .frame(width: island.compactRightWidth)
                .accessibilityLabel("Sessions: \(activeSessions.count)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collapsedAgentMarks: some View {
        Group {
            if let session = activeSessions.first {
                CompactSessionMarks(session: session)
            } else {
                CompactFallbackMark()
            }
        }
        .frame(width: 31, alignment: .leading)
    }

    private var islandMenu: some View {
        VStack {
            Button {
                SettingsWindowController.shared.show(model: model)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            if model.hooksConfigured {
                Button("Remove hooks", action: model.deconfigureHooks)
            } else {
                Button("Install hooks", action: model.configureHooks)
            }
            Divider()
            Button("Quit CoderBar") { NSApp.terminate(nil) }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                island.dragBegan()
                island.dragMoved(value.translation)
            }
            .onEnded { _ in island.dragEnded() }
    }

}

private struct CompactSessionMarks: View {
    let session: SessionStore.Session

    private var style: AgentVisualStyle {
        .forSource(session.visualSource)
    }

    private var isWorking: Bool {
        session.statusText == "thinking"
    }

    var body: some View {
        HStack(spacing: 4) {
            AgentApplicationIcon(source: session.visualSource, style: style)
                .frame(width: 15, height: 15)

            CompactActivityIndicator(
                color: style.color,
                statusColor: session.pendingInteraction == nil
                    ? CoderBarPalette.active : .orange,
                isWorking: isWorking
            )
            .frame(width: 11, height: 11)
        }
        .accessibilityHidden(true)
    }
}

struct AgentApplicationIcon: View {
    let source: String?
    let style: AgentVisualStyle

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            icon(side: side)
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Use the installed application's current artwork, with a packaged fallback.
    private static let chatGPTIcon: NSImage = {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        if let url = Bundle.main.url(forResource: "ChatGPT", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }()

    @ViewBuilder
    private func icon(side: CGFloat) -> some View {
        switch source {
        case "codex":
            Image(nsImage: Self.chatGPTIcon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        case "claude", "claude_desktop":
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
                    .fill(Color(red: 0.87, green: 0.38, blue: 0.24))
                Image(systemName: "sparkle")
                    .font(.system(size: side * 0.53, weight: .bold))
                    .foregroundStyle(.white)
            }
        default:
            Image(systemName: style.symbol)
                .font(.system(size: side * 0.57, weight: .bold))
                .foregroundStyle(style.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color.white.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: side * 0.27)
                )
        }
    }
}

private struct CompactActivityIndicator: View {
    let color: Color
    let statusColor: Color
    let isWorking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isWorking && !reduceMotion {
            TimelineView(.animation(minimumInterval: 0.10)) { timeline in
                CompactPixelSpinner(
                    color: color,
                    phase: Int(timeline.date.timeIntervalSinceReferenceDate * 10) % 8
                )
            }
        } else {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
                .shadow(color: statusColor.opacity(0.62), radius: 2.5)
        }
    }
}

private struct CompactPixelSpinner: View {
    let color: Color
    let phase: Int

    private let positions: [(Int, Int)] = [
        (1, 0), (2, 0), (2, 1), (2, 2),
        (1, 2), (0, 2), (0, 1), (0, 0)
    ]

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 3
            for trail in 0..<4 {
                let index = (phase - trail + positions.count) % positions.count
                let position = positions[index]
                let rect = CGRect(
                    x: CGFloat(position.0) * unit,
                    y: CGFloat(position.1) * unit,
                    width: max(1, unit - 0.55),
                    height: max(1, unit - 0.55)
                )
                context.opacity = 1 - Double(trail) * 0.22
                context.fill(Path(rect), with: .color(color))
            }
        }
        .shadow(color: color.opacity(0.72), radius: 2.5)
    }
}

private struct CompactFallbackMark: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.blue)
                .frame(width: 15, height: 15)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 4))
            Circle()
                .fill(Color.white.opacity(0.26))
                .frame(width: 5, height: 5)
        }
        .accessibilityHidden(true)
    }
}

struct TopAttachedPanelShape: InsettableShape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var insetAmount: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(topRadius, bottomRadius), insetAmount) }
        set {
            topRadius = newValue.first.first
            bottomRadius = newValue.first.second
            insetAmount = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let top = min(topRadius, insetRect.width / 2, insetRect.height / 2)
        let bottom = min(bottomRadius, insetRect.width / 2, insetRect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: insetRect.minX + top, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX - top, y: insetRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.maxX, y: insetRect.minY + top),
            control: CGPoint(x: insetRect.maxX, y: insetRect.minY)
        )
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.maxX - bottom, y: insetRect.maxY),
            control: CGPoint(x: insetRect.maxX, y: insetRect.maxY)
        )
        path.addLine(to: CGPoint(x: insetRect.minX + bottom, y: insetRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.minX, y: insetRect.maxY - bottom),
            control: CGPoint(x: insetRect.minX, y: insetRect.maxY)
        )
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.minX + top, y: insetRect.minY),
            control: CGPoint(x: insetRect.minX, y: insetRect.minY)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> TopAttachedPanelShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

enum CoderBarPalette {
    static let active = Color(red: 0.12, green: 0.95, blue: 0.34)
    static let metadataText = Color(white: 223.0 / 255)
    static let metadataBackground = Color.white.opacity(0.08)
    static let codex = Color(red: 158.0 / 255, green: 133.0 / 255, blue: 1)
}

struct AgentVisualStyle {
    let name: String
    let symbol: String
    let color: Color

    static func forSource(_ source: String?) -> AgentVisualStyle {
        switch source {
        case "claude":
            return .init(name: "Claude Code", symbol: "sparkles", color: .orange)
        case "claude_desktop":
            return .init(name: "Claude", symbol: "sparkles", color: .orange)
        case "codex":
            return .init(name: "Codex", symbol: "chevron.left.forwardslash.chevron.right", color: CoderBarPalette.codex)
        case "gemini":
            return .init(name: "Gemini", symbol: "star.fill", color: .purple)
        case "cursor":
            return .init(name: "Cursor", symbol: "cursorarrow", color: .cyan)
        case "devin":
            return .init(name: "Devin", symbol: "hammer.fill", color: .pink)
        default:
            return .init(name: "Agent", symbol: "terminal.fill", color: CoderBarPalette.active)
        }
    }
}
