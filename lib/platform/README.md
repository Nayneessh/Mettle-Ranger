Camera and timer platform-channel code (Android first).

CameraX behind a foreground service. Flutter camera plugins do not survive
screen lock or backgrounding, which spec §7 makes non-negotiable, so capture
is native and the Dart side only ever sees a channel.

Nothing here ships before the Sprint 1.5 spike passes on real hardware.
