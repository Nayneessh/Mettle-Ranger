# Mettle Ranger

A martial-arts training log for BJJ, boxing, Muay Thai, MMA and wrestling. It
records sessions on-camera and auto-chapters the footage by round, so a
specific spar or roll can be found and reviewed in seconds — no scrubbing.

Android first, Flutter, offline by default. Video never leaves the device.

**Status: Sprint 1 complete.** Scaffold, schema and CI only. No screens, no
camera, no backend.

## Getting started

```bash
flutter pub get
dart run build_runner build   # generated sources are git-ignored
flutter analyze --fatal-infos
flutter test
```

Generated Drift sources (`*.g.dart`) are not committed. Run `build_runner`
after a fresh clone and after any change to `lib/data/tables.dart`.

## Layout

```
lib/
  data/      Drift schema, DAOs, migrations
  domain/    timer engine, chapter stamping, load calc, storage policy
  screens/   Train, Setup, Player, Recap, Footage, Clip, Progress
  widgets/   shared components
  platform/  camera + timer platform channels (Android first)
  backup/    Supabase auth + log backup, behind an interface
```

Bottom nav carries three tabs — Train, Footage, Progress. Setup, Player, Recap
and Clip review are full-screen flows outside the tab bar.

## The rules that do not bend

Three data guarantees are load-bearing. Each has a test in
`test/data/schema_rules_test.dart` that fails loudly if it is broken.

1. **Deleting a recording never deletes its session.** Storage pressure can
   cost a user their footage. It must never cost them their training history.
2. **Chapter offsets are written by the round timer at round boundaries** —
   never derived afterwards from the video file. Segment rollover and dropped
   frames make the file an unreliable witness to when a round ended.
3. **Every video write is segmented.** A crash or force-kill costs the segment
   in flight, never the session. `Recording.localPath` therefore addresses a
   segment *directory*, not a single file.

## Scope boundaries

Not built, and not to be built: weight/set/rep logging, Plan vs Actual,
buddies or any social feature, nutrition, AI coaching, cloud video storage,
video sharing, real-time multi-device sync, and ads anywhere on Session
Player, Session Setup, Recap or Clip review.

Supabase has exactly two jobs: opt-in auth, and a periodic one-way backup of
the text log. It never carries video, never syncs in real time, and never
gates a core feature — the app works fully signed-out.

## Assumptions made in Sprint 1

Each of these was a call made in the absence of a stated answer. All are
reversible except the first.

| Decision | Value | Note |
| --- | --- | --- |
| Application ID | `com.mettleranger.app` | **Irreversible after publication.** Confirmed before `flutter create`. |
| Flutter / Dart | 3.35.5 stable / 3.9.2 | Pinned in `.github/workflows/ci.yml`. |
| Minimum Android SDK | 29 | Scoped storage and foreground-service semantics that §7's background recording depends on are only coherent from Q onward. Lowering to 26 widens reach but moves the camera risk. |
| Target / compile SDK | Flutter defaults | Left to the toolchain until the camera spike pins a requirement. |
| Java / JVM target | 17 | Required by the Android Gradle Plugin 8.9. |
| Drift | 2.28.x | `drift_flutter` for the on-device connection; `NativeDatabase.memory()` in tests. |
| Offset units | Milliseconds | Chapter-jump seeking is the core interaction; second precision is not enough. |
| `Recording.localPath` | A directory | Follows from the segmented-write rule. §4 lists it as a single column; it addresses a segment directory. |
| Generated sources | Git-ignored | Rebuilt by CI. Keeps generated diffs out of review. |
| Design system | Derived from spec prose | The seven canvas artboards were not available. Colour and type follow §1's direction; spacing scale, component shapes and states are open. Reconcile before the Train screen is called done. |

## CI

`flutter analyze --fatal-infos` and `flutter test` run on every push to any
branch; `main` stays buildable and nothing merges on red. A debug APK builds
after they pass.

No secrets are committed. Supabase, AdMob and RevenueCat keys live in `.env`
locally (git-ignored, see `.env.example`) and reach CI as GitHub Actions
secrets. The release signing keystore is generated locally, kept in a password
manager, and injected only at release time.
