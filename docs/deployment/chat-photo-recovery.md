# Old chat photos on Render

An image message can survive in PostgreSQL while its original bytes are absent.
New uploads already use `PrivateMediaFiles`; the old storage fallback previously
served a disk file without copying it into the database. Render's default local
filesystem is ephemeral, including across restarts and redeploys:
https://render.com/docs/disks

Another legacy case is a sent attachment with a missing `AttachedAt`. Reading it
as another member previously returned 403, and the 24-hour cleanup could attempt
to delete its file before the message foreign key stopped metadata deletion.

The fix:

- Reading an existing legacy file now copies its bytes into PostgreSQL, with a
  conflict-safe insert when two clients open the same image concurrently.
- A background preservation pass scans referenced chat/evidence files at startup
  and hourly, including legacy rows without an attach marker. Files that no one
  opens are preserved too. It reports missing files without deleting messages.
- Cleanup excludes attachments referenced by a chat message and evidence linked
  to an occurrence, checking again inside the household mutation lock.
- Current room members can read a sent attachment even when its old marker is
  missing. Another person's unsent uploads remain private.
- The Flutter image bubble distinguishes missing bytes (404/410), lost access
  (403), and temporary failures that can be retried.

## Recover actual old files

No production API credentials or database connection were available in this
session. The user's particular missing photo has not been inspected or restored
on Render, and these changes have not been deployed.

Before restarting/redeploying the existing service, preserve any surviving media
directory from that running instance or its persistent disk. Deploying new code
cannot retrieve bytes from a container filesystem that has already disappeared.

Run `backend/scripts/media-storage-audit.sql` against the intended database for
read-only daily counts. `sent_without_durable_blob` means the bytes are not in
PostgreSQL; it does not prove they are missing from every disk or backup.

Restore backups to a private, durable directory on the service, keeping the
original 32-character storage-key filenames. Set `MediaStorage__RootPath` to the
existing directory or add fallback locations as `MediaStorage__LegacyRootPaths__0`,
`MediaStorage__LegacyRootPaths__1`, etc. Relative paths resolve from the API's
content root. The preservation pass reads only keys referenced in the database;
it leaves source backup files in place. Check the preservation counts in logs
and rerun the audit to verify that recovered files now have database bytes.

If the old file is absent from the live disk, persistent volumes, backups and
the sender's original upload, its image cannot be reconstructed from the message
row. Do not replace it with a different image or claim a retry can recover it.
The sender can send the original photo again if they still have it.

No new schema migration is required beyond the existing
`20261030034437_AddDurablePrivateMedia` migration. Deploy both the backend and
Flutter client to apply the storage and error-state fixes.

## Validation

- Backend unit tests use Release because a running local Debug API holds its DLLs.
- PostgreSQL regressions exercise legacy files over 24 hours old, cleanup,
  concurrent promotion, missing files, room-member access, unsent privacy, and
  reading the same bytes after removing the old disk file and opening a new scope.
- Existing durable-storage and authenticated HTTP media tests remain included.
- Flutter tests cover missing/forbidden images, retry recovery and camera flows.
