package com.life.orbit

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.life.orbit/intent"
    private var pendingRoute: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getRoute") {
                val route = pendingRoute
                pendingRoute = null
                result.success(route)
            } else {
                result.notImplemented()
            }
        }
        // Check initial intent.
        pendingRoute = intent?.getStringExtra("route")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val route = intent.getStringExtra("route")
        if (route != null) {
            // If Flutter is already running, invoke the method directly.
            channel?.invokeMethod("onRoute", route)
        }
    }
}
