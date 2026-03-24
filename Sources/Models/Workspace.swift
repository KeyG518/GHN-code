import Foundation
import Combine
import SwiftTerm

@MainActor
final class Workspace: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var rootNode: SplitNode
    @Published var panels: [UUID: TerminalPanel] = [:]
    @Published var focusedPanelID: UUID? {
        didSet {
            if let id = focusedPanelID, let panel = panels[id] {
                panel.clearAttention()
            }
        }
    }
    @Published var isZoomed: Bool = false
    @Published var isRenaming: Bool = false

    private var panelCancellables: [UUID: AnyCancellable] = [:]

    struct ActivitySummary: Equatable {
        var active: Int = 0
        var idle: Int = 0
        var exited: Int = 0
        var attention: Int = 0
    }

    var activitySummary: ActivitySummary {
        var summary = ActivitySummary()
        for panel in panels.values {
            if panel.needsAttention {
                summary.attention += 1
            }
            switch panel.activityState {
            case .active: summary.active += 1
            case .idle: summary.idle += 1
            case .exited: summary.exited += 1
            }
        }
        return summary
    }

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name

        let panel = TerminalPanel()
        let root = SplitNode.leaf(panelID: panel.id)
        self.rootNode = root
        self.focusedPanelID = panel.id
        addPanel(panel)
    }

    /// Init for restoring from persistence — no default panel created.
    init(id: UUID, name: String, rootNode: SplitNode) {
        self.id = id
        self.name = name
        self.rootNode = rootNode
    }

    // MARK: - Panel Management

    func addPanel(_ panel: TerminalPanel) {
        panels[panel.id] = panel
        panelCancellables[panel.id] = panel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    private func removePanel(_ panel: TerminalPanel) {
        panelCancellables.removeValue(forKey: panel.id)
        panels.removeValue(forKey: panel.id)
    }

    // MARK: - Split Operations

    func splitFocusedPane(direction: SplitDirection) {
        guard let panelID = focusedPanelID else { return }

        // Inherit working directory: try reading from running process first, fall back to stored value
        var cwd = panels[panelID]?.workingDirectory
        if let tv = panels[panelID]?.terminalView as? GHNTerminalView,
           let process = tv.process {
            let pid = process.shellPid
            if pid != 0, let processCWD = getProcessCWD(pid: pid) {
                cwd = processCWD
            }
        }
        let newPanel = TerminalPanel(workingDirectory: cwd)

        addPanel(newPanel)
        rootNode = rootNode.splitting(panelID: panelID, direction: direction, newPanelID: newPanel.id)
        focusedPanelID = newPanel.id
    }

    func closeFocusedPane() {
        guard let panelID = focusedPanelID else { return }
        guard rootNode.leafCount > 1 else { return }

        let allBefore = rootNode.allPanelIDs
        guard let index = allBefore.firstIndex(of: panelID) else { return }

        if let newRoot = rootNode.removing(panelID: panelID) {
            rootNode = newRoot

            if let panel = panels[panelID] {
                removePanel(panel)
            }

            let remaining = rootNode.allPanelIDs
            let newFocusIndex = min(index, remaining.count - 1)
            focusedPanelID = remaining[newFocusIndex]
        }
    }

    func updateRatio(nodeID: UUID, ratio: CGFloat) {
        rootNode = rootNode.withRatio(nodeID: nodeID, ratio: ratio)
    }

    // MARK: - Navigation

    func focusAdjacentPane(direction: NavigationDirection) {
        guard let current = focusedPanelID else { return }
        if let adjacent = rootNode.adjacentPanel(to: current, direction: direction) {
            focusedPanelID = adjacent
        }
    }

    func focusNextPane() {
        guard let current = focusedPanelID else { return }
        let all = rootNode.allPanelIDs
        guard let index = all.firstIndex(of: current) else { return }
        let nextIndex = (index + 1) % all.count
        focusedPanelID = all[nextIndex]
    }

    func toggleZoom() {
        isZoomed.toggle()
    }
}
