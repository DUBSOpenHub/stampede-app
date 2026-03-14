# Agents

## Overview

**Stampede App** is a native macOS SwiftUI dashboard for monitoring Terminal Stampede multi-agent orchestration runs in real time. This repo contains no custom AI agents or Copilot CLI skills — it is a Swift application.

## How Copilot Can Help

Although there are no custom agents defined here, GitHub Copilot can assist with this Swift/SwiftUI codebase in the following ways:

- **UI development**: Generate or refactor SwiftUI views (dashboard, grid, agent detail panel, menu bar extra)
- **Filesystem IPC**: Help read and parse Stampede's `fleet.json`, `claimed/`, `queue/`, and `results/` directories
- **Design system**: Apply the gold-on-dark color tokens (`#F5A623` gold, `#0D1117` bgDeep) consistently across views
- **Conflict detection**: Implement or improve file-overlap detection logic for the conflict-warning banner
- **Testing**: Write XCTest unit and UI tests for view models and file-watching logic
- **Performance**: Optimize the polling/file-watching loop and `swift build` pipeline

## Configuration

```bash
git clone https://github.com/DUBSOpenHub/stampede-app.git
cd stampede-app
swift build
open "$(swift build --show-bin-path)/StampedeUI"
```

Point the app at your Stampede run directory via **Preferences** (`STAMPEDE_DIR`). Requires macOS 13+ and Swift 5.9+.
