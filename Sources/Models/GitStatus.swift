import Foundation

// MARK: - Git File Status

enum GitFileStatus: Equatable, Hashable {
    case added
    case modified
    case deleted
    case renamed
    case untracked
    case conflicted
}

// MARK: - Git File Change

struct GitFileChange: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let status: GitFileStatus
    let staged: Bool
    var linesAdded: Int = 0
    var linesDeleted: Int = 0

    /// Just the filename (last path component)
    var filename: String {
        (path as NSString).lastPathComponent
    }

    /// Directory portion of the path (empty if file is at root)
    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir == "." ? "" : dir
    }

    static func == (lhs: GitFileChange, rhs: GitFileChange) -> Bool {
        lhs.path == rhs.path && lhs.status == rhs.status && lhs.staged == rhs.staged
            && lhs.linesAdded == rhs.linesAdded && lhs.linesDeleted == rhs.linesDeleted
    }
}

// MARK: - Diff Models

struct DiffHunk: Identifiable {
    let id = UUID()
    let header: String
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]
}

enum DiffLineType {
    case context
    case addition
    case deletion
}

struct DiffLine: Identifiable {
    let id = UUID()
    let type: DiffLineType
    let content: String
    /// Line number in the old file (nil for additions)
    let oldLineNumber: Int?
    /// Line number in the new file (nil for deletions)
    let newLineNumber: Int?
}

// MARK: - Parsing

enum GitParser {

    /// Parse `git status --porcelain=v1` output into file changes.
    static func parseStatusPorcelain(_ output: String) -> [GitFileChange] {
        var changes: [GitFileChange] = []
        for line in output.components(separatedBy: "\n") where line.count >= 3 {
            let indexChar = line[line.startIndex]
            let worktreeChar = line[line.index(line.startIndex, offsetBy: 1)]
            let path = String(line.dropFirst(3))

            // Staged changes (index column)
            if indexChar != " " && indexChar != "?" {
                changes.append(GitFileChange(
                    path: path,
                    status: mapStatusChar(indexChar),
                    staged: true
                ))
            }
            // Unstaged changes (worktree column)
            if worktreeChar != " " && worktreeChar != "?" {
                // Don't duplicate if already captured as staged with same status
                let status = mapStatusChar(worktreeChar)
                if !(indexChar != " " && indexChar != "?" && mapStatusChar(indexChar) == status) {
                    changes.append(GitFileChange(
                        path: path,
                        status: status,
                        staged: false
                    ))
                }
            }
            // Untracked files
            if indexChar == "?" {
                changes.append(GitFileChange(path: path, status: .untracked, staged: false))
            }
        }
        return changes
    }

    /// Parse `git diff --numstat` output into a dictionary of path -> (added, deleted).
    static func parseNumstat(_ output: String) -> [String: (added: Int, deleted: Int)] {
        var result: [String: (added: Int, deleted: Int)] = [:]
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count >= 3 else { continue }
            let added = Int(parts[0]) ?? 0
            let deleted = Int(parts[1]) ?? 0
            let path = String(parts[2])
            result[path] = (added, deleted)
        }
        return result
    }

    /// Parse unified diff output into hunks.
    static func parseDiff(_ diffText: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var currentLines: [DiffLine] = []
        var currentHeader: (header: String, oldStart: Int, oldCount: Int, newStart: Int, newCount: Int)? = nil
        var oldLine = 0
        var newLine = 0

        for line in diffText.components(separatedBy: "\n") {
            if line.hasPrefix("@@") {
                // Save previous hunk
                if let h = currentHeader {
                    hunks.append(DiffHunk(
                        header: h.header,
                        oldStart: h.oldStart, oldCount: h.oldCount,
                        newStart: h.newStart, newCount: h.newCount,
                        lines: currentLines
                    ))
                }
                currentLines = []

                // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
                let parsed = parseHunkHeader(line)
                currentHeader = (
                    header: line,
                    oldStart: parsed.oldStart,
                    oldCount: parsed.oldCount,
                    newStart: parsed.newStart,
                    newCount: parsed.newCount
                )
                oldLine = parsed.oldStart
                newLine = parsed.newStart

            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                currentLines.append(DiffLine(
                    type: .addition,
                    content: String(line.dropFirst()),
                    oldLineNumber: nil,
                    newLineNumber: newLine
                ))
                newLine += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                currentLines.append(DiffLine(
                    type: .deletion,
                    content: String(line.dropFirst()),
                    oldLineNumber: oldLine,
                    newLineNumber: nil
                ))
                oldLine += 1
            } else if line.hasPrefix(" ") {
                currentLines.append(DiffLine(
                    type: .context,
                    content: String(line.dropFirst()),
                    oldLineNumber: oldLine,
                    newLineNumber: newLine
                ))
                oldLine += 1
                newLine += 1
            }
            // Skip lines starting with "diff", "index", "---", "+++" etc.
        }

        // Save last hunk
        if let h = currentHeader {
            hunks.append(DiffHunk(
                header: h.header,
                oldStart: h.oldStart, oldCount: h.oldCount,
                newStart: h.newStart, newCount: h.newCount,
                lines: currentLines
            ))
        }
        return hunks
    }

    // MARK: - Helpers

    private static func mapStatusChar(_ char: Character) -> GitFileStatus {
        switch char {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "U": return .conflicted
        default: return .modified
        }
    }

    private static func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int) {
        // @@ -10,7 +10,8 @@ optional context
        var oldStart = 0, oldCount = 1, newStart = 0, newCount = 1

        // Find the content between @@ markers
        guard let firstAt = line.range(of: "@@"),
              let secondAt = line[firstAt.upperBound...].range(of: "@@") else {
            return (oldStart, oldCount, newStart, newCount)
        }

        let inner = line[firstAt.upperBound..<secondAt.lowerBound]
            .trimmingCharacters(in: .whitespaces)

        let parts = inner.split(separator: " ")
        for part in parts {
            if part.hasPrefix("-") {
                let nums = part.dropFirst().split(separator: ",")
                oldStart = Int(nums[0]) ?? 0
                if nums.count > 1 { oldCount = Int(nums[1]) ?? 1 }
            } else if part.hasPrefix("+") {
                let nums = part.dropFirst().split(separator: ",")
                newStart = Int(nums[0]) ?? 0
                if nums.count > 1 { newCount = Int(nums[1]) ?? 1 }
            }
        }
        return (oldStart, oldCount, newStart, newCount)
    }
}
