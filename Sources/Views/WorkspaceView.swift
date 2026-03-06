import SwiftUI

private let bgWorkspace = Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))

struct WorkspaceView: View {
    @ObservedObject var workspace: Workspace

    var body: some View {
        ZStack {
            bgWorkspace.ignoresSafeArea()

            if workspace.isZoomed, let focusedID = workspace.focusedPanelID,
               let panel = workspace.panels[focusedID] {
                PaneView(panel: panel, workspace: workspace, nodeID: UUID())
                    .padding(4)
            } else {
                SplitNodeView(node: workspace.rootNode, workspace: workspace)
                    .padding(4)
            }
        }
    }
}
