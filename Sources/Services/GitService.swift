import Foundation

// MARK: - Git Error

enum GitError: Error {
    case commandFailed(status: Int32, stderr: String)
    case notARepository
    case gitNotFound
}

// MARK: - Git Service

@MainActor
final class GitService: ObservableObject {
    @Published var branchName: String?
    @Published var repoRoot: String?
    @Published var isGitRepo: Bool = false
    @Published var fileChanges: [GitFileChange] = []
    @Published var isLoading: Bool = false

    /// Per-file diff text, keyed by file path. Populated on demand.
    @Published var expandedDiffs: [String: [DiffHunk]] = [:]

    private var currentDirectory: String?
    private var refreshTimer: Timer?

    // MARK: - Directory Tracking

    /// Call when the focused terminal's working directory changes.
    func updateDirectory(_ directory: String?) {
        guard directory != currentDirectory else { return }
        currentDirectory = directory
        expandedDiffs.removeAll()
        Task { await refresh() }
    }

    // MARK: - Polling

    func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Refresh

    /// Full refresh: detect repo, get branch, status, and line counts.
    func refresh() async {
        guard let dir = currentDirectory else {
            clearState()
            return
        }

        // Detect repo root
        guard let root = await detectRepoRoot(for: dir) else {
            clearState()
            return
        }

        repoRoot = root
        isGitRepo = true

        // Run branch, status, and numstat in parallel
        async let branchResult = runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: root)
        async let statusResult = runGit(["status", "--porcelain=v1"], in: root)
        async let numstatResult = runGit(["diff", "HEAD", "--numstat"], in: root)

        let branch = try? await branchResult
        let status = try? await statusResult
        let numstat = try? await numstatResult

        branchName = branch?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse file changes
        var changes = GitParser.parseStatusPorcelain(status ?? "")

        // Merge line counts from numstat
        let lineCounts = GitParser.parseNumstat(numstat ?? "")
        for i in changes.indices {
            if let counts = lineCounts[changes[i].path] {
                changes[i].linesAdded = counts.added
                changes[i].linesDeleted = counts.deleted
            }
        }

        // Sort: modified first, then added, deleted, untracked
        changes.sort { a, b in
            statusOrder(a.status) < statusOrder(b.status)
        }

        fileChanges = changes

        // Prune expanded diffs for files no longer changed
        let activePaths = Set(changes.map(\.path))
        for key in expandedDiffs.keys where !activePaths.contains(key) {
            expandedDiffs.removeValue(forKey: key)
        }
    }

    // MARK: - Per-File Diff

    /// Fetch and parse the unified diff for a specific file.
    func fetchDiff(for path: String) async {
        guard let root = repoRoot else { return }

        // Use HEAD diff to capture both staged and unstaged changes
        let output = try? await runGit(["diff", "HEAD", "--", path], in: root)
        guard let diffText = output, !diffText.isEmpty else {
            // For untracked files, show the whole file as additions
            if let untrackedOutput = try? await runGit(["diff", "--no-index", "/dev/null", path], in: root) {
                let hunks = GitParser.parseDiff(untrackedOutput)
                expandedDiffs[path] = hunks
            } else {
                expandedDiffs[path] = []
            }
            return
        }
        let hunks = GitParser.parseDiff(diffText)
        expandedDiffs[path] = hunks
    }

    /// Remove cached diff for a file (collapse).
    func collapseDiff(for path: String) {
        expandedDiffs.removeValue(forKey: path)
    }

    // MARK: - Private Helpers

    private func clearState() {
        branchName = nil
        repoRoot = nil
        isGitRepo = false
        fileChanges = []
        expandedDiffs = [:]
    }

    private func detectRepoRoot(for directory: String) async -> String? {
        let output = try? await runGit(["rev-parse", "--show-toplevel"], in: directory)
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func statusOrder(_ status: GitFileStatus) -> Int {
        switch status {
        case .modified: return 0
        case .added: return 1
        case .deleted: return 2
        case .renamed: return 3
        case .untracked: return 4
        case .conflicted: return 5
        }
    }

    // MARK: - Git Process Runner

    /// Run a git command asynchronously and return stdout.
    private func runGit(_ arguments: [String], in directory: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
            process.standardOutput = stdout
            process.standardError = stderr

            var env = ProcessInfo.processInfo.environment
            env["GIT_TERMINAL_PROMPT"] = "0"
            env["LC_ALL"] = "C"
            process.environment = env

            process.terminationHandler = { proc in
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

                if proc.terminationStatus == 0 || proc.terminationStatus == 1 {
                    // git diff returns 1 when there are differences (--no-index mode)
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    let err = String(data: errorData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: GitError.commandFailed(
                        status: proc.terminationStatus, stderr: err
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GitError.gitNotFound)
            }
        }
    }
}
