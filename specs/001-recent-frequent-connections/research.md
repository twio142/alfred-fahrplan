# Research: Recent & Frequent Connections

## Stop name derivation

**Decision**: Do not store stop names in `history.json`. Derive them at display time.

**Rationale**: `Stop(id:)` already decodes the human-readable name from the DB stop ID
string by extracting the `O=<name>` segment. This means `Stop(id: originId).name` gives
the correct display name with no extra storage.

**Alternatives considered**: Storing name alongside ID — rejected because it duplicates
data already recoverable from the ID and would require keeping names in sync if they ever
change.

---

## Recording trigger

**Decision**: Record the search in `main.swift`'s `searchTrips` case, inside the
`.success` branch, immediately after `writeCache` succeeds (i.e. only when actual trip
results are returned). Call a new `recordSearch(SOID:, ZOID:)` function from `DataStore`.

**Rationale**: `search.SOID` and `search.ZOID` are already in scope at that point. Recording
only on success matches the spec assumption: "a completed search means trip results were
returned". Paging requests for the same route also count (they return new trips for the
same SOID/ZOID pair), which correctly increments the count.

**Alternatives considered**: Recording in `Interaction.searchTrips()` — rejected because
that function is in `FahrplanLib` and should remain testable without a live data directory;
keeping persistence calls in `main.swift` is consistent with the existing pattern where
`saveStop`/`removeStop` are also dispatched from `main.swift`.

---

## Date serialisation

**Decision**: Use `JSONEncoder.dateEncodingStrategy = .iso8601` / `JSONDecoder.dateDecodingStrategy = .iso8601`.

**Rationale**: Consistent with existing ISO 8601 usage elsewhere in the codebase
(`ISO8601DateFormatter` in `main.swift`, `Interaction.swift`). Keeps `history.json`
human-readable for debugging.

---

## Single entry point, combined ranking

**Decision**: One mode `listHistory`, one sorted list, no configuration. Entries searched
within the last 1 hour are bucketed as "recent" and sorted by `lastSearched` descending.
All older entries are sorted by `count` descending, `lastSearched` descending as tiebreaker.
The two buckets are concatenated — recent first.

**Rationale**: The 1-hour threshold captures "I just searched this and want it back
immediately" while letting habitual long-term routes surface below. No toggle, no env var,
no user configuration needed.

**Alternatives considered**:
- Two separate views with a toggle — added unnecessary complexity and required the user to
  decide which view to use.
- Pure recency — ignores frequency entirely, making habitual routes invisible after an hour.
- Recency-weighted scoring formula — more complex, harder to reason about and test.

---

## Cap and eviction

**Decision**: After appending/updating an entry, sort the array by `lastSearched`
descending and truncate to 50. This implements LRU eviction: entries with the oldest
`lastSearched` timestamp are dropped first.

**Rationale**: Sorting by `lastSearched` before truncation means the least-recently-used
entry is always at index 50+. A single `dropLast` after sorting is the minimal implementation.
