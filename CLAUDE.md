# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Alfred workflow for searching Deutsche Bahn train connections. The `Fahrplan` binary is invoked by Alfred as a script filter — it reads environment variables set by Alfred and writes JSON to stdout.

## Commands

```bash
make build          # Release build (swift build -c release)
make clean          # Clean all build artifacts
swift test          # Run all tests
swift test --filter FormatDurationTests  # Run a specific test suite
swift build         # Debug build
```

The binary lands at `.build/release/Fahrplan`. The Alfred plist auto-builds it on first run via `[ -x Fahrplan ] || make build`.

## Architecture

Two targets:
- **`FahrplanLib`** — library with all logic (`Sources/FahrplanLib/`)
- **`Fahrplan`** — thin executable (`Sources/Fahrplan/main.swift`) that reads the `mode` env var and dispatches

### Dispatch by `mode`

Alfred sets `mode` before invoking the binary. `main.swift` switches on it:

| `mode`        | Handler           | What it does                              |
|---------------|-------------------|-------------------------------------------|
| `setStop`     | `setStop()`       | Search stations; show saved + API results |
| `setTime`     | `setTime()`       | Parse time/date input and store in cache  |
| `searchTrips` | `searchTrips()`   | Hit DB API, write trips to cache, record search in history |
| `cachedTrips` | `listTrips()` / `showTrip()` | Read cache and display results |
| `listHistory` | `listHistory()`   | Show ranked history: last-hour entries by recency, older by frequency |

### Library modules

| File | Responsibility |
|------|---------------|
| `Alfred.swift` | `Workflow` / `Item` types — serialize everything to Alfred's JSON format |
| `API.swift` | Data models (`Stop`, `Trip`, `Segment`, `Search`) and two HTTP functions: `searchStops()`, `searchTrips()` |
| `DataStore.swift` | Persistent saved stops and home station (`$alfred_workflow_data`); trip cache (`$alfred_workflow_cache`) |
| `Interaction.swift` | Top-level interaction flows called from `main.swift` |
| `Utils.swift` | Pure formatting helpers: `formatDuration()`, `tripSubtitle()`, `timeTable()`, segment titles |
| `Basics.swift` | `MyError`, `log()`, `debug()`, environment helpers |

### Storage

- **Data dir** (`$alfred_workflow_data`): saved favourite stops, home station, and search history (JSON)
- **Cache dir** (`$alfred_workflow_cache`): current trip results for pagination / drill-down

## Testing

Uses the `swift-testing` framework (not XCTest). Tests live in `Tests/FahrplanTests/`:
- `FahrplanTests.swift` — unit tests for formatting logic
- `APIIntegrationTests.swift` — integration tests against the real DB API (network required)

Run a single test file: `swift test --filter FahrplanTests`

## Active Technologies
- Swift 6.0, macOS 14+ + Foundation (stdlib) — no new SPM dependencies (001-recent-frequent-connections)
- `$alfred_workflow_data/history.json` — JSON array, ISO 8601 dates (001-recent-frequent-connections)

## Recent Changes
- 001-recent-frequent-connections: Added Swift 6.0, macOS 14+ + Foundation (stdlib) — no new SPM dependencies
