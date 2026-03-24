import SwiftUI

struct PaneView: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager
    @ObservedObject var panel: TerminalPanel
    @ObservedObject var workspace: Workspace
    let nodeID: UUID

    private var isFocused: Bool {
        workspace.focusedPanelID == panel.id
    }

    private var watchIcon: String {
        switch panel.watchMode {
        case .off: return "bell.slash"
        case .on: return "bell.fill"
        case .silent: return "bell"
        }
    }

    private var watchHelp: String {
        switch panel.watchMode {
        case .off: return "Notifications: off"
        case .on: return "Notifications: on"
        case .silent: return "Notifications: silent"
        }
    }

    /// Status dot color based on panel state
    private var statusColor: Color {
        if panel.needsAttention { return Theme.warning }
        if case .active = panel.activityState { return Theme.success }
        if case .exited(let code) = panel.activityState {
            return code == 0 ? Theme.textMuted : Theme.danger
        }
        return Theme.idle
    }

    private var borderColor: Color {
        if panel.needsAttention { return Theme.warning.opacity(0.5) }
        if isFocused { return Theme.focus }
        return Theme.border
    }

    private var borderWidth: CGFloat {
        if panel.needsAttention || isFocused { return Theme.borderWidthFocused }
        return Theme.borderWidth
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Title bar ──
            titleBar
            
            // ── Thin separator ──
            Theme.separator.frame(height: 0.5)

            // ── Terminal ──
            TerminalSurfaceView(
                panel: panel,
                isFocused: isFocused,
                isWorkspaceSelected: workspace.id == workspaceManager.selectedWorkspaceID,
                suppressFocus: workspace.isRenaming
            )
            .clipped()
            .onTapGesture {
                panel.clearAttention()
                workspace.focusedPanelID = panel.id
            }
        }
        .background(Theme.surfacePane)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            // Status dot
            StatusDot(
                color: statusColor,
                size: 6,
                isPulsing: panel.needsAttention
            )

            // Title or rename field
            if panel.isRenaming {
                RenameField(text: $panel.title) {
                    panel.hasCustomTitle = !panel.title.trimmingCharacters(in: .whitespaces).isEmpty
                    panel.isRenaming = false
                }
                .font(Theme.titleBarFont)
                .frame(maxWidth: 200)
            } else {
                Text(panel.title)
                    .font(Theme.titleBarFont)
                    .foregroundColor(isFocused ? Theme.textBright : Theme.textMuted)
                    .lineLimit(1)
                    .contextMenu {
                        Button("Rename") {
                            panel.isRenaming = true
                        }
                    }
            }

            Spacer()

            // Exit code badge
            if case .exited(let code) = panel.activityState {
                Text("exit \(code)")
                    .font(Theme.badgeFont)
                    .foregroundColor(code == 0 ? Theme.textMuted : Theme.danger)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(code == 0 ? Theme.surfaceHover : Theme.danger.opacity(0.15))
                    )
            }

            // Action buttons
            HStack(spacing: 0) {
                PaneTitleButton(
                    systemName: watchIcon,
                    help: watchHelp
                ) {
                    panel.watchMode = panel.watchMode.next
                }

                PaneTitleButton(systemName: "rectangle.split.2x1", help: "Split Right (⌘→)") {
                    workspace.focusedPanelID = panel.id
                    workspace.splitFocusedPane(direction: .horizontal)
                }
                PaneTitleButton(systemName: "rectangle.split.1x2", help: "Split Down (⌘↓)") {
                    workspace.focusedPanelID = panel.id
                    workspace.splitFocusedPane(direction: .vertical)
                }
                if workspace.rootNode.leafCount > 1 {
                    PaneTitleButton(systemName: "xmark", help: "Close (⌘W)") {
                        workspace.focusedPanelID = panel.id
                        workspace.closeFocusedPane()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Theme.titleBarHeight)
        .background(
            panel.needsAttention
                ? Theme.warning.opacity(0.08)
                : (isFocused ? Theme.surfaceTitlebar : Theme.surfacePane)
        )
        .onTapGesture(count: 2) {
            // Double-click title bar to zoom/unzoom (like macOS window double-click)
            workspace.focusedPanelID = panel.id
            workspace.toggleZoom()
        }
        .onTapGesture(count: 1) {
            panel.clearAttention()
            workspace.focusedPanelID = panel.id
        }
    }
}

// MARK: - Title Bar Button

struct PaneTitleButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isHovered ? Theme.textPrimary : Theme.textMuted)
                .frame(width: 24, height: 24)
                .background(isHovered ? Theme.surfaceHover : .clear)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

// MARK: - Rename Field

struct RenameField: View {
    @Binding var text: String
    var onCommit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Name", text: $text)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { onCommit() }
            .onExitCommand { onCommit() }
            .onAppear { isFocused = true }
            .onChange(of: isFocused) { _, focused in
                if !focused { onCommit() }
            }
    }
}
