import SwiftUI

// MARK: - Git Diff Panel (Right Sidebar)

struct GitDiffPanel: View {
    @EnvironmentObject var gitService: GitService
    @EnvironmentObject var workspaceManager: WorkspaceManager

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            panelHeader

            Theme.separator.frame(height: 0.5)

            // ── Content ──
            if !gitService.isGitRepo {
                notARepoState
            } else if gitService.fileChanges.isEmpty {
                noChangesState
            } else {
                fileList
            }
        }
        .background(Theme.surfaceSidebar)
        .overlay(alignment: .leading) {
            Theme.separator.frame(width: 0.5)
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CODE REVIEW")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                // Refresh button
                Button(action: {
                    Task { await gitService.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Refresh")

                // Close button
                Button(action: {
                    workspaceManager.showDiffPanel = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Close panel")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Branch bar
            if gitService.isGitRepo {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.accent)

                    Text(gitService.branchName ?? "HEAD")
                        .font(Theme.labelSmallFont)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if !gitService.fileChanges.isEmpty {
                        Text("\(gitService.fileChanges.count) file\(gitService.fileChanges.count == 1 ? "" : "s")")
                            .font(Theme.badgeFont)
                            .foregroundColor(Theme.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .fill(Theme.surfaceHover)
                            )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(gitService.fileChanges) { change in
                    FileChangeRow(change: change)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty States

    private var noChangesState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(Theme.success.opacity(0.6))
            Text("No changes")
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textSecondary)
            Text("Working tree is clean")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var notARepoState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(Theme.textMuted)
            Text("Not a git repository")
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textSecondary)
            Text("Open a terminal in a git repo\nto see changes here")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - File Change Row

struct FileChangeRow: View {
    let change: GitFileChange
    @EnvironmentObject var gitService: GitService
    @State private var isHovered = false

    private var isExpanded: Bool {
        gitService.expandedDiffs[change.path] != nil
    }

    private var statusColor: Color {
        switch change.status {
        case .added: return Theme.success
        case .modified: return Theme.warning
        case .deleted: return Theme.danger
        case .renamed: return Theme.accent
        case .untracked: return Theme.textMuted
        case .conflicted: return Theme.danger
        }
    }

    private var statusLabel: String {
        switch change.status {
        case .added: return "A"
        case .modified: return "M"
        case .deleted: return "D"
        case .renamed: return "R"
        case .untracked: return "?"
        case .conflicted: return "U"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // File row
            HStack(spacing: 8) {
                // Expand chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 12)

                // Status badge
                Text(statusLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
                    .frame(width: 14)

                // File info
                VStack(alignment: .leading, spacing: 1) {
                    Text(change.filename)
                        .font(Theme.labelSmallFont)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    if !change.directory.isEmpty {
                        Text(change.directory)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Line counts
                HStack(spacing: 4) {
                    if change.linesAdded > 0 {
                        Text("+\(change.linesAdded)")
                            .font(Theme.badgeFont)
                            .foregroundColor(Theme.success)
                    }
                    if change.linesDeleted > 0 {
                        Text("-\(change.linesDeleted)")
                            .font(Theme.badgeFont)
                            .foregroundColor(Theme.danger)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHovered ? Theme.surfaceHover : .clear)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpansion()
            }
            .onHover { isHovered = $0 }

            // Expanded diff
            if isExpanded, let hunks = gitService.expandedDiffs[change.path] {
                DiffView(hunks: hunks)
                    .padding(.leading, 20)
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    private func toggleExpansion() {
        if isExpanded {
            gitService.collapseDiff(for: change.path)
        } else {
            Task { await gitService.fetchDiff(for: change.path) }
        }
    }
}

// MARK: - Diff View

struct DiffView: View {
    let hunks: [DiffHunk]

    var body: some View {
        if hunks.isEmpty {
            HStack {
                Text("No diff available")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
                    .italic()
                Spacer()
            }
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hunks) { hunk in
                    // Hunk header
                    Text(hunk.header)
                        .font(Theme.diffFont)
                        .foregroundColor(Theme.diffHunkHeader)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Diff lines
                    ForEach(hunk.lines) { line in
                        DiffLineView(line: line)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
        }
    }
}

// MARK: - Diff Line View

struct DiffLineView: View {
    let line: DiffLine

    private var backgroundColor: Color {
        switch line.type {
        case .addition: return Theme.diffAdditionBg
        case .deletion: return Theme.diffDeletionBg
        case .context: return .clear
        }
    }

    private var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        }
    }

    private var lineNumber: String {
        if let num = line.newLineNumber {
            return String(format: "%4d", num)
        } else if let num = line.oldLineNumber {
            return String(format: "%4d", num)
        }
        return "    "
    }

    private var textColor: Color {
        switch line.type {
        case .addition: return Theme.success
        case .deletion: return Theme.danger
        case .context: return Theme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text(lineNumber)
                .font(Theme.diffFont)
                .foregroundColor(Theme.textMuted)
                .frame(width: 36, alignment: .trailing)

            // Prefix (+/-/space)
            Text(prefix)
                .font(Theme.diffFont)
                .foregroundColor(textColor)
                .frame(width: 14)

            // Content
            Text(line.content)
                .font(Theme.diffFont)
                .foregroundColor(textColor)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 0.5)
        .background(backgroundColor)
    }
}
