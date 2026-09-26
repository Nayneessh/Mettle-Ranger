package com.mettleranger.app.capture

import android.content.Context
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * The self-view on the Player screen: shows whatever the active recording's
 * camera is actually pointed at, so the person recording can see themselves
 * the same way any ordinary camera app would show a live viewfinder.
 *
 * [PreviewView.ImplementationMode.COMPATIBLE] forces a `TextureView` rather
 * than CameraX's default `SurfaceView`-when-possible — deliberately, since
 * Flutter's [io.flutter.plugin.platform.PlatformView] hosts this through a
 * virtual display by default, and a `SurfaceView` inside a virtual display
 * is the well-known combination that renders black/blank on many devices.
 */
class CapturePreviewView(context: Context) : PlatformView {
    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }

    private val unsubscribe = CapturePreviewRegistry.subscribe { preview ->
        preview?.setSurfaceProvider(previewView.surfaceProvider)
    }

    override fun getView() = previewView

    override fun dispose() {
        unsubscribe()
    }
}

class CapturePreviewViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CapturePreviewView(context)
    }

    companion object {
        const val VIEW_TYPE = "mettle_ranger/capture_preview"
    }
}
