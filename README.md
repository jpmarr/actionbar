# ActionBar

A macOS menubar app for monitoring GitHub Actions workflow runs across multiple repositories.

![macOS](https://img.shields.io/badge/macOS-15%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange)

## Features

- **GitHub OAuth device flow** — authenticate without browser redirects; tokens stored securely in Keychain
- **Personal access token** support as an alternative auth method
- **Repository browsing** — view all repositories accessible to your GitHub account
- **Workflow watching** — select specific workflows to monitor
- **Live run status** — see queued, in-progress, completed, and failed runs at a glance
- **Menubar status icon** — icon updates to reflect the overall state of your watched runs
- **Notifications** — get notified when runs complete or fail
- **Workflow dispatch** — trigger workflow runs with configurable inputs and saved dispatch configs
- **Placeholder expressions** — use dynamic values like current branch in dispatch inputs
- **Webhook notifications** — optional real-time updates via [Smee.io](https://smee.io) webhook relay (no public server required)
- **Configurable polling** — default 30s interval, faster 10s polling for active runs; can be disabled when using webhooks
- **Click to open** — jump straight to a run on GitHub from the menubar

## Requirements

- macOS 15 (Sequoia) or later
- Swift 6.0+
- A GitHub account

## Build & Run

ActionBar uses Swift Package Manager — no Xcode project file required.

```bash
swift build
swift run ActionBar
```

Or open the package in Xcode and run the `ActionBar` scheme.

## Test

```bash
swift test
```

## Setup

1. Launch ActionBar — it appears as an icon in your menubar
2. Click the icon and sign in with your GitHub account (OAuth device flow)
3. Browse your repositories and select workflows to watch
4. ActionBar will poll for updates and notify you of run completions/failures

### Webhook mode (optional)

For near-instant updates without polling, enable webhooks in Settings:

1. Open **Settings** and toggle **Enable webhooks**
2. ActionBar automatically creates a [Smee.io](https://smee.io) channel and registers GitHub webhooks on your watched repos
3. Run status updates arrive in real time via server-sent events
4. You can disable polling entirely or keep both for redundancy

Webhooks require admin access on the watched repositories to create the GitHub webhook. Repos where you lack admin are silently skipped.

## Project Structure

```
Sources/ActionBar/
├── App/        # App entry point, state management
├── Models/     # Data models (Repository, Workflow, WorkflowRun, etc.)
├── Services/   # GitHub API client, auth, polling, notifications
├── Storage/    # Keychain, UserDefaults, dispatch config persistence
└── Views/      # SwiftUI views for the menubar panel
```

## License

All rights reserved.
