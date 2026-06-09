package com.life.orbit

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.SleepSegmentRequest

/**
 * Helper to register/unregister for Google Sleep API updates.
 */
object SleepApiHelper {
    private const val TAG = "SleepApiHelper"
    private const val REQUEST_CODE = 9999

    private fun getPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, SleepReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun register(context: Context) {
        val pendingIntent = getPendingIntent(context)
        val client = ActivityRecognition.getClient(context)
        client.requestSleepSegmentUpdates(
            pendingIntent,
            SleepSegmentRequest.getDefaultSleepSegmentRequest()
        ).addOnSuccessListener {
            Log.d(TAG, "Successfully subscribed to sleep data.")
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to subscribe to sleep data: $e")
        }
    }

    fun unregister(context: Context) {
        val pendingIntent = getPendingIntent(context)
        val client = ActivityRecognition.getClient(context)
        client.removeSleepSegmentUpdates(pendingIntent)
            .addOnSuccessListener {
                Log.d(TAG, "Successfully unsubscribed from sleep data.")
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to unsubscribe from sleep data: $e")
            }
    }
}
