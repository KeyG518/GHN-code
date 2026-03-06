import Foundation

enum SplitDirection: String, Codable {
    case horizontal
    case vertical
}

struct SplitNode: Identifiable, Equatable {
    let id: UUID
    var content: Content

    indirect enum Content: Equatable {
        case leaf(panelID: UUID)
        case split(direction: SplitDirection, ratio: CGFloat, first: SplitNode, second: SplitNode)
    }

    static func leaf(panelID: UUID) -> SplitNode {
        SplitNode(id: UUID(), content: .leaf(panelID: panelID))
    }

    static func split(direction: SplitDirection, ratio: CGFloat, first: SplitNode, second: SplitNode) -> SplitNode {
        SplitNode(id: UUID(), content: .split(direction: direction, ratio: ratio, first: first, second: second))
    }

    // MARK: - Tree Operations

    /// Returns all panel IDs in this subtree.
    var allPanelIDs: [UUID] {
        switch content {
        case .leaf(let panelID):
            return [panelID]
        case .split(_, _, let first, let second):
            return first.allPanelIDs + second.allPanelIDs
        }
    }

    /// Returns the number of leaves.
    var leafCount: Int {
        switch content {
        case .leaf:
            return 1
        case .split(_, _, let first, let second):
            return first.leafCount + second.leafCount
        }
    }

    /// Update the split ratio for a specific node.
    func withRatio(nodeID: UUID, ratio: CGFloat) -> SplitNode {
        guard case .split(let dir, let currentRatio, let first, let second) = content else {
            return self
        }
        if id == nodeID {
            return SplitNode(id: id, content: .split(
                direction: dir,
                ratio: max(0.1, min(0.9, ratio)),
                first: first,
                second: second
            ))
        }
        return SplitNode(id: id, content: .split(
            direction: dir,
            ratio: currentRatio,
            first: first.withRatio(nodeID: nodeID, ratio: ratio),
            second: second.withRatio(nodeID: nodeID, ratio: ratio)
        ))
    }

    /// Split a leaf into two panes.
    func splitting(panelID: UUID, direction: SplitDirection, newPanelID: UUID) -> SplitNode {
        switch content {
        case .leaf(let pid):
            if pid == panelID {
                return .split(
                    direction: direction,
                    ratio: 0.5,
                    first: self,
                    second: .leaf(panelID: newPanelID)
                )
            }
            return self

        case .split(let dir, let ratio, let first, let second):
            return SplitNode(id: id, content: .split(
                direction: dir,
                ratio: ratio,
                first: first.splitting(panelID: panelID, direction: direction, newPanelID: newPanelID),
                second: second.splitting(panelID: panelID, direction: direction, newPanelID: newPanelID)
            ))
        }
    }

    /// Remove a panel, collapsing the split. Returns nil if removing the only leaf.
    func removing(panelID: UUID) -> SplitNode? {
        switch content {
        case .leaf(let pid):
            return pid == panelID ? nil : self

        case .split(let dir, let ratio, let first, let second):
            let newFirst = first.removing(panelID: panelID)
            let newSecond = second.removing(panelID: panelID)

            if newFirst == nil && newSecond == nil { return nil }
            if newFirst == nil { return newSecond }
            if newSecond == nil { return newFirst }

            return SplitNode(id: id, content: .split(
                direction: dir,
                ratio: ratio,
                first: newFirst!,
                second: newSecond!
            ))
        }
    }

    /// Find the panel ID adjacent to the given panel in a direction.
    func adjacentPanel(to panelID: UUID, direction: NavigationDirection) -> UUID? {
        let leaves = orderedLeaves(for: panelID, axis: direction.axis)
        guard let index = leaves.firstIndex(of: panelID) else { return nil }

        switch direction {
        case .left, .up:
            return index > 0 ? leaves[index - 1] : nil
        case .right, .down:
            return index < leaves.count - 1 ? leaves[index + 1] : nil
        }
    }

    /// Ordered leaves along an axis for navigation, scoped to the subtree containing panelID.
    private func orderedLeaves(for panelID: UUID, axis: SplitDirection) -> [UUID] {
        switch content {
        case .leaf(let pid):
            return [pid]
        case .split(let dir, _, let first, let second):
            if dir == axis {
                // Same axis as navigation: both subtrees are ordered along this direction
                return first.orderedLeaves(for: panelID, axis: axis)
                     + second.orderedLeaves(for: panelID, axis: axis)
            } else {
                // Perpendicular split: stay within the subtree containing panelID
                if first.allPanelIDs.contains(panelID) {
                    return first.orderedLeaves(for: panelID, axis: axis)
                } else {
                    return second.orderedLeaves(for: panelID, axis: axis)
                }
            }
        }
    }
}

enum NavigationDirection {
    case left, right, up, down

    var axis: SplitDirection {
        switch self {
        case .left, .right: return .horizontal
        case .up, .down: return .vertical
        }
    }
}
