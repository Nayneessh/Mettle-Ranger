package com.mettleranger.app.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.PendingRecording
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import java.io.File

/**
 * The capture pipeline (spec §7): CameraX recording, running in a foreground
 * service so it survives a locked screen and backgrounding — the one thing
 * a Flutter camera plugin alone cannot do, and the reason this exists in
 * Kotlin at all rather than as a plugin.
 *
 * [LifecycleService] rather than a plain `Service`: CameraX binds to a
 * `LifecycleOwner`, and this service is its own, so recording does not
 * depend on an `Activity` staying alive.
 *
 * **Status**: implemented against the CameraX Recorder API as documented,
 * never run against a camera. There is no device or emulator in the
 * environment this was written in. Nothing here has passed the spec §9
 * Sprint 3 gate (lock / background / force-kill on real hardware) — that is
 * the validation this code exists to be put through, not validation it has
 * already had.
 *
 * One recording per service instance: [stopRecording] tears the service
 * down, so a new session starts a fresh instance rather than reusing camera
 * state across sessions. Simpler, and a training app records one session at
 * a time regardless.
 */
class CaptureForegroundService : LifecycleService() {

    interface Listener {
        /** Every event this service produces, forwarded verbatim to the
         * Flutter EventChannel as a `Map` — see `CaptureEvent.fromMap`. */
        fun onEvent(event: Map<String, Any?>)
    }

    inner class LocalBinder : Binder() {
        fun getService(): CaptureForegroundService = this@CaptureForegroundService
    }

    private val binder = LocalBinder()
    private val mainThreadExecutor by lazy { ContextCompat.getMainExecutor(this) }
    private val rolloverHandler = Handler(Looper.getMainLooper())
    private val rolloverRunnable = Runnable { rolloverSegment() }

    var listener: Listener? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var recorder: Recorder? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var preview: Preview? = null
    private var activeRecording: Recording? = null

    private var sessionDir: File? = null
    private var segmentIndex = 0
    private var globalElapsedMsAtSegmentStart = 0L
    private val finishedSegments = mutableListOf<SegmentResult>()
    private var isStopping = false
    private var startAcknowledged = false

    /** True between a confirmed `pauseRecording()` and the matching
     * `resumeRecording()`. Guards the rollover timer (below) and lets
     * `stopRecording()` finalize correctly from a paused state. */
    private var isPaused = false

    /** Wall-clock deadline (`SystemClock.elapsedRealtime()`) the current
     * segment's rollover is scheduled for. Recomputed relative to this, not
     * reissued as a flat 5-minute delay, so a pause doesn't silently gift
     * the next segment extra recorded time or roll over mid-pause on stale
     * wall-clock elapsed. */
    private var segmentRolloverDeadline = 0L

    /** Resolved once, the first time this recording confirms it is really
     * writing — either `true` on the first segment's Start event, or
     * `false` on any failure before that. */
    private var onStartResolved: ((Boolean) -> Unit)? = null
    private var onStopFinished: ((Map<String, Any?>) -> Unit)? = null

    private data class SegmentResult(
        val index: Int,
        val fileName: String,
        val startOffsetMs: Long,
        val durationMs: Long,
        val sizeBytes: Long,
    )

    override fun onCreate() {
        super.onCreate()
        startForegroundWithNotification()
    }

    override fun onBind(intent: Intent): IBinder {
        super.onBind(intent)
        return binder
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        return START_NOT_STICKY
    }

    // --- Public API, called by CaptureChannelHandler through the binder ---

    fun startRecording(
        directoryPath: String,
        qualityName: String,
        onStart: (Boolean) -> Unit,
    ) {
        if (activeRecording != null || cameraProvider != null) {
            onStart(false)
            listener?.onEvent(
                errorEvent("startRecording called while already recording", fatal = false),
            )
            return
        }

        if (!hasPermission(android.Manifest.permission.CAMERA) ||
            !hasPermission(android.Manifest.permission.RECORD_AUDIO)
        ) {
            onStart(false)
            listener?.onEvent(errorEvent("camera or microphone permission not granted", fatal = true))
            return
        }

        val dir = File(directoryPath)
        if (!dir.exists() && !dir.mkdirs()) {
            onStart(false)
            listener?.onEvent(errorEvent("could not create session directory: $directoryPath", fatal = true))
            return
        }

        sessionDir = dir
        segmentIndex = 0
        globalElapsedMsAtSegmentStart = 0L
        finishedSegments.clear()
        isStopping = false
        isPaused = false
        startAcknowledged = false
        onStartResolved = onStart

        val quality = qualityFromName(qualityName)
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                val qualitySelector =
                    QualitySelector.from(quality, FallbackStrategy.lowerQualityOrHigherThan(quality))
                val builtRecorder = Recorder.Builder().setQualitySelector(qualitySelector).build()
                val capture = VideoCapture.withOutput(builtRecorder)
                val builtPreview = Preview.Builder().build()

                provider.unbindAll()
                provider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    builtPreview,
                    capture,
                )

