# ActionBar

macOS menubar utility for monitoring GitHub Actions workflow runs across multiple repositories.

## Project Overview

- **Platform:** macOS (menubar app)
- **Language:** Swift 6.2
- **UI Framework:** SwiftUI
- **Minimum deployment target:** macOS 15 (Sequoia)
- **Xcode:** 26.2
- **Architecture:** Swift Package Manager (no Xcode project file — use `swift build` / `swift test`)

## What It Does

ActionBar sits in the macOS menubar and lets the user:

1. Authenticate with GitHub (OAuth device flow or personal access token)
2. Browse repositories accessible to their account
3. Select specific workflows to "watch"
4. See live status of watched workflow runs (queued, in_progress, completed, failed)
5. Get notifications on run completion or failure
6. Click a run to open it in the browser

## Architecture

```
ActionBar/
├── Package.swift
├── Sources/
│   └── ActionBar/
│       ├── App/              # App entry point, menubar setup
│       ├── Models/           # Data models (Workflow, Run, Repo, etc.)
│       ├── Services/         # GitHub API client, polling/webhooks, auth
│       ├── Views/            # SwiftUI views (menu content, settings)
│       └── Storage/          # Persistence for watched workflows, tokens
└── Tests/
    └── ActionBarTests/
```

## Key Technical Decisions

- **GitHub API:** Use REST API v3 via URLSession. Key endpoints:
  - `GET /user/repos` — list accessible repos
  - `GET /repos/{owner}/{repo}/actions/workflows` — list workflows
  - `GET /repos/{owner}/{repo}/actions/runs` — list/poll runs
- **Auth:** GitHub OAuth device flow preferred (no redirect URI needed for menubar apps). Store tokens in Keychain.
- **Polling:** Poll active runs on a configurable interval (default 30s). Only poll workflows the user is watching.
- **Persistence:** Store watched workflow config in `UserDefaults` or a JSON file in Application Support.
- **Notifications:** Use `UserNotifications` framework for completion/failure alerts.

## Build & Run

```bash
swift build
swift run ActionBar
```

## Test

```bash
swift test
```

## Conventions

- Use Swift concurrency (async/await, actors) — no Combine or callback-based patterns
- Keep views small and composable
- Prefer value types (structs/enums) for models
- All GitHub API interaction goes through a single `GitHubClient` actor
- Errors should surface to the user via the menu UI, not silently fail
- No third-party dependencies unless strictly necessary
