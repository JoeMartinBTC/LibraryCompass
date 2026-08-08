# Backup — what protects the library, and how to get it back

The library lives in `~/Library/Application Support/LibraryCompass/Library.store`.
It is the only copy of anything typed by hand: ratings, comments, read dates. Losing
it loses work that no lookup can reconstruct.

## What runs

`~/bin/librarycompass-backup.sh`, scheduled by the LaunchAgent
`com.macstudio.librarycompass-backup` at **09:00, 14:00 and 21:00**, plus once whenever
the agent loads (so a run missed while the Mac was off is caught up).

Each run writes two dated files to `Library.store`'s neighbour directory `Backups/`, and
never overwrites an earlier one:

| File | Purpose |
|---|---|
| `Library-YYYYMMDD-HHMMSS.store` | full database, can be put straight back |
| `Library-YYYYMMDD-HHMMSS.csv` | all ten fields, readable without the app |

The newest 30 of each are kept. Log: `~/Library/Logs/librarycompass-backup.log`.

**The app may keep running during a backup.** That is the whole point of using
`sqlite3 .backup` rather than `cp`: SwiftData writes in WAL mode, so a raw file copy
catches a state with pending changes still outside the main file. `.backup` takes a
consistent snapshot mid-flight — exactly what's needed while books are being entered.

A run that produces a database with zero books deletes its own output and exits non-zero.
A backup nobody read is not a backup.

## Restoring

Close the app first, then swap the file in:

```bash
cd ~/Library/Application\ Support/LibraryCompass
osascript -e 'tell application "LibraryCompass" to quit'
mv Library.store Library.store.broken            # keep the bad one until you're sure
rm -f Library.store-wal Library.store-shm        # stale journals belong to the old file
cp Backups/Library-YYYYMMDD-HHMMSS.store Library.store
open -a LibraryCompass
```

Check before trusting it — the count should match what you expect:

```bash
sqlite3 Backups/Library-YYYYMMDD-HHMMSS.store "select count(*) from ZBOOK;"
```

The CSV is the fallback when the database itself is suspect: it opens in any spreadsheet
and carries every field, so nothing is locked inside an app-specific format.

## What this does *not* cover

The backups sit on the same disk as the library. They protect against accidental
deletion, a bad maintenance run, or a corrupted store — not against losing the disk.
Time Machine covers that, and the folder is included in it; local APFS snapshots exist
as well. For anything irreplaceable, keep an occasional copy of the CSV somewhere else.
