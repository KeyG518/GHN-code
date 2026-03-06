# smux

A lightweight macOS terminal workspace app built with SwiftUI + AppKit.

`smux` gives you:
- Multiple workspaces
- Split terminal panes (horizontal/vertical)
- Focus navigation between panes
- Per-pane activity and attention indicators
- Optional completion notifications for background work
- Layout/state restore on relaunch

## Current Tech Stack

- Language: Swift 5.9+
- Platform: macOS 14+
- UI: SwiftUI + AppKit
- Terminal engine: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
- Build system: Xcode project (`smux.xcodeproj`)

## What Is Implemented

- Workspace management (create/select/delete)
- Recursive split tree layout with draggable split dividers
- Pane focus tracking and directional navigation
- Terminal pane actions:
  - Split right / split down
  - Close focused pane
  - Zoom focused pane
  - Toggle notification watch mode (`Off -> On -> Silent`)
- Activity detection from terminal output:
  - `active`, `idle`, `exited`
  - attention highlight when watched commands finish out of focus
- Sidebar badges for active/attention counts
- State persistence on quit + restore on launch

## Keyboard Shortcuts

### Terminal

- `Cmd+W`: Close terminal pane
- `Cmd+Right`: Split right
- `Cmd+Down`: Split down
- `Cmd+Shift+Enter`: Zoom terminal
- `Cmd+B`: Toggle notifications (`Off / On / Silent`)
- `Option+Left/Right/Up/Down`: Jump between panes

### Workspace

- `Cmd+1..9`: Jump to workspace
- `Option+Shift+Right` or `Option+Shift+Down`: Next workspace
- `Option+Shift+Left` or `Option+Shift+Up`: Previous workspace
- `Cmd+Shift+T`: New workspace

### Help

- `Cmd+/`: Open keyboard shortcuts window

## Project Structure

```text
Sources/
  App/        # App entrypoint, app delegate, menu commands
  Models/     # Workspace, split tree, panel/activity/watch models
  Services/   # Activity detection, persistence, workspace manager
  Views/      # Sidebar, workspace layout, pane and terminal views
Resources/
  Assets.xcassets
smux.xcodeproj/
```

## Build And Run

1. Open `smux.xcodeproj` in Xcode 15+.
2. Select the `smux` scheme.
3. Build and run (`Cmd+R`).

### Command-line build

```bash
xcodebuild -project smux.xcodeproj -scheme smux -destination 'generic/platform=macOS' build
```

## Notifications

`smux` can notify you when a watched command finishes while you are not looking at that pane.

- `Off`: no attention behavior
- `On`: attention + sound + system notification (when app is backgrounded)
- `Silent`: attention + system notification (no sound)

Detailed behavior is documented in [`docs/notification-logic.md`](docs/notification-logic.md).

## Known Gaps / Next Steps

- Workspace rename UI is not implemented yet (context menu entry is placeholder).
- Persistence currently restores layout and panel identities, but not full per-panel session metadata.
- No CLI/socket automation API yet.
- No in-app browser integration.
