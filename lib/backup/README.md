Supabase auth and log backup, isolated behind an interface.

Two jobs only (spec §5): opt-in auth, and a periodic one-way upload of the
text log. No video. No real-time sync. No conflict resolution.

backup_projection.dart pins the wire shape from the first commit; the client
that uploads it arrives at Sprint 11.
