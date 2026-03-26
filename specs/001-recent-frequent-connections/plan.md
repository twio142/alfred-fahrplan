# Implementation Plan: Recent & Frequent Connections

**Branch**: `001-recent-frequent-connections` | **Date**: 2026-03-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-recent-frequent-connections/spec.md`

## Summary

Add a `listHistory` mode that lists previously searched origin–destination pairs, sortable
by recency or frequency. Searches are silently recorded to `history.json` (in
`$alfred_workflow_data`) whenever `searchTrips` returns results. The history is a JSON
array of `HistoryEntry` records capped at 50, with LRU eviction.

## Technical Context

**Language/Version**: Swift 6.0, macOS 14+
**Primary Dependencies**: Foundation (stdlib) — no new SPM dependencies
**Storage**: `$alfred_workflow_data/history.json` — JSON array, ISO 8601 dates
**Testing**: swift-testing
**Target Platform**: macOS 14+ (Alfred workflow binary)
**Project Type**: CLI tool / Alfred Script Filter
**Performance Goals**: Sub-millisecond — file read + sort of ≤ 50 records
**Constraints**: No network calls; fully offline; atomic file writes
**Scale/Scope**: Single user; ≤ 50 records

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Pre-design | Post-design |
|-----------|-----------|-------------|
| I. Thin Executable, Rich Library | ✅ History CRUD in `FahrplanLib/DataStore.swift`; handler in `FahrplanLib/Interaction.swift`; `main.swift` adds one case + one recording call | ✅ |
| II. Alfred JSON Protocol | ✅ `listHistory()` outputs via `Workflow`/`Item` | ✅ |
| III. Mode-Based Dispatch | ✅ New `listHistory` mode; recording side-effect in `searchTrips` is documented in contracts | ✅ |
| IV. Alfred Directories | ✅ `history.json` in `$alfred_workflow_data` | ✅ |
| V. Simplicity | ✅ No new dependencies; plain JSON array; sort + truncate | ✅ |

## Project Structure

### Documentation (this feature)

```text
specs/001-recent-frequent-connections/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── modes.md         # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Sources/
├── Fahrplan/
│   └── main.swift               # +case "listHistory"; +recordSearch call in searchTrips
└── FahrplanLib/
    ├── DataStore.swift          # +HistoryEntry struct; +readHistory/writeHistory/recordSearch
    └── Interaction.swift        # +listHistory(_:_:) handler

Tests/FahrplanTests/
└── FahrplanTests.swift          # +HistoryTests suite
```

**Structure Decision**: Single-project layout, extending the existing `FahrplanLib` target.
No new files beyond the test suite additions; all changes go into the three files already
central to the feature's concerns.

## Implementation Notes

### DataStore.swift additions

```
HistoryEntry: Codable {
    originId: String
    destinationId: String
    lastSearched: Date
    count: Int
}

historyURL() -> URL?           // $alfred_workflow_data/history.json
readHistory() -> [HistoryEntry]
writeHistory([HistoryEntry])
recordSearch(originId:, destinationId:)
    // upsert, sort by lastSearched desc, truncate to 50, write
```

Encoder/decoder use `.iso8601` date strategy, matching the rest of the codebase.
`readHistory()` returns `[]` on any error (absent file, corrupt JSON).

### Interaction.swift additions

```
listHistory(_ workflow: Workflow)
    // load history
    // partition: lastSearched >= now-3600s → recent bucket; else → older bucket
    // recent bucket: sort by lastSearched desc
    // older bucket: sort by count desc, lastSearched desc as tiebreaker
    // concatenate: recent + older
    // for each entry: add Item(title: "Origin → Dest", subtitle: "\(count)x gesucht",
    //                          variables: { mode: searchTrips, SOID:, ZOID: })
    // empty guard: warnEmpty("Keine bisherigen Verbindungen")
```

### main.swift changes

1. New `case "listHistory"` in the `mode` switch:
   ```swift
   case "listHistory":
       listHistory(workflow)
   ```

2. In `case "searchTrips"`, inside the `.success` branch after `writeCache`:
   ```swift
   recordSearch(originId: search.SOID, destinationId: search.ZOID)
   ```

### info.plist / Alfred wiring

A new Script Filter object is needed in the Alfred workflow with:
- **Keyword**: `dbh` (configurable)
- **Script**: `./Fahrplan` (same binary)
- **Environment variable**: `mode = listHistory`

This is an Alfred editor change, not a code change. It is documented here for completeness
but is outside the scope of the Swift implementation tasks.
