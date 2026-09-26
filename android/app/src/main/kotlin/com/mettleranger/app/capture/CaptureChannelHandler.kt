package com.mettleranger.app.capture

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the Dart `CaptureController` (lib/platform/capture_controller.dart)
 * to [CaptureForegroundService]. This class owns the `MethodChannel` and
 * `EventChannel`, and the [android.content.ServiceConnection] that binds to
 * the service for the life of one recording.
 */
class CaptureChannelHandler(private val activity: Activity) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    CaptureForegroundService.Listener {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private var boundService: CaptureForegroundService? = null
    private var serviceConnection: ServiceConnection? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun attach(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        unbindIfNeeded()
    }

    /** Called from `MainActivity.onRequestPermissionsResult`. Returns true if
     * this handler owned the request code, so the Activity knows not to look
     * elsewhere. */
    fun onRequestPermissionsResult(
        requestCode: Int,
        @Suppress("UNUSED_PARAMETER") permissions: Array<out String>,
        @Suppress("UNUSED_PARAMETER") grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        result.success(
            mapOf(
                "camera" to hasPermission(Manifest.permission.CAMERA),
                "microphone" to hasPermission(Manifest.permission.RECORD_AUDIO),
            ),
        )
        return true
    }

    // --- MethodChannel.MethodCallHandler ---

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasCameraPermission" -> result.success(hasPermission(Manifest.permission.CAMERA))
            "hasMicrophonePermission" -> result.success(hasPermission(Manifest.permission.RECORD_AUDIO))
            "requestPermissions" -> requestPermissions(result)
            "freeStorageBytes" -> result.success(DeviceStatus.freeStorageBytes(activity))
            "batteryPercent" -> result.success(DeviceStatus.batteryPercent(activity))
            "thermalStatus" -> result.success(DeviceStatus.thermalStatusOrdinal(activity))
            "startRecording" -> startRecording(call, result)
            "pauseRecording" -> pauseRecording(result)
            "resumeRecording" -> resumeRecording(result)
            "stopRecording" -> stopRecording(result)
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(permission: String) =
        ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED

    private fun requestPermissions(result: MethodChannel.Result) {
        val needed = mutableListOf<String>()
        if (!hasPermission(Manifest.permission.CAMERA)) needed.add(Manifest.permission.CAMERA)
        if (!hasPermission(Manifest.permission.RECORD_AUDIO)) needed.add(Manifest.permission.RECORD_AUDIO)

        if (needed.isEmpty()) {
            result.success(mapOf("camera" to true, "microphone" to true))
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(activity, needed.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    private fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        val sessionDir = call.argument<String>("sessionDir")
        val quality = call.argument<String>("quality") ?: "p720"
        if (sessionDir == null) {
            result.error("bad_args", "sessionDir is required", null)
            return
        }

        bindServiceThen { service ->
            service.listener = this
            service.startRecording(sessionDir, quality) { started -> result.success(started) }
        }
    }

    private fun pauseRecording(result: MethodChannel.Result) {
        val service = boundService
        if (service == null) {
            result.success(false)
            return
        }
        service.pauseRecording { ok -> result.success(ok) }
    }

    private fun resumeRecording(result: MethodChannel.Result) {
        val service = boundService
        if (service == null) {
            result.success(false)
            return
        }
        service.resumeRecording { ok -> result.success(ok) }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val service = boundService
        if (service == null) {
            result.success(
                mapOf("segments" to emptyList<Any?>(), "totalDurationMs" to 0, "totalSizeBytes" to 0),
            )
            return
        }
        service.stopRecording { payload ->
            result.success(payload)
            unbindIfNeeded()
        }
    }

    private fun bindServiceThen(action: (CaptureForegroundService) -> Unit) {
        boundService?.let {
            action(it)
            return
        }

        val intent = Intent(activity, CaptureForegroundService::class.java)
        ContextCompat.startForegroundService(activity, intent)

        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                val service = (binder as? CaptureForegroundService.LocalBinder)?.getService() ?: return
                boundService = service
                action(service)
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                boundService = null
            }
        }
        serviceConnection = connection
        activity.bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    private fun unbindIfNeeded() {
        serviceConnection?.let {
            try {
                activity.unbindService(it)
            } catch (_: IllegalArgumentException) {
                // Already unbound — the service may have torn itself down first.
            }
        }
        serviceConnection = null
        boundService = null
    }

    // --- EventChannel.StreamHandler ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // --- CaptureForegroundService.Listener ---

    override fun onEvent(event: Map<String, Any?>) {
        eventSink?.success(event)
        if (event["type"] == "error" && event["fatal"] == true) {
            unbindIfNeeded()
        }
    }

    companion object {
        const val METHOD_CHANNEL = "mettle_ranger/capture"
        const val EVENT_CHANNEL = "mettle_ranger/capture_events"
        private const val PERMISSION_REQUEST_CODE = 4242
    }
}
