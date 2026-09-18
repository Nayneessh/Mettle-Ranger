import 'package:flutter/services.dart';

import '../domain/enums.dart';
import '../domain/storage_policy.dart';
import 'capture_events.dart';

/// Which runtime permissions the capture pipeline was granted.
class PermissionResult {
  const PermissionResult({required this.camera, required this.microphone});

  final bool camera;
  final bool microphone;

  bool get granted => camera && microphone;
}

/// Dart-side gateway to the native capture pipeline (spec §7).
///
/// Everything below this class's public surface is a `MethodChannel` call or
/// an `EventChannel` stream into `android/app/.../capture/`. Flutter's own
/// camera plugins do not survive screen lock or backgrounding, so recording
/// runs through a Kotlin foreground service the Dart side only ever talks to
/// through this channel — see `lib/platform/README.md`.
///
/// **Status**: code-complete against the CameraX API, but unvalidated on
/// physical hardware — this build environment has no device or emulator.
/// Nothing here has passed the spec §9 Sprint 3 gate (survives lock,
/// backgrounding, force-kill on a real mid-range Android device). Treat
/// every call as unproven until that spike runs.
class CaptureController {
  static const MethodChannel _methods = MethodChannel('mettle_ranger/capture');
  static const EventChannel _events = EventChannel(
    'mettle_ranger/capture_events',
  );

  Stream<CaptureEvent>? _eventStream;

  /// Status ticks, segment rollovers and errors while a recording is active.
  /// A broadcast stream — safe for the Player screen and a background
  /// storage-watcher to both listen at once.
  Stream<CaptureEvent> get events {
    return _eventStream ??= _events.receiveBroadcastStream().map((raw) {
      return CaptureEvent.fromMap(Map<Object?, Object?>.from(raw as Map));
    }).asBroadcastStream();
  }

  Future<bool> hasCameraPermission() async =>
      (await _methods.invokeMethod<bool>('hasCameraPermission')) ?? false;

  Future<bool> hasMicrophonePermission() async =>
      (await _methods.invokeMethod<bool>('hasMicrophonePermission')) ?? false;

  /// Prompts for camera and microphone permission if either is missing.
  /// Must be called after the consent screen (spec §7) has already been
  /// accepted — this method does not check consent itself.
  Future<PermissionResult> requestPermissions() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'requestPermissions',
    );
    return PermissionResult(
      camera: result?['camera'] as bool? ?? false,
      microphone: result?['microphone'] as bool? ?? false,
    );
  }

  /// Free space on the volume recordings are written to. Feeds
  /// `StoragePolicy.evaluateBeforeStart` before Setup lets a session begin,
  /// and the live storage readout on Player.
  Future<int> freeStorageBytes() async =>
      (await _methods.invokeMethod<int>('freeStorageBytes')) ?? 0;

  Future<int> batteryPercent() async =>
      (await _methods.invokeMethod<int>('batteryPercent')) ?? 100;

  Future<ThermalLevel> thermalStatus() async {
    final ordinal = await _methods.invokeMethod<int>('thermalStatus');
    return thermalLevelFromOrdinal(ordinal);
  }

  /// Starts the foreground service and begins segmented recording into
  /// [sessionDirectoryPath], an app-private directory Setup/Player create
  /// under the platform's app-specific external files area — never a shared
  /// or gallery-visible location (spec §7).
  ///
  /// Returns false without throwing on a permission or camera-open failure;
  /// callers should treat that as "could not start," not crash the session.
  Future<bool> startRecording({
    required String sessionDirectoryPath,
    required CaptureQuality quality,
  }) async {
    final ok = await _methods.invokeMethod<bool>('startRecording', {
      'sessionDir': sessionDirectoryPath,
      'quality': quality.name,
    });
    return ok ?? false;
  }

  /// Stops recording, finalizes the in-flight segment, and returns every
  /// segment the session produced — exactly the rows `RecordingDao` needs
  /// via `insertSegments`.
  Future<CaptureStopResult> stopRecording() async {
    final raw = await _methods.invokeMethod<Map<Object?, Object?>>(
      'stopRecording',
    );
    if (raw == null) {
      return const CaptureStopResult(
        segments: [],
        totalDurationMs: 0,
        totalSizeBytes: 0,
      );
    }
    return CaptureStopResult.fromMap(raw);
  }
}