                cameraProvider = provider
                recorder = builtRecorder
                videoCapture = capture
                preview = builtPreview
                CapturePreviewRegistry.publish(builtPreview)

                beginSegment()
            } catch (error: Exception) {
                listener?.onEvent(errorEvent("camera bind failed: ${error.message}", fatal = true))
                resolveStart(false)
            }
        }, mainThreadExecutor)
    }

    /** Pauses the in-flight segment (CameraX `Recording.pause()`) and the
     * segment-rollover timer together, so a paused recording neither writes
     * frames nor gets rolled over by stale wall-clock elapsed while nothing
     * is being recorded. `onResult(false)` when there is nothing to pause. */
    fun pauseRecording(onResult: (Boolean) -> Unit) {
        val recording = activeRecording
        if (recording == null || isPaused) {
            onResult(false)
            return
        }
        isPaused = true
        rolloverHandler.removeCallbacks(rolloverRunnable)
        recording.pause()
        onResult(true)
    }

    /** Resumes a paused segment, rescheduling rollover for whatever time was
     * actually left in this segment rather than a fresh 5 minutes. */
    fun resumeRecording(onResult: (Boolean) -> Unit) {
        val recording = activeRecording
        if (recording == null || !isPaused) {
            onResult(false)
            return
        }
        isPaused = false
        val remaining = (segmentRolloverDeadline - SystemClock.elapsedRealtime())
            .coerceAtLeast(1_000L)
        rolloverHandler.postDelayed(rolloverRunnable, remaining)
        recording.resume()
        onResult(true)
    }

    fun stopRecording(onStopped: (Map<String, Any?>) -> Unit) {
        if (activeRecording == null) {
            onStopped(stopResultPayload())
            tearDown()
            return
        }
        onStopFinished = onStopped
        isStopping = true
        isPaused = false
        rolloverHandler.removeCallbacks(rolloverRunnable)
        activeRecording?.stop()
    }

    // --- Segment lifecycle ---

    private fun beginSegment() {
        val dir = sessionDir ?: return
        val builtRecorder = recorder ?: return
        val fileName = "segment_%04d.mp4".format(segmentIndex)
        val outputFile = File(dir, fileName)

        try {
            val outputOptions = FileOutputOptions.Builder(outputFile).build()
            var pending: PendingRecording = builtRecorder.prepareRecording(this, outputOptions)
            if (hasPermission(android.Manifest.permission.RECORD_AUDIO)) {
                pending = pending.withAudioEnabled()
            }
            activeRecording = pending.start(mainThreadExecutor) { event ->
                handleVideoRecordEvent(event, fileName)
            }
            segmentRolloverDeadline = SystemClock.elapsedRealtime() + SEGMENT_DURATION_MS
            rolloverHandler.postDelayed(rolloverRunnable, SEGMENT_DURATION_MS)
        } catch (error: Exception) {
            listener?.onEvent(errorEvent("could not start segment $segmentIndex: ${error.message}", fatal = true))
            resolveStart(false)
        }
    }

    private fun rolloverSegment() {
        // Stops the current segment; its Finalize handler starts the next
        // one. A crash between here and the next Start event costs this one
        // segment, never the ones already finalized — RULE 3 of spec §4.
        // Never reached while paused: pauseRecording() cancels this callback
        // and resumeRecording() reschedules it, so this fires only against
        // a segment that is actually still recording.
        activeRecording?.stop()
    }

    private fun handleVideoRecordEvent(event: VideoRecordEvent, fileName: String) {
        when (event) {
            is VideoRecordEvent.Start -> {
                listener?.onEvent(
                    mapOf("type" to "segment_started", "index" to segmentIndex, "fileName" to fileName),
                )
                resolveStart(true)
            }
            is VideoRecordEvent.Status -> {
                val elapsedMs =
                    globalElapsedMsAtSegmentStart + (event.recordingStats.recordedDurationNanos / 1_000_000)
                val bytesSoFar =
                    finishedSegments.sumOf { it.sizeBytes } + event.recordingStats.numBytesRecorded
                listener?.onEvent(
                    mapOf(
                        "type" to "status",
                        "elapsedMs" to elapsedMs,
                        "sizeBytesSoFar" to bytesSoFar,
                        "segmentIndex" to segmentIndex,
                        "thermalLevel" to DeviceStatus.thermalStatusOrdinal(this),
                        "batteryPercent" to DeviceStatus.batteryPercent(this),
                    ),
                )
            }
            is VideoRecordEvent.Finalize -> {
                if (event.hasError()) {
                    listener?.onEvent(
                        errorEvent("segment $segmentIndex finalize error code ${event.error}", fatal = false),
                    )
                }
                val durationMs = event.recordingStats.recordedDurationNanos / 1_000_000
                val sizeBytes = event.recordingStats.numBytesRecorded
                val segment = SegmentResult(
                    index = segmentIndex,
                    fileName = fileName,
                    startOffsetMs = globalElapsedMsAtSegmentStart,
                    durationMs = durationMs,
                    sizeBytes = sizeBytes,
                )
                finishedSegments.add(segment)
                listener?.onEvent(
                    mapOf(
                        "type" to "segment_finished",
                        "index" to segment.index,
                        "fileName" to segment.fileName,
                        "startOffsetMs" to segment.startOffsetMs,
                        "durationMs" to segment.durationMs,
                        "sizeBytes" to segment.sizeBytes,
                    ),
                )
                globalElapsedMsAtSegmentStart += durationMs
                activeRecording = null

                if (isStopping) {
                    val payload = stopResultPayload()
                    tearDown()
                    onStopFinished?.invoke(payload)
                    onStopFinished = null
                } else {
                    segmentIndex += 1
                    beginSegment()
                }
            }
            is VideoRecordEvent.Pause -> {
                listener?.onEvent(mapOf("type" to "paused"))
            }
            is VideoRecordEvent.Resume -> {
                listener?.onEvent(mapOf("type" to "resumed"))
            }
            else -> Unit
        }
    }

    private fun resolveStart(success: Boolean) {
        if (startAcknowledged) return
        startAcknowledged = true
        onStartResolved?.invoke(success)
        onStartResolved = null
    }

    private fun stopResultPayload(): Map<String, Any?> = mapOf(
        "segments" to finishedSegments.map {
            mapOf(
                "index" to it.index,
                "fileName" to it.fileName,
                "startOffsetMs" to it.startOffsetMs,
                "durationMs" to it.durationMs,
                "sizeBytes" to it.sizeBytes,
            )
        },
        "totalDurationMs" to finishedSegments.sumOf { it.durationMs },
        "totalSizeBytes" to finishedSegments.sumOf { it.sizeBytes },
    )

    private fun tearDown() {
        rolloverHandler.removeCallbacks(rolloverRunnable)
        CapturePreviewRegistry.publish(null)
        cameraProvider?.unbindAll()
        cameraProvider = null
        recorder = null
        videoCapture = null
        preview = null
        activeRecording = null
        isPaused = false
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun hasPermission(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun errorEvent(message: String, fatal: Boolean): Map<String, Any?> =
        mapOf("type" to "error", "message" to message, "fatal" to fatal)

    private fun qualityFromName(name: String): Quality = when (name) {
        "p1080" -> Quality.FHD
        else -> Quality.HD
    }

    // --- Foreground notification ---

    private fun startForegroundWithNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Session recording",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Shown while Mettle Ranger is recording a training session." }
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Recording session")
            .setContentText("Mettle Ranger is recording this session on-device.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .build()

        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
        )
    }

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "mettle_ranger_capture"
        private const val NOTIFICATION_ID = 4201

        // Time-based rollover, decoupled from round boundaries on purpose:
        // crash resilience (spec §4 RULE 3) and chapter placement (RULE 2)
        // are two different concerns. domain/segment_resolver.dart is what
        // reconciles a chapter's global offset against wherever a segment
        // boundary actually landed.
        private const val SEGMENT_DURATION_MS = 5 * 60 * 1000L
    }
}
