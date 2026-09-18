import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'capture_controller.dart';

final captureControllerProvider = Provider<CaptureController>(
  (ref) => CaptureController(),
);

/// Free bytes on the recordings volume, for the Footage storage meter (spec
/// §2, screen 5). A snapshot, not a stream — nothing pushes storage-changed
/// events, so a screen that needs a fresh read after writing calls
/// `ref.invalidate(freeStorageBytesProvider)`, same as `totalStorageBytesProvider`.
final freeStorageBytesProvider = FutureProvider<int>(
  (ref) => ref.watch(captureControllerProvider).freeStorageBytes(),
);
