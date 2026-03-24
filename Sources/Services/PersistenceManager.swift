import Foundation

// MARK: - Snapshot Types

struct AppSnapshot: Codable {
    let workspaces: [WorkspaceSnapshot]
    let selectedWorkspaceID: UUID?
}

struct WorkspaceSnapshot: Codable {
    let id: UUID
    let name: String
    let rootNode: SplitNodeSnapshot
    let focusedPanelID: UUID?
    let panels: [PanelSnapshot]
}

struct SplitNodeSnapshot: Codable {
    let id: UUID
    let type: NodeType

    indirect enum NodeType: Codable {
        case leaf(panelID: UUID)
        case split(direction: SplitDirection, ratio: CGFloat, first: SplitNodeSnapshot, second: SplitNodeSnapshot)
    }
}

struct PanelSnapshot: Codable {
    let id: UUID
    let title: String
    let hasCustomTitle: Bool
    let workingDirectory: String?
    let command: String?
    let watchMode: WatchMode
    let scrollback: String?

    init(id: UUID, title: String, hasCustomTitle: Bool, workingDirectory: String?, command: String?, watchMode: WatchMode, scrollback: String?) {
        self.id = id
        self.title = title
        self.hasCustomTitle = hasCustomTitle
        self.workingDirectory = workingDirectory
        self.command = command
        self.watchMode = watchMode
        self.scrollback = scrollback
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        hasCustomTitle = try container.decodeIfPresent(Bool.self, forKey: .hasCustomTitle) ?? false
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        watchMode = try container.decodeIfPresent(WatchMode.self, forKey: .watchMode) ?? .off
        scrollback = try container.decodeIfPresent(String.self, forKey: .scrollback)
    }
}

// MARK: - PersistenceManager

@MainActor
final class PersistenceManager {
    static let shared = PersistenceManager()

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ghnDir = appSupport.appendingPathComponent("GHN-code", isDirectory: true)
        try? FileManager.default.createDirectory(at: ghnDir, withIntermediateDirectories: true)
        return ghnDir.appendingPathComponent("state.json")
    }()

    func save(workspaceManager: WorkspaceManager) {
        let snapshot = AppSnapshot(
            workspaces: workspaceManager.workspaces.map { snapshotWorkspace($0) },
            selectedWorkspaceID: workspaceManager.selectedWorkspaceID
        )
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("GHN-code: failed to save state: \(error)")
        }
    }

    func restore(into manager: WorkspaceManager) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            manager.createWorkspace()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: data)

            if snapshot.workspaces.isEmpty {
                manager.createWorkspace()
                return
            }

            for ws in snapshot.workspaces {
                let workspace = restoreWorkspace(ws)
                manager.addRestoredWorkspace(workspace)
            }
            manager.selectedWorkspaceID = snapshot.selectedWorkspaceID ?? manager.workspaces.first?.id

            // Set counter past any existing "Workspace N" names to avoid duplicates
            for ws in snapshot.workspaces {
                if ws.name.hasPrefix("Workspace "),
                   let num = Int(ws.name.dropFirst("Workspace ".count)) {
                    manager.nextWorkspaceNumber = max(manager.nextWorkspaceNumber, num + 1)
                }
            }
        } catch {
            print("GHN-code: failed to restore state: \(error)")
            manager.createWorkspace()
        }
    }

    // MARK: - Snapshot Helpers

    private func snapshotWorkspace(_ workspace: Workspace) -> WorkspaceSnapshot {
        let panelSnapshots = workspace.panels.values.map { panel -> PanelSnapshot in
            // Get live CWD from running process if possible
            let liveCWD: String?
            if let tv = panel.terminalView as? GHNTerminalView {
                liveCWD = getProcessCWD(pid: tv.process.shellPid) ?? panel.workingDirectory
            } else {
                liveCWD = panel.workingDirectory
            }

            // Only save scrollback if user has run commands (avoids accumulating empty prompts on restart)
            let scrollback = panel.hasHadActivity
                ? (panel.terminalView as? GHNTerminalView)?.getScrollbackText()
                : nil

            return PanelSnapshot(
                id: panel.id,
                title: panel.title,
                hasCustomTitle: panel.hasCustomTitle,
                workingDirectory: liveCWD,
                command: panel.command,
                watchMode: panel.watchMode,
                scrollback: scrollback
            )
        }

        return WorkspaceSnapshot(
            id: workspace.id,
            name: workspace.name,
            rootNode: snapshotNode(workspace.rootNode),
            focusedPanelID: workspace.focusedPanelID,
            panels: panelSnapshots
        )
    }

    private func snapshotNode(_ node: SplitNode) -> SplitNodeSnapshot {
        switch node.content {
        case .leaf(let panelID):
            return SplitNodeSnapshot(id: node.id, type: .leaf(panelID: panelID))
        case .split(let direction, let ratio, let first, let second):
            return SplitNodeSnapshot(
                id: node.id,
                type: .split(
                    direction: direction,
                    ratio: ratio,
                    first: snapshotNode(first),
                    second: snapshotNode(second)
                )
            )
        }
    }

    private func restoreWorkspace(_ snapshot: WorkspaceSnapshot) -> Workspace {
        let (node, panelIDs) = restoreNode(snapshot.rootNode)
        let workspace = Workspace(id: snapshot.id, name: snapshot.name, rootNode: node)
        let panelsByID = Dictionary(uniqueKeysWithValues: snapshot.panels.map { ($0.id, $0) })

        for panelID in panelIDs {
            let panelSnap = panelsByID[panelID]
            let panel = TerminalPanel(
                id: panelID,
                title: panelSnap?.title ?? "Terminal",
                command: panelSnap?.command,
                workingDirectory: panelSnap?.workingDirectory
            )
            panel.watchMode = panelSnap?.watchMode ?? .off
            panel.hasCustomTitle = panelSnap?.hasCustomTitle ?? false
            panel.scrollbackToRestore = panelSnap?.scrollback
            if panelSnap?.scrollback != nil { panel.hasHadActivity = true }
            workspace.addPanel(panel)
        }

        workspace.focusedPanelID = snapshot.focusedPanelID ?? panelIDs.first
        return workspace
    }

    private func restoreNode(_ snapshot: SplitNodeSnapshot) -> (SplitNode, [UUID]) {
        switch snapshot.type {
        case .leaf(let panelID):
            return (SplitNode(id: snapshot.id, content: .leaf(panelID: panelID)), [panelID])
        case .split(let direction, let ratio, let first, let second):
            let (firstNode, firstIDs) = restoreNode(first)
            let (secondNode, secondIDs) = restoreNode(second)
            let node = SplitNode(
                id: snapshot.id,
                content: .split(direction: direction, ratio: ratio, first: firstNode, second: secondNode)
            )
            return (node, firstIDs + secondIDs)
        }
    }
}
