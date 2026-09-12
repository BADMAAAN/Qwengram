# Qwengram History storage V1

This standalone module reserves **1009** (`1000 + 9`) as a Qwengram-local,
application-specific Postbox ordered collection. It is not an upstream allocation.
Keep this reservation unique when rebasing or adding collections. The literal
avoids importing TelegramCore's application-specific collection helper.

Each account owns its Postbox and archive. One entry identifies one message:
16 bytes, packed `PeerId.toInt64()` (8), message namespace (4), message id (4),
all signed two's-complement, big-endian. Account and thread are excluded.
Example `(0x0102030405060708, -1, 42)`:
`0102030405060708ffffffff0000002a`.

`CodableEntry.data` contains UTF-8 JSON encoded by Foundation, with required
`version: 1`, `key`, `revisions`, `events`, and `nextRevision`, plus optional
`threadId`. Use this store's decoder, not `CodableEntry.get`, which expects
Postbox's own encoding. Optional fields may be absent; required fields must be
present. Unknown JSON fields are ignored. Unknown schema versions and enum
values fail explicitly; future incompatible changes need a version migration.
Identifiers stay Int64/Int32 throughout Swift decoding (no Double conversion).

Revisions contain caller-supplied OLD snapshots, including server edit time,
text, UTF-16 entities, author, original timestamp, optional forward/reply/thread
metadata, and descriptive media metadata. Metadata dictionaries contain only
strings: use stable named fields and decimal strings for identifiers/timestamps.
Media dimensions are pixels, duration seconds and size bytes. Resource/file
identifiers must be descriptive, not credentials or downloadable payloads.
No media bytes or resources are retained; media may become unavailable.

Events preserve the supplied type/source/reason without inferring server or
local intent. `revisionNumber` is an optional reference that can outlive an
evicted revision. A future caller can append a snapshot and a delete event in
one Postbox transaction. These helpers do not install hooks or mutate Telegram
history. Callers handle thrown errors; throwing does not roll back earlier
operations in a Postbox transaction.

V1 limits: 1,000 archived messages, newest 20 revisions and 100 events per
message, and 262,144 bytes of JSON per record. Upsert trims oldest array entries,
then rejects oversized content before writing (no silent text truncation).
Successful writes move the record to the front and evict the collection tail
on insertion. Maximum record payload total is approximately 250 MiB, excluding
Postbox overhead. This bounds logical archive contents, not database file size.
Revision numbering starts at 1 and stays increasing across trimming; removing
a record resets its numbering if later recreated. Upsert replaces the record;
use append helpers for read-modify-write semantics.

Archive reads return the complete bounded list in last-write order because
Transaction exposes a full-list API. Corrupt entries fail reads explicitly;
remove-by-key and clear remain available without decoding.

Bazel target: `//Qwengram/HistoryStorage:QwengramHistoryStorage`. Foundation is
an SDK import; Postbox is the sole Bazel dependency. No TelegramCore dependency,
app wiring, UI, hooks, migrations, or upstream modifications are included.
