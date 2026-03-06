import SwiftUI

struct SplitNodeView: View {
    let node: SplitNode
    @ObservedObject var workspace: Workspace

    var body: some View {
        switch node.content {
        case .leaf(let panelID):
            if let panel = workspace.panels[panelID] {
                PaneView(panel: panel, workspace: workspace, nodeID: node.id)
            }

        case .split(let direction, let ratio, let first, let second):
            SplitContainerView(
                direction: direction,
                ratio: ratio,
                onRatioChange: { newRatio in
                    workspace.updateRatio(nodeID: node.id, ratio: newRatio)
                },
                first: {
                    SplitNodeView(node: first, workspace: workspace)
                },
                second: {
                    SplitNodeView(node: second, workspace: workspace)
                }
            )
        }
    }
}

// MARK: - Resizable Split Container

struct SplitContainerView<First: View, Second: View>: View {
    let direction: SplitDirection
    let ratio: CGFloat
    let onRatioChange: (CGFloat) -> Void
    @ViewBuilder let first: () -> First
    @ViewBuilder let second: () -> Second

    /// Captured at drag start so it doesn't shift mid-drag.
    @State private var dragStartRatio: CGFloat? = nil
    private let gap: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let isHorizontal = direction == .horizontal
            let totalSize = isHorizontal ? geometry.size.width : geometry.size.height
            let firstSize = totalSize * ratio - gap / 2
            let secondSize = totalSize * (1 - ratio) - gap / 2

            if isHorizontal {
                HStack(spacing: 0) {
                    first()
                        .frame(width: max(0, firstSize))

                    DividerHandle(isHorizontal: true, onDrag: { translation in
                        handleDrag(delta: translation.width, totalSize: totalSize)
                    }, onDragEnd: {
                        dragStartRatio = nil
                    })

                    second()
                        .frame(width: max(0, secondSize))
                }
            } else {
                VStack(spacing: 0) {
                    first()
                        .frame(height: max(0, firstSize))

                    DividerHandle(isHorizontal: false, onDrag: { translation in
                        handleDrag(delta: translation.height, totalSize: totalSize)
                    }, onDragEnd: {
                        dragStartRatio = nil
                    })

                    second()
                        .frame(height: max(0, secondSize))
                }
            }
        }
    }

    private func handleDrag(delta: CGFloat, totalSize: CGFloat) {
        if dragStartRatio == nil {
            dragStartRatio = ratio
        }
        guard let startRatio = dragStartRatio, totalSize > 0 else { return }
        let newRatio = startRatio + delta / totalSize
        let clamped = max(0.1, min(0.9, newRatio))
        // Skip sub-pixel changes to reduce jitter
        guard abs(clamped - ratio) > 0.001 else { return }
        // Suppress animations during drag
        withTransaction(Transaction(animation: nil)) {
            onRatioChange(clamped)
        }
    }
}

struct DividerHandle: View {
    let isHorizontal: Bool
    let onDrag: (CGSize) -> Void
    let onDragEnd: () -> Void

    var body: some View {
        Color.clear
            .frame(
                width: isHorizontal ? gap : nil,
                height: isHorizontal ? nil : gap
            )
            .contentShape(Rectangle().inset(by: -hitExpansion))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        onDrag(value.translation)
                    }
                    .onEnded { _ in
                        onDragEnd()
                    }
            )
            .onHover { hovering in
                if hovering {
                    if isHorizontal {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.resizeUpDown.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
    }

    private let gap: CGFloat = 4
    private let hitExpansion: CGFloat = 4
}
