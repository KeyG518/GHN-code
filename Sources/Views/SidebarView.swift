import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager

    var body: some View {
        VStack(spacing: 0) {
            // ── Sidebar header ──
            HStack {
                Text("Workspaces")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Button(action: {
                    let ws = workspaceManager.createWorkspace()
                    workspaceManager.selectedWorkspaceID = ws.id
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .frame(width: 24, height: 24)
                        .background(Theme.surfaceHover)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .help("New Workspace (⇧⌘T)")
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // ── Workspace list ──
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(workspaceManager.workspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            isSelected: workspace.id == workspaceManager.selectedWorkspaceID
                        )
                        .onTapGesture {
                            workspaceManager.selectedWorkspaceID = workspace.id
                        }
                        .contextMenu {
                            Button("Rename") {
                                workspace.isRenaming = true
                            }
                            Divider()
                            Button("Close Workspace", role: .destructive) {
                                workspaceManager.deleteWorkspace(id: workspace.id)
                            }
                            .disabled(workspaceManager.workspaces.count <= 1)
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .frame(minWidth: Theme.sidebarMinWidth)
        .background(Theme.surfaceSidebar)
    }
}

// MARK: - Workspace Row

struct WorkspaceRow: View {
    @ObservedObject var workspace: Workspace
    var isSelected: Bool = false
    @State private var isHovered: Bool = false

    /// Status dot color based on workspace activity
    private var statusColor: Color {
        let summary = workspace.activitySummary
        if summary.attention > 0 { return Theme.warning }
        if summary.active > 0 { return Theme.success }
        return Theme.idle
    }

    /// Whether the status dot should pulse (attention needed)
    private var shouldPulse: Bool {
        workspace.activitySummary.attention > 0
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator dot
            StatusDot(
                color: statusColor,
                size: 6,
                isPulsing: shouldPulse
            )

            // Workspace name
            if workspace.isRenaming {
                RenameField(text: $workspace.name) {
                    workspace.isRenaming = false
                }
                .font(Theme.labelSmallFont)
                .frame(maxWidth: 120)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.name)
                        .font(Theme.labelSmallFont)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Theme.textBright : (isHovered ? Theme.textPrimary : Theme.textSecondary))

                    // Panel count subtitle
                    let count = workspace.panels.count
                    if count > 1 {
                        Text("\(count) terminals")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }

            Spacer()

            // Activity count badge (only for attention)
            let summary = workspace.activitySummary
            if summary.attention > 0 {
                Text("\(summary.attention)")
                    .font(Theme.badgeFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Theme.warning)
                    )
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusRow)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected { return Theme.surfaceSelected }
        if isHovered { return Theme.surfaceHover }
        return .clear
    }
}
