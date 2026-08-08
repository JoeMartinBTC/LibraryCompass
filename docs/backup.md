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

## Offsite copy

The same run also builds an **AES-256 encrypted disk image** holding that run's database
and CSV, and files it in iCloud Drive as
`Backups/LibraryCompassBackup-YYYYMMDD-HHMMSS.dmg`, newest 14 kept.
`LibraryCompassBackup-LATEST.txt` names the current one.

Encrypted because the library carries personal reading notes — places, dates, verdicts.
That is not something to put in a cloud in the clear. The password comes from the keychain
service `brain-backup`, shared with the other vault backups so there is one recovery
password to remember rather than several to lose.

Nothing reaches iCloud unverified. The image must report as encrypted, mount, and contain
a database with the **same book count** as the local snapshot. If any check fails the run
says so and leaves the existing offsite copies untouched — a broken backup must never
displace a good one.

One trap worth knowing: the count is taken from a copy pulled out of the mounted image,
not from the file inside it. SQLite refuses to open a WAL database on a read-only volume,
so counting in place returns zero and would reject every backup instead of only the bad
ones.

To restore from it: open the `.dmg` (Finder, double-click), enter the `brain-backup`
password, and copy the `.store` out — then follow the restore steps above.

## What this does *not* cover

Losing the Mac and the iCloud account at once. Local snapshots protect against mistakes,
the encrypted iCloud copy against losing the disk. Time Machine covers the folder as well
(it is `[Included]`), though in this setup its external disks have failed before, so the
iCloud copy is the one to rely on.
