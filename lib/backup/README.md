Supabase auth and log backup, isolated behind an interface.

Two jobs only (spec §5): opt-in auth, and a periodic one-way upload of the
text log. No video. No real-time sync. No conflict resolution.

- `backup_client.dart` — the interface. Everything above this file depends
  on it, never on which implementation is live.
- `local_noop_backup_client.dart` — the default. Live with zero
  configuration; every method no-ops or throws a message a UI can show.
- `supabase_backup_client.dart` — the real client. Only live once
  `AppConfig.supabaseConfigured` is true (real `--dart-define` keys
  supplied at build time). Needs `supabase/schema.sql` applied to the
  connected project — nothing in this build applies it, since no real
  project is connected here to apply it against.
- `backup_projection.dart` — pins the wire shape from schema v1 (see its own
  header comment). Pure, no IO.
- `backup_service.dart` — walks the local database and hands the
  projection to whichever client is live.

**Honest limit on "periodic":** true OS-level periodic sync needs a
WorkManager-backed background task on Android — separate native scope this
build does not add. `BackupService.backupNow()` is triggered, not scheduled:
called from the "back this up" prompt on Train (spec §5's contextual
sign-in prompt) and from wherever a future release wires an explicit
"back up now" action. Wiring true background periodicity is a known gap,
not a silent one.
