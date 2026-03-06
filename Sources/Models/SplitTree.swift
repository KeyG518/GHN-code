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
        let axis = direction.axis
        let forward = direction == .right || direction == .down

        // Build path from root to the panel
        guard let path = pathTo(panelID) else { return nil }

        // Walk up the path to find the deepest same-axis split we can cross
        for i in stride(from: path.count - 1, through: 0, by: -1) {
            let step = path[i]
            guard step.direction == axis else { continue }

            // Going forward: we must be in the first child to cross to second
            // Going backward: we must be in the second child to cross to first
            if forward && step.wentFirst {
                let perpHints = perpendicularHints(from: path, below: i)
                return selectLeaf(in: step.second, axis: axis, forward: true, perpHints: perpHints)
            } else if !forward && !step.wentFirst {
                let perpHints = perpendicularHints(from: path, below: i)
                return selectLeaf(in: step.first, axis: axis, forward: false, perpHints: perpHints)
            }
        }
        return nil
    }

    // MARK: - Navigation Helpers

    private struct PathStep {
        let direction: SplitDirection
        let wentFirst: Bool
        let first: SplitNode
        let second: SplitNode
    }

    /// Build the path from this node down to the leaf containing panelID.
    private func pathTo(_ panelID: UUID) -> [PathStep]? {
        switch content {
        case .leaf(let pid):
            return pid == panelID ? [] : nil
        case .split(let dir, _, let first, let second):
            if let sub = first.pathTo(panelID) {
                return [PathStep(direction: dir, wentFirst: true, first: first, second: second)] + sub
            }
            if let sub = second.pathTo(panelID) {
                return [PathStep(direction: dir, wentFirst: false, first: first, second: second)] + sub
            }
            return nil
        }
    }

    /// Collect perpendicular position hints (first/second) from the path below the crossing point.
    private func perpendicularHints(from path: [PathStep], below crossIndex: Int) -> [Bool] {
        var hints: [Bool] = []
        for i in (crossIndex + 1)..<path.count {
            if path[i].direction != path[crossIndex].direction {
                hints.append(path[i].wentFirst)
            }
        }
        return hints
    }

    /// Select the nearest leaf in a subtree, mirroring the source panel's perpendicular positions.
    private func selectLeaf(in node: SplitNode, axis: SplitDirection, forward: Bool, perpHints: [Bool]) -> UUID {
        switch node.content {
        case .leaf(let pid):
            return pid
        case .split(let dir, _, let first, let second):
            if dir == axis {
                // Same axis: take the nearest side to the crossing boundary
                let target = forward ? first : second
                return selectLeaf(in: target, axis: axis, forward: forward, perpHints: perpHints)
            } else {
                // Perpendicular: mirror the source's position using hints
                var remaining = perpHints
                let goFirst = remaining.isEmpty ? true : remaining.removeFirst()
                let target = goFirst ? first : second
                return selectLeaf(in: target, axis: axis, forward: forward, perpHints: remaining)
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
