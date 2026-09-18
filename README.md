# Mettle Ranger

A martial-arts training log for BJJ, boxing, Muay Thai, MMA and wrestling. It
records sessions on-camera and auto-chapters the footage by round, so a
specific spar or roll can be found and reviewed in seconds — no scrubbing.

Android first, Flutter, offline by default. Video never leaves the device.

**Status: all seven screens are built and wired to real data**, alongside
the native capture pipeline, backup and monetisation scaffolding. See
**What is not, and cannot be, verified here** below before treating this as
release-ready — the honest gaps are specific, not hand-waved.

## Getting started

```bash
flutter pub get
dart run build_runner build   # generated sources are git-ignored
flutter analyze --fatal-infos
flutter test
```

Generated Drift sources (`*.g.dart`) are not committed. Run `build_runner`
after a fresh clone and after any change to `lib/data/tables.dart`.

To build with real backend/ad/IAP credentials rather than the safe defaults:

```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=ADMOB_APP_ID=... \
  --dart-define=ADMOB_BANNER_UNIT_ID=... \
  --dart-define=REVENUECAT_PUBLIC_KEY=...
```

Every one of those is optional — see `lib/config/app_config.dart`. With none
supplied, the app runs fully functional: Supabase backup is inert, AdMob
serves Google's own public test ads, and the remove-ads IAP is inert.

## Layout

```
lib/
  data/      Drift schema, DAOs, migrations
  domain/    timer engine, chapter stamping, load calc, storage policy,
             segment resolver — pure Dart, no Flutter/DB/platform imports
  screens/   Train, Setup, Player, Recap, Footage, Clip, Progress, Consent
  widgets/   shared components
  platform/  camera + timer platform channels (Android first)
  backup/    Supabase auth + log backup, behind an interface
  ads/       AdMob banners + RevenueCat remove-ads IAP, behind interfaces
  config/    third-party credentials, all optional (see above)
android/     native platform-channel implementation (CameraX capture)
supabase/    Postgres schema + RLS policies for whoever connects a real project
```

Bottom nav carries three tabs — Train, Footage, Progress. Setup, Player, Recap
and Clip review are full-screen flows outside the tab bar. Consent is a
full-screen flow triggered from Setup/Player the first time a recording
starts — never a gate on app open (spec §5, §7).

## The rules that do not bend

Three data guarantees are load-bearing. Each has a test in
`test/data/schema_rules_test.dart` that fails loudly if it is broken.

1. **Deleting a recording never deletes its session.** Storage pressure can
   cost a user their footage. It must never cost them their training history.
2. **Chapter offsets are written by the round timer at round boundaries** —
   never derived afterwards from the video file. Segment rollover and dropped
   frames make the file an unreliable witness to when a round ended.
3. **Every video write is segmented.** A crash or force-kill costs the segment
   in flight, never the session. `Recording.localPath` addresses a segment
   *directory*; the `Segments` table (added to schema v1, since nothing has
   shipped yet) maps each file's place on the recording's global timeline.
   `domain/segment_resolver.dart` is what turns a chapter's global offset
   into "this file, this local offset" — with tests in `test/domain`.

## What is not, and cannot be, verified here

This was built in a cloud container with no Android device or emulator and
no live Supabase/AdMob/RevenueCat project. Specifically:

- **The capture pipeline is code-complete, not hardware-validated.**
  `android/app/.../capture/CaptureForegroundService.kt` implements CameraX
  segmented recording behind a foreground service, written against the
  documented API. It has never run against a camera. Nothing here has
  passed the spec §9 Sprint 3 gate (survives lock, backgrounding, a
  force-kill on a real mid-range Android device) — that gate is what this
  code exists to be put through next, not something it has already cleared.
  Storage bitrate estimates in `domain/storage_policy.dart` are placeholders
  for the same reason — flagged explicitly in that file.
- **Trim-on-save is file-level, not frame-accurate.** A segment survives
  whole if any flagged chapter's start falls in it (`recap/trim_on_save.dart`
  explains why). Frame-accurate cutting needs a re-encode pipeline, which is
  real scope beyond this build.
- **A chapter that crosses a segment boundary plays, and loops, only to the
  end of that segment.** Segments roll over on a 5-minute timer independent
  of round length, so this is a rare edge, not the common case — see
  `domain/segment_resolver.dart`.
- **Backup is triggered, not truly periodic.** True background sync needs
  Android WorkManager, separate native scope not added here — see
  `lib/backup/README.md`.
- **No widget/integration tests.** `test/` covers the data and domain layers
  (52 tests) — the layers where a bug silently corrupts a user's log. The
  screens themselves are exercised by `flutter analyze` and, eventually, a
  human on a device.
- **No real third-party credentials.** Every integration in `config/`,
  `backup/` and `ads/` is inert by default and activates only once real
  keys are supplied (see *Getting started*).

## Scope boundaries

Not built, and not to be built: weight/set/rep logging, Plan vs Actual,
buddies or any social feature, nutrition, AI coaching, cloud video storage,
video sharing, real-time multi-device sync, and ads anywhere on Session
Player, Session Setup, Recap or Clip review — `AdSlot` (`lib/ads/ad_slot.dart`)
has no member for those four screens, so this is enforced by the type
system, not just a rule someone has to remember.

Supabase has exactly two jobs: opt-in auth, and a periodic one-way backup of
the text log. It never carries video, never syncs in real time, and never
gates a core feature — the app works fully signed-out.

## Assumptions and additions beyond the literal spec

Each of these was a call made in the absence of a stated answer, or a gap
the schema/UI needed filled. All are reversible except the first.

| Decision | Value | Note |
| --- | --- | --- |
| Application ID | `com.mettleranger.app` | **Irreversible after publication.** Confirmed before `flutter create`. |
| Flutter / Dart | 3.35.5 stable / 3.9.2 | Pinned in `.github/workflows/ci.yml`. |
| Minimum Android SDK | 29 | Scoped storage, foreground-service semantics and `PowerManager.currentThermalStatus` all need it. |
| Java / JVM target | 17 | Required by the Android Gradle Plugin 8.9. |
| Offset units | Milliseconds | Chapter-jump seeking is the core interaction; second precision is not enough. |
| `Recording.localPath` | A directory | Follows from the segmented-write rule; paired with the `Segments` table. |
| Round type field on Setup | Added | §2's screen list doesn't name one, but `Rounds.mode` is required and Progress's sparring-ratio chart needs it. Applied uniformly to every round in a session. |
| Design system | Derived from spec prose | The seven canvas artboards were not available. Colour (deep green ground, gold accent) and Anton display numerals follow §1 directly; spacing scale and component shapes are this build's own, not matched pixel-for-pixel against a canvas that doesn't exist here. |
| Discipline colour palette | 5 fixed hues | Gold/green/orange/blue/violet, in `Discipline.values` order, for the Progress tab's discipline split — never cycled, never reassigned when filtered. |
| Generated sources | Git-ignored | Rebuilt by CI. Keeps generated diffs out of review. |

## CI

`flutter analyze --fatal-infos` and `flutter test` run on every push to any
branch; `main` stays buildable and nothing merges on red. A debug APK builds
after they pass, with any configured secrets passed through as
`--dart-define` values (see *Getting started*).

No secrets are committed. Supabase, AdMob and RevenueCat keys live in `.env`
locally (git-ignored, see `.env.example`) and reach CI as GitHub Actions
secrets. The release signing keystore is generated locally, kept in a password
manager, and injected only at release time.
