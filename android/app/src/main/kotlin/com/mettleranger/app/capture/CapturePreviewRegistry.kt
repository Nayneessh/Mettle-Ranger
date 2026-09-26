package com.mettleranger.app.capture

import androidx.camera.core.Preview

/**
 * Hands the active recording's CameraX [Preview] use case to whichever
 * [CapturePreviewView] platform views exist, without either side needing to
 * know the other's lifecycle.
 *
 * [CaptureForegroundService] only creates a [Preview] use case while a
 * recording is actually bound to the camera (one camera session per
 * recording — see the service's own doc comment), while the Flutter
 * [CapturePreviewView] can be created, torn down and recreated by the
 * widget tree at any time relative to that. A simple publish/subscribe
 * object lets either side come and go independently, rather than one
 * holding a reference to the other across a lifecycle it doesn't own.
 */
object CapturePreviewRegistry {
    private var current: Preview? = null
    private val listeners = mutableSetOf<(Preview?) -> Unit>()

    /** Called by the service when a recording starts (a real [Preview]) or
     * ends ([preview] = null). Every current subscriber is reattached. */
    fun publish(preview: Preview?) {
        current = preview
        listeners.toList().forEach { it(preview) }
    }

    /** Called by a [CapturePreviewView] as it's created. Immediately
     * delivers whatever preview is active right now, if any. Returns an
     * unsubscribe function to call on [CapturePreviewView.dispose]. */
    fun subscribe(listener: (Preview?) -> Unit): () -> Unit {
        listeners.add(listener)
        listener(current)
        return { listeners.remove(listener) }
    }
}
