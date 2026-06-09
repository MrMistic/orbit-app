package com.life.orbit

import android.Manifest
import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.life.orbit/intent"
    private var pendingRoute: String? = null
    private var pendingShareText: String? = null
    private var channel: MethodChannel? = null
    private var filePickerResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null

    companion object {
        private const val PICK_JSON_FILE = 1001
        private const val PERMISSION_ACTIVITY_RECOGNITION = 1002
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    result.success(route)
                }
                "getShareText" -> {
                    val text = pendingShareText
                    pendingShareText = null
                    result.success(text)
                }
                "refreshWidgets" -> {
                    refreshAllWidgets()
                    result.success(null)
                }
                "enableSleepDetection" -> {
                    SleepApiHelper.register(applicationContext)
                    result.success(null)
                }
                "disableSleepDetection" -> {
                    SleepApiHelper.unregister(applicationContext)
                    result.success(null)
                }
                "pickJsonFile" -> {
                    filePickerResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(intent, PICK_JSON_FILE)
                }
                "requestActivityRecognition" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION)
                        == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        permissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                            PERMISSION_ACTIVITY_RECOGNITION
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
        // Check initial intent.
        pendingRoute = intent?.getStringExtra("route")
        // Check for share intent on cold start.
        if (intent?.action == Intent.ACTION_SEND && intent?.type == "text/plain") {
            pendingShareText = intent?.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent?.getStringExtra(Intent.EXTRA_SUBJECT)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle share intents (ACTION_SEND).
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
            if (text != null) {
                channel?.invokeMethod("onShareText", text)
                return
            }
        }
        // Existing widget route handling.
        val route = intent.getStringExtra("route")
        if (route != null) {
            channel?.invokeMethod("onRoute", route)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_JSON_FILE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                val path = copyUriToCache(uri)
                filePickerResult?.success(path)
            } else {
                filePickerResult?.success(null)
            }
            filePickerResult = null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_ACTIVITY_RECOGNITION) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionResult?.success(granted)
            permissionResult = null
        }
    }

    /// Copies the content at [uri] to a temp file in cache dir and returns
    /// the absolute path. This is needed because content:// URIs can't be
    /// read directly from Dart.
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val tempFile = File(cacheDir, "import_backup.json")
            tempFile.outputStream().use { out ->
                inputStream.copyTo(out)
            }
            inputStream.close()
            tempFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun refreshAllWidgets() {
        val widgetClasses = listOf(
            NextTodoWidget::class.java,
            NextDateWidget::class.java,
            FitnessWidget::class.java,
            SleepWidget::class.java,
            BankrollWidget::class.java,
            SubscriptionsWidget::class.java,
            CycleWidget::class.java,
            PhotoWidget::class.java,
        )
        val manager = AppWidgetManager.getInstance(this)
        for (cls in widgetClasses) {
            val ids = manager.getAppWidgetIds(ComponentName(this, cls))
            if (ids.isNotEmpty()) {
                val intent = Intent(this, cls).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                sendBroadcast(intent)
            }
        }
    }
}
