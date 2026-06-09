package com.life.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import com.google.android.gms.location.SleepClassifyEvent
import com.google.android.gms.location.SleepSegmentEvent

/**
 * Receives sleep events from the Google Sleep API.
 *
 * SleepSegmentEvent: fired once after the user wakes up, contains the full
 * sleep session (start time, end time, status).
 *
 * SleepClassifyEvent: fired every ~10 minutes with a confidence score
 * (0-100) indicating likelihood the user is asleep. We don't use these
 * directly but could use them for real-time status in the future.
 */
class SleepReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (SleepSegmentEvent.hasEvents(intent)) {
            val events = SleepSegmentEvent.extractEvents(intent)
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            for (event in events) {
                // Only store successful detections (status 0 = OK).
                if (event.status == SleepSegmentEvent.STATUS_SUCCESSFUL) {
                    storeSleepSegment(prefs, event)
                }
            }
        }
        // We ignore SleepClassifyEvents for now — they're periodic confidence
        // updates, not full sessions.
    }

    private fun storeSleepSegment(prefs: SharedPreferences, event: SleepSegmentEvent) {
        // Store as a pending sleep entry for Flutter to pick up on next app open.
        // Format: "startMillis|endMillis" appended to a list.
        val existing = prefs.getString("flutter.pending_sleep_segments", "") ?: ""
        val startMs = event.startTimeMillis
        val endMs = event.endTimeMillis
        val entry = "$startMs|$endMs"
        val updated = if (existing.isEmpty()) entry else "$existing;$entry"
        prefs.edit().putString("flutter.pending_sleep_segments", updated).apply()
    }
}
