import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var workspace: Workspace

    var body: some View {
        ZStack {
            Theme.surfacePrimary.ignoresSafeArea()

            if workspace.isZoomed, let focusedID = workspace.focusedPanelID,
               let panel = workspace.panels[focusedID] {
                PaneView(panel: panel, workspace: workspace, nodeID: UUID())
                    .padding(Theme.splitGap)
            } else {
                SplitNodeView(node: workspace.rootNode, workspace: workspace)
                    .padding(Theme.splitGap)
            }
        }
    }
}
