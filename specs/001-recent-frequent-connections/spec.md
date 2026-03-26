# Feature Specification: Recent & Frequent Connections

**Feature Branch**: `001-recent-frequent-connections`
**Created**: 2026-03-26
**Status**: Draft
**Input**: User description: "add a new entry point for listing recent / frequent connections. keep records of searched connections"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open History and Re-run a Connection (Priority: P1)

A user triggers a single dedicated entry point and sees a combined list of their connection
history. Connections searched within the last hour appear at the top, ordered by recency —
ideal for re-running a search made moments ago. Older connections follow, ordered by how
often they've been searched — surfacing habitual routes even if not used today. Selecting
any entry replays the search instantly.

**Why this priority**: This is the entire feature — one entry point, one ranked list, no
configuration needed.

**Independent Test**: Perform a connection search, then invoke the history entry point and
verify the just-performed search appears first. Select it and confirm connection results
are displayed.

**Acceptance Scenarios**:

1. **Given** a user searched a connection less than 1 hour ago, **When** they open the
   history list, **Then** that entry appears at the top, ordered by recency among other
   sub-hour entries.
2. **Given** a user searched connection A five times (last search 2 hours ago) and
   connection B once (last search 3 hours ago), **When** they open the history list and
   no entries are within the last hour, **Then** A appears above B.
3. **Given** a user selects any entry, **When** the selection is confirmed, **Then** the
   workflow searches for that connection departing now.
4. **Given** a user has never performed a search, **When** they open the history list,
   **Then** a friendly placeholder message is shown.

---

### Edge Cases

- If the history store is corrupted or unreadable, the entry point MUST degrade gracefully
  and show an error item rather than crash.
- The history MUST cap at 50 unique origin–destination pairs; entries beyond the cap are
  evicted (least-recently-used first) to prevent unbounded storage growth.
- If the history file is absent on first launch, the workflow MUST treat this as empty
  history and create the file on the first recorded search.
- If origin equals destination, the search is still recorded; no special filtering applied.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The workflow MUST expose a new dedicated entry point that lists previously
  searched connections, accessible without re-entering origin or destination.
- **FR-002**: Every completed connection search MUST be automatically recorded with origin
  stop ID, destination stop ID, and a timestamp.
- **FR-003**: The history list MUST rank entries using a two-tier sort: entries searched
  within the last 1 hour appear first (sorted by `lastSearched` descending); entries older
  than 1 hour follow (sorted by `count` descending, `lastSearched` descending as tiebreaker).
- **FR-004**: Selecting any entry MUST immediately trigger a new connection search for that
  origin–destination pair, departing now.
- **FR-005**: The history MUST persist across workflow invocations and Alfred restarts.
- **FR-006**: The history store MUST cap at 50 unique origin–destination pairs; the
  least-recently-used entry is evicted when the cap is exceeded.
- **FR-007**: If history is empty, the entry point MUST display an informative placeholder
  item rather than a blank list.

### Key Entities

- **Connection Record**: A single recorded search — origin stop ID, destination stop ID,
  last-searched timestamp, and total search count.
- **History Store**: The ordered collection of Connection Records, persisted in the workflow
  data directory. Subject to the 50-record cap.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can re-run any of their last 50 connection searches in 2 actions or
  fewer from the Alfred prompt (invoke entry point + select item).
- **SC-002**: All connection searches performed during a session are present in the history
  the next time the user opens the workflow — no silent loss of records.
- **SC-003**: After 10 or more recorded searches across at least 3 distinct routes, the
  most-searched route ranks first among entries older than 1 hour.
- **SC-004**: The history entry point loads and displays results with no perceptible
  additional latency compared to the existing cached-trips shortcut.

---

## Assumptions

- The new entry point is triggered by a new Alfred keyword (e.g. `dbh`), not by modifying
  an existing keyword — preserving backward compatibility with current usage.
- A "completed search" means the user reached the trip-results step and results were
  returned; browsing stops alone does not count as a recordable search.
- Searches are keyed by origin–destination pair only; departure time is not part of the
  uniqueness key (same route at different times increments the count on one record).
- When replaying a connection from history, departure time defaults to "now" rather than
  any originally stored time.
- History is stored in the existing workflow data directory, consistent with how saved
  stops and home station are stored.
- No cloud sync or cross-device sharing of history is in scope.
