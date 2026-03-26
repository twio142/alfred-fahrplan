# Mode Contracts: Recent & Frequent Connections

## New mode: `listHistory`

Lists the connection history using a two-tier sort: entries from the last hour by recency,
older entries by frequency.

### Input (environment variables)

| Variable | Required | Values          |
|----------|----------|-----------------|
| `mode`   | yes      | `"listHistory"` |

No other input variables.

### Output (Alfred JSON items)

Each history entry produces one `Item`:

| Field       | Value |
|-------------|-------|
| `title`     | `"<OriginName> → <DestinationName>"` |
| `subtitle`  | `"<N>x gesucht"` (count) |
| `arg`       | `"<OriginName> → <DestinationName>"` |
| `variables` | `{ mode: "searchTrips", SOID: "<originId>", ZOID: "<destinationId>" }` |
| `icon`      | `./icons/trip.png` |

Sort order: entries with `lastSearched >= now - 3600s` first (by `lastSearched` desc),
then entries older than 1 hour (by `count` desc, `lastSearched` desc as tiebreaker).

When history is empty, a single non-actionable `warnEmpty` item is shown.

---

## Modified mode: `searchTrips` (recording side-effect)

After a successful trip search (result contains ≥ 1 trip), the workflow records the search
to history before displaying results. This is transparent to the user.

**Trigger**: `.success` branch of `searchTrips()` callback, after `writeCache`, before `listTrips`.
**Call**: `recordSearch(originId: search.SOID, destinationId: search.ZOID)`

No change to `searchTrips` output or Alfred item structure.
