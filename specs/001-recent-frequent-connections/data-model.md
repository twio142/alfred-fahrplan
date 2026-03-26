# Data Model: Recent & Frequent Connections

## HistoryEntry

Represents one unique origin–destination pair ever searched.

| Field            | Type   | Description                                          |
|------------------|--------|------------------------------------------------------|
| `originId`       | String | DB stop ID of the origin stop                        |
| `destinationId`  | String | DB stop ID of the destination stop                   |
| `lastSearched`   | Date   | Timestamp of the most recent search for this pair    |
| `count`          | Int    | Total number of searches recorded for this pair      |

**Uniqueness key**: `originId + destinationId` (ordered pair — A→B and B→A are distinct records).

**Name derivation**: Display names are not stored. At render time, `Stop(id: originId).name`
and `Stop(id: destinationId).name` decode the names from the DB ID strings (the `O=<name>`
segment), consistent with the existing `savedStops()` implementation.

---

## History Store

- **File**: `$alfred_workflow_data/history.json`
- **Format**: JSON array of `HistoryEntry` objects, encoded with ISO 8601 dates
- **Cap**: Maximum 50 entries. After each write the array is sorted by `lastSearched`
  descending and truncated to 50 — evicting the least-recently-used entry.
- **Absence**: A missing file is treated as an empty history; the file is created on the
  first `recordSearch` call.
- **Corruption**: A file that cannot be decoded is treated as empty (same fallback as
  `readStore()` in `DataStore.swift`).

---

## Update Logic (recordSearch)

1. Load `history.json` (or start with `[]` if absent/corrupt).
2. Find existing entry where `originId` and `destinationId` match.
   - If found: increment `count`, set `lastSearched = now`.
   - If not found: append new entry with `count = 1`, `lastSearched = now`.
3. Sort array by `lastSearched` descending (for LRU eviction).
4. Truncate to 50 entries.
5. Write back atomically.

## Display Sort Logic (listHistory)

At render time, re-sort the loaded array (no file write):

1. Partition into two buckets using a 1-hour threshold (`now - 3600s`):
   - **Recent**: `lastSearched >= threshold` — sort by `lastSearched` descending
   - **Older**: `lastSearched < threshold` — sort by `count` descending, `lastSearched` descending as tiebreaker
2. Concatenate: recent bucket first, then older bucket.
