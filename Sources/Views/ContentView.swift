import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager
    @EnvironmentObject var gitService: GitService

    var body: some View {
        HSplitView {
            // ── Left sidebar ──
            SidebarView()
                .frame(minWidth: 140, maxWidth: 220)

            // ── Main content area ──
            VStack(spacing: 0) {
                // Workspace content
                ZStack {
                    if workspaceManager.workspaces.isEmpty {
                        emptyState
                    } else {
                        ForEach(workspaceManager.workspaces) { workspace in
                            let isSelected = workspace.id == workspaceManager.selectedWorkspaceID
                            WorkspaceView(workspace: workspace)
                                .zIndex(isSelected ? 1 : 0)
                                .allowsHitTesting(isSelected)
                                .offset(x: isSelected ? 0 : 100_000)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Status bar ──
                StatusBarView()
            }

            // ── Right sidebar (Code Review) ──
            if workspaceManager.showDiffPanel {
                GitDiffPanel()
                    .frame(minWidth: Theme.rightSidebarMinWidth, maxWidth: 400)
            }
        }
        .background(Theme.surfacePrimary)
        .frame(minWidth: 800, minHeight: 500)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(Theme.textMuted)
            Text("No workspace")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Button("Create Workspace") {
                let ws = workspaceManager.createWorkspace()
                workspaceManager.selectedWorkspaceID = ws.id
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
    }
}

// MARK: - Status Bar

struct StatusBarView: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager
    @EnvironmentObject var gitService: GitService

    private var workspace: Workspace? {
        workspaceManager.selectedWorkspace
    }

    var body: some View {
        HStack(spacing: 12) {
            // Workspace name
            if let ws = workspace {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                    Text(ws.name)
                        .font(Theme.statusBarFont)
                        .foregroundColor(Theme.textSecondary)
                }

                Theme.separator
                    .frame(width: 1, height: 14)

                // Panel count
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.split.3x1")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                    Text("\(ws.panels.count) terminal\(ws.panels.count == 1 ? "" : "s")")
                        .font(Theme.statusBarFont)
                        .foregroundColor(Theme.textSecondary)
                }

                // Git branch
                if let branch = gitService.branchName {
                    Theme.separator
                        .frame(width: 1, height: 14)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent)
                        Text(branch)
                            .font(Theme.statusBarFont)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                // Activity summary
                let summary = ws.activitySummary
                if summary.active > 0 {
                    Theme.separator
                        .frame(width: 1, height: 14)

                    HStack(spacing: 4) {
                        StatusDot(color: Theme.success, size: 5)
                        Text("\(summary.active) active")
                            .font(Theme.statusBarFont)
                            .foregroundColor(Theme.success)
                    }
                }
            }

            Spacer()

            // Zoom indicator
            if let ws = workspace, ws.isZoomed {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                    Text("Zoomed")
                        .font(Theme.statusBarFont)
                }
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(Theme.accent.opacity(0.15))
                )
            }

            // Code Review toggle button
            Button(action: {
                workspaceManager.showDiffPanel.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text("Diff")
                        .font(Theme.statusBarFont)
                }
                .foregroundColor(workspaceManager.showDiffPanel ? Theme.accent : Theme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(workspaceManager.showDiffPanel ? Theme.accent.opacity(0.15) : Theme.surfaceHover)
                )
            }
            .buttonStyle(.plain)
            .help("Toggle Code Review panel")

            // Keyboard shortcut hint
            Text("⌘/ for shortcuts")
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.statusBarHeight)
        .background(Theme.surfaceSidebar)
        .overlay(alignment: .top) {
            Theme.separator.frame(height: 0.5)
        }
    }
}
