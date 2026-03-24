import SwiftUI
import Combine

@main
struct GHNCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var workspaceManager = WorkspaceManager()
    @StateObject private var activityDetector = ActivityDetector()
    @StateObject private var gitService = GitService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspaceManager)
                .environmentObject(activityDetector)
                .environmentObject(gitService)
                .preferredColorScheme(.dark)
                .onAppear {
                    guard !workspaceManager.hasInitialized else { return }
                    workspaceManager.hasInitialized = true

                    NSApp.appearance = NSAppearance(named: .darkAqua)
                    activityDetector.start(workspaceManager: workspaceManager)
                    activityDetector.gitService = gitService
                    PersistenceManager.shared.restore(into: workspaceManager)

                    // Start git polling
                    gitService.startPolling()

                    // Initial CWD detection
                    updateGitDirectory()

                    // Autosave every 30 seconds
                    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak workspaceManager] _ in
                        guard let manager = workspaceManager else { return }
                        Task { @MainActor in
                            PersistenceManager.shared.save(workspaceManager: manager)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    PersistenceManager.shared.save(workspaceManager: workspaceManager)
                    gitService.stopPolling()
                }
                // Track focused panel changes to update git CWD
                .onReceive(workspaceManager.objectWillChange) { _ in
                    updateGitDirectory()
                }
        }
        .commands {
            AppCommands(workspaceManager: workspaceManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }

    /// Read the focused terminal's CWD and update GitService.
    private func updateGitDirectory() {
        guard let workspace = workspaceManager.selectedWorkspace,
              let focusedID = workspace.focusedPanelID,
              let panel = workspace.panels[focusedID] else { return }

        // Try to get the live CWD from the running process
        if let tv = panel.terminalView as? GHNTerminalView,
           let process = tv.process {
            let pid = process.shellPid
            if pid != 0, let cwd = getProcessCWD(pid: pid) {
                gitService.updateDirectory(cwd)
                return
            }
        }
        // Fall back to stored working directory
        if let cwd = panel.workingDirectory {
            gitService.updateDirectory(cwd)
        }
    }
}
