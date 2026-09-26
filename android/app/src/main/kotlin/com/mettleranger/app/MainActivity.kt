package com.mettleranger.app

import com.mettleranger.app.capture.CaptureChannelHandler
import com.mettleranger.app.capture.CapturePreviewViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var captureChannelHandler: CaptureChannelHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureChannelHandler = CaptureChannelHandler(this)
        captureChannelHandler.attach(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            CapturePreviewViewFactory.VIEW_TYPE,
            CapturePreviewViewFactory(),
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        captureChannelHandler.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        captureChannelHandler.detach()
        super.onDestroy()
    }
}
