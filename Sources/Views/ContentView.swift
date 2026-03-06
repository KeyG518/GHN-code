import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack {
                if workspaceManager.workspaces.isEmpty {
                    emptyState
                } else {
                    // Render ALL workspaces to keep terminal NSViews alive in the
                    // window hierarchy. Non-selected workspaces are moved offscreen
                    // (not opacity 0, which SwiftUI optimizes away).
                    ForEach(workspaceManager.workspaces) { workspace in
                        let isSelected = workspace.id == workspaceManager.selectedWorkspaceID
                        WorkspaceView(workspace: workspace)
                            .zIndex(isSelected ? 1 : 0)
                            .allowsHitTesting(isSelected)
                            .offset(x: isSelected ? 0 : 100_000)
                    }
                }
            }
            .toolbar {}
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No workspace")
                .foregroundStyle(.secondary)
            Button("Create Workspace") {
                let ws = workspaceManager.createWorkspace()
                workspaceManager.selectedWorkspaceID = ws.id
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
