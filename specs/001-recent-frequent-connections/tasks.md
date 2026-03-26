---

description: "Task list for Recent & Frequent Connections"
---

# Tasks: Recent & Frequent Connections

**Input**: Design documents from `/specs/001-recent-frequent-connections/`
**Prerequisites**: plan.md ✅, spec.md ✅, data-model.md ✅, contracts/modes.md ✅

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: Add persistence layer to `FahrplanLib`. All US1 tasks depend on these.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 Add `HistoryEntry` struct (fields: `originId: String`, `destinationId: String`, `lastSearched: Date`, `count: Int`) conforming to `Codable` in `Sources/FahrplanLib/DataStore.swift`
- [x] T002 Add private `historyURL() -> URL?` returning `$alfred_workflow_data/history.json` in `Sources/FahrplanLib/DataStore.swift`
- [x] T003 Add `readHistory() -> [HistoryEntry]` using `JSONDecoder` with `.iso8601` date strategy, returning `[]` on any error, in `Sources/FahrplanLib/DataStore.swift`
- [x] T004 Add `writeHistory(_ entries: [HistoryEntry])` using `JSONEncoder` with `.iso8601` date strategy and `.atomic` write option in `Sources/FahrplanLib/DataStore.swift`
- [x] T005 Add `package func recordSearch(originId: String, destinationId: String)` — upsert entry (increment `count` + update `lastSearched` if found, else append with `count=1`), sort by `lastSearched` descending, truncate to 50, call `writeHistory` — in `Sources/FahrplanLib/DataStore.swift`

**Checkpoint**: `swift build` passes. `readHistory()` returns `[]` when file absent; `recordSearch` creates and updates `history.json` correctly.

---

## Phase 2: User Story 1 — History Entry Point (Priority: P1) 🎯 MVP

**Goal**: Expose the `listHistory` mode and record searches automatically.

**Independent Test**: Set `mode=listHistory`, run binary, verify Alfred JSON output. Then run a `searchTrips` call and confirm `history.json` is created/updated.

### Implementation for User Story 1

- [x] T006 [P] [US1] Add `package func listHistory(_ workflow: Workflow)` to `Sources/FahrplanLib/Interaction.swift`:
  - Load history via `readHistory()`
  - Partition: `lastSearched >= Date() - 3600` → recent bucket, else → older bucket
  - Sort recent bucket by `lastSearched` descending
  - Sort older bucket by `count` descending, `lastSearched` descending as tiebreaker
  - Concatenate: recent + older
  - For each entry: add `Item(title: "\(Stop(id: originId).name) → \(Stop(id: destinationId).name)", subtitle: "\(count)x gesucht", icon: Item.Icon(path: "./icons/trip.png"), variables: ["mode": "searchTrips", "SOID": originId, "ZOID": destinationId])`
  - If list empty: call `workflow.warnEmpty("Keine bisherigen Verbindungen")`
- [x] T007 [P] [US1] Add `case "listHistory": listHistory(workflow)` to the `mode` switch in `Sources/Fahrplan/main.swift`
- [x] T008 [US1] Add `recordSearch(originId: search.SOID, destinationId: search.ZOID)` call in the `searchTrips` `.success` branch of `Sources/Fahrplan/main.swift`, after `writeCache` and before `listTrips`

**Checkpoint**: All acceptance scenarios from spec.md pass. `swift build` succeeds.

---

## Phase 3: Polish

- [x] T009 Update the dispatch table in `CLAUDE.md` to add the `listHistory` mode row
- [x] T010 Run `swift test` and resolve any test failures

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: No dependencies — start immediately
- **User Story 1 (Phase 2)**: Depends on Phase 1 completion
  - T006 (Interaction.swift) and T007+T008 (main.swift) can run in parallel once Phase 1 is done
  - T007 and T008 are in the same file — execute sequentially
- **Polish (Phase 3)**: Depends on Phase 2 completion

### Parallel Opportunities

```
# Phase 2 parallel execution (once Phase 1 complete):
Task T006: listHistory() in Sources/FahrplanLib/Interaction.swift
Task T007+T008: main.swift changes (sequential within this task)
```

---

## Implementation Strategy

### MVP (User Story 1 only)

1. Complete Phase 1 (T001–T005) — foundation ready
2. Complete Phase 2 (T006–T008) — fully functional
3. Validate: run binary with `mode=listHistory`, confirm output; run `searchTrips`, confirm recording
4. Complete Phase 3 (T009–T010) — done
