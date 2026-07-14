---
name: db-reset
description: Reset or re-seed the local SQLite database (backend/database.sqlite) for the mortgage calculator. Use when asked to reset the db, wipe test data, re-seed sample areas/promos/payment methods, or when a schema change in init.sql needs to be picked up.
---

`backend/database.sqlite` is a local-only, gitignored SQLite file. There is
no migration system (per `CLAUDE.md`) — `backend/database/init.sql` is the
entire schema, applied with `CREATE TABLE IF NOT EXISTS`.

## First: figure out which of the two situations this actually is

**A. "Just make sure the db exists and has sample data"** (fresh clone, or
after pulling someone else's changes) — you do **not** need to delete the
file. Both scripts are safe to run against an existing db as-is:
- `init.sql` is `IF NOT EXISTS` — running it again is a no-op if tables
  already exist.
- `seed.sql` uses `INSERT OR IGNORE` with fixed, explicit IDs (areas 42/131/
  205/312/501, promos 7/8/9, payment methods 1-4) — running it again does
  **not** duplicate rows, it just no-ops on conflict. (This was a stale
  claim in `run-phpcalculator/SKILL.md`, which used to say re-running
  seed.sql "just re-adds sample rows" — verified against the actual SQL,
  it doesn't, and that file's since been corrected too.)

For this case, just run:
```bash
cd backend
sqlite3 database.sqlite < database/init.sql
sqlite3 database.sqlite < database/seed.sql
```

**B. "Actually wipe and start over"** (schema in `init.sql` changed —
e.g. a new column or table — and `IF NOT EXISTS` means an existing db
won't pick that up; or the data is just messy and you want a clean slate).
This requires deleting the file first, which is destructive to anything
in the `requests` table (real submitted applications aren't seeded by
`seed.sql` — they only exist if someone actually used the calculator).

## Before deleting the file (case B)

Check whether there's anything in `requests` worth losing:
```bash
cd backend
sqlite3 database.sqlite "SELECT COUNT(*) FROM requests;" 2>/dev/null || echo "0 (no db file yet)"
```
If the count is 0 (or the file doesn't exist), delete-and-recreate freely.
If it's non-zero, tell the user how many rows are about to be lost and get
explicit confirmation before deleting — this is real, unrecoverable
user-submitted data, not sample rows, and there's no backup mechanism.

Once confirmed (or count is 0):
```bash
cd backend
rm database.sqlite
sqlite3 database.sqlite < database/init.sql
sqlite3 database.sqlite < database/seed.sql
```

## After either path

Sanity-check the four tables exist and are populated (mirrors what CI's
"Database Schema Check" job does):
```bash
cd backend
sqlite3 database.sqlite ".tables"
sqlite3 database.sqlite "SELECT COUNT(*) FROM areas;"   # expect 5
sqlite3 database.sqlite "SELECT COUNT(*) FROM promos;"  # expect 3
sqlite3 database.sqlite "SELECT COUNT(*) FROM payment_methods;"  # expect 4
```
