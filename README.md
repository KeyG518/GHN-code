# GHN-code

A native macOS terminal for running multiple AI coding agents in parallel.

Based on [smux](https://github.com/gergomiklos/smux) (MIT License).

## Features

- **Split terminals, run agents in parallel** — Split horizontally or vertically and manage everything at once.
- **Works with any CLI agent** — OpenCode, Claude Code, Aider, or any terminal tool.
- **Get notified when agents need you** — Turn on watch mode for any terminal.
- **Workspaces** — Group related terminals into workspaces and switch between them.
- **Keyboard-driven** — Split, navigate, zoom, close, switch — everything is one shortcut away.
- **Session persistence** — Layout, terminals, and everything are saved and restored automatically.
- **Native and fast** — Written in Swift for macOS.

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Split right | `Cmd + Right` |
| Split down | `Cmd + Down` |
| Close | `Cmd + W` |
| Zoom | `Cmd + Shift + Enter` |
| Toggle notifications | `Cmd + B` |
| Navigate | `Option + Arrow keys` |
| Switch workspace | `Option + Shift + Arrow keys` |
| New workspace | `Cmd + Shift + T` |
| Show all shortcuts | `Cmd + /` |

## Build from source

Requires macOS 14+ and Xcode 15+.

```bash
git clone https://github.com/KeyG518/GHN-code.git
cd GHN-code
open smux.xcodeproj
# Press Cmd+R to build and run
```

## License

MIT (original smux code)

See [LICENSE](LICENSE) for the full MIT license text.
