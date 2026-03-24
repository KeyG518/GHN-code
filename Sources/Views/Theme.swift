import SwiftUI

// MARK: - Mux-inspired Dark Theme
// Centralized color and style constants matching coder/mux design language.

enum Theme {
    // MARK: Surface Colors
    /// Primary background — near-black (#0a0a0b)
    static let surfacePrimary = Color(nsColor: NSColor(red: 0.04, green: 0.04, blue: 0.043, alpha: 1))
    /// Sidebar background (#171717)
    static let surfaceSidebar = Color(nsColor: NSColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1))
    /// Pane / card background (#141414)
    static let surfacePane = Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1))
    /// Title bar / elevated surface (#1a1a1a)
    static let surfaceTitlebar = Color(nsColor: NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1))
    /// Hover / subtle highlight
    static let surfaceHover = Color.white.opacity(0.04)
    /// Selected item highlight
    static let surfaceSelected = Color.white.opacity(0.08)

    // MARK: Border Colors
    /// Default border (#262626)
    static let border = Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1))
    /// Separator (same as border)
    static let separator = Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1))

    // MARK: Accent / Status Colors
    /// Accent blue — VS Code-style (#007acc)
    static let accent = Color(red: 0.0, green: 0.48, blue: 0.80)
    /// Focus ring — muted accent
    static let focus = Color(red: 0.0, green: 0.48, blue: 0.80).opacity(0.6)
    /// Success / active (#4caf50)
    static let success = Color(red: 0.30, green: 0.69, blue: 0.31)
    /// Warning / attention (#ffc107)
    static let warning = Color(red: 1.0, green: 0.76, blue: 0.03)
    /// Danger / error (#e53935)
    static let danger = Color(red: 0.90, green: 0.22, blue: 0.21)
    /// Idle / neutral dot
    static let idle = Color.white.opacity(0.3)

    // MARK: Mode Colors (matching mux agent modes)
    /// Working / exec mode — purple
    static let modeExec = Color(red: 0.55, green: 0.24, blue: 0.93)
    /// Plan mode — steel blue
    static let modePlan = Color(red: 0.24, green: 0.47, blue: 0.72)
    /// Auto mode — light cyan
    static let modeAuto = Color(red: 0.64, green: 0.91, blue: 0.95)
    /// Task / subagent — teal
    static let modeTask = Color(red: 0.22, green: 0.70, blue: 0.64)

    // MARK: Text Colors
    /// Primary text (#d4d4d4)
    static let textPrimary = Color(nsColor: NSColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1))
    /// Secondary text (#a0a0a0)
    static let textSecondary = Color.white.opacity(0.55)
    /// Muted / tertiary text
    static let textMuted = Color.white.opacity(0.35)
    /// Bright white for focused elements
    static let textBright = Color.white.opacity(0.9)

    // MARK: Terminal Colors
    /// Terminal background (slightly offset from pane)
    static let terminalBg = NSColor(red: 0.06, green: 0.06, blue: 0.065, alpha: 1)
    /// Terminal foreground text
    static let terminalFg = NSColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1)

    // MARK: Dimensions
    /// Corner radius for cards/panes
    static let cornerRadius: CGFloat = 8
    /// Corner radius for smaller elements (badges, buttons)
    static let cornerRadiusSmall: CGFloat = 4
    /// Sidebar row corner radius
    static let cornerRadiusRow: CGFloat = 6
    /// Border width — default
    static let borderWidth: CGFloat = 1
    /// Border width — focused/active
    static let borderWidthFocused: CGFloat = 1.5
    /// Gap between split panes
    static let splitGap: CGFloat = 2
    /// Title bar height
    static let titleBarHeight: CGFloat = 32
    /// Status bar height
    static let statusBarHeight: CGFloat = 28
    /// Sidebar width
    static let sidebarMinWidth: CGFloat = 200

    // MARK: Fonts
    /// Monospaced font for terminal
    static let terminalFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    /// UI label font
    static let labelFont = Font.system(size: 12, weight: .medium)
    /// Small label font
    static let labelSmallFont = Font.system(size: 11, weight: .medium)
    /// Badge font
    static let badgeFont = Font.system(size: 10, weight: .semibold, design: .monospaced)
    /// Title bar font
    static let titleBarFont = Font.system(size: 11, weight: .medium)
    /// Status bar font
    static let statusBarFont = Font.system(size: 11, weight: .regular)
}

// MARK: - Status Indicator

/// A small colored dot indicating workspace/panel status.
struct StatusDot: View {
    let color: Color
    var size: CGFloat = 7
    var isPulsing: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .fill(color.opacity(0.4))
                    .frame(width: size + 4, height: size + 4)
                    .opacity(isPulsing ? 1 : 0)
                    .animation(isPulsing ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: isPulsing)
            )
    }
}
