package com.life.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-registers for Sleep API updates after device reboot.
 * Only registers if the user has opted in (stored in SharedPreferences).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val enabled = prefs.getBoolean("flutter.sleep_auto_detect", false)
            if (enabled) {
                SleepApiHelper.register(context)
            }
        }
    }
}
