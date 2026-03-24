import Foundation
import Combine

@MainActor
final class WorkspaceManager: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceID: UUID?
    @Published var showDiffPanel: Bool = false

    private var workspaceCancellables: [UUID: AnyCancellable] = [:]
    var nextWorkspaceNumber = 1
    var hasInitialized = false

    var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    @discardableResult
    func createWorkspace(name: String? = nil) -> Workspace {
        let workspace = Workspace(name: name ?? "Workspace \(nextWorkspaceNumber)")
        nextWorkspaceNumber += 1
        workspaces.append(workspace)
        workspaceCancellables[workspace.id] = workspace.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        if selectedWorkspaceID == nil {
            selectedWorkspaceID = workspace.id
        }
        return workspace
    }

    func addRestoredWorkspace(_ workspace: Workspace) {
        workspaces.append(workspace)
        workspaceCancellables[workspace.id] = workspace.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    func deleteWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        workspaceCancellables.removeValue(forKey: id)
        if selectedWorkspaceID == id {
            selectedWorkspaceID = workspaces.first?.id
        }
    }

    func renameWorkspace(id: UUID, name: String) {
        if let workspace = workspaces.first(where: { $0.id == id }) {
            workspace.name = name
        }
    }

    func selectWorkspace(at index: Int) {
        guard index >= 0, index < workspaces.count else { return }
        selectedWorkspaceID = workspaces[index].id
    }

    func selectNextWorkspace() {
        guard let currentID = selectedWorkspaceID,
              let index = workspaces.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIndex = (index + 1) % workspaces.count
        selectedWorkspaceID = workspaces[nextIndex].id
    }

    func selectPreviousWorkspace() {
        guard let currentID = selectedWorkspaceID,
              let index = workspaces.firstIndex(where: { $0.id == currentID }) else { return }
        let prevIndex = (index - 1 + workspaces.count) % workspaces.count
        selectedWorkspaceID = workspaces[prevIndex].id
    }
}
