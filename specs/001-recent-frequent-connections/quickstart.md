# Quickstart: Recent & Frequent Connections

## Prerequisites

```bash
make build   # builds .build/release/Fahrplan
```

Set the required environment variables (Alfred sets these automatically at runtime;
for local testing, export them manually):

```bash
export alfred_workflow_data="$TMPDIR/fahrplan-data"
export alfred_workflow_cache="$TMPDIR/fahrplan-cache"
mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
```

---

## 1. Seed history by performing a search

```bash
export mode=searchTrips
export SOID="A=1@O=München Hbf@..."   # a valid DB stop ID
export ZOID="A=1@O=Augsburg Hbf@..."  # a valid DB stop ID
.build/release/Fahrplan
```

Successful output writes trips to cache **and** records the pair to
`$alfred_workflow_data/history.json`.

Inspect the file:

```bash
cat "$alfred_workflow_data/history.json"
# Expected: array with one entry, count=1, lastSearched=<now>
```

---

## 2. List recent connections

```bash
export mode=listHistory
unset historySortMode   # defaults to "recent"
.build/release/Fahrplan
```

Expected: Alfred JSON with one item showing `München Hbf → Augsburg Hbf` and a
toggle item at the bottom.

---

## 3. List frequent connections

```bash
export mode=listHistory
export historySortMode=frequent
.build/release/Fahrplan
```

Expected: same item, subtitle shows `"1x gesucht"`.

---

## 4. Replay a connection from history

From the Alfred UI: select any history item → triggers `searchTrips` with the stored
`SOID`/`ZOID`, departing now.

From the terminal (simulating selection):

```bash
export mode=searchTrips
export SOID="A=1@O=München Hbf@..."
export ZOID="A=1@O=Augsburg Hbf@..."
unset dateTime   # defaults to now + 2 min
.build/release/Fahrplan
```

---

## 5. Verify cap enforcement

Seed 51 distinct pairs, then check the file has exactly 50 entries:

```bash
# (loop calling the binary with 51 different SOID/ZOID pairs)
jq 'length' "$alfred_workflow_data/history.json"
# Expected: 50
```

---

## 6. Verify empty-history message

```bash
rm "$alfred_workflow_data/history.json"
export mode=listHistory
.build/release/Fahrplan
# Expected: Alfred JSON with a single warnEmpty item
```
