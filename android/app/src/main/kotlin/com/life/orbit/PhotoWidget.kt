package com.life.orbit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import android.widget.RemoteViews
import androidx.exifinterface.media.ExifInterface

class PhotoWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        // Ensure alarm is scheduled for rotation.
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val intervalMinutes = try {
            prefs.getLong("flutter.widget_featured_photo_interval", 1440).toInt()
        } catch (e: ClassCastException) {
            try { prefs.getInt("flutter.widget_featured_photo_interval", 1440) }
            catch (_: Exception) { 1440 }
        }
        PhotoWidgetAlarm.schedule(context, intervalMinutes)
    }

    companion object {
        private const val CORNER_RADIUS = 48f // px, roughly 16dp at ~3x density

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val pathsRaw = prefs.getString("flutter.widget_featured_photos", "") ?: ""
            val cropsRaw = prefs.getString("flutter.widget_featured_photo_crops", "") ?: ""
            val count = try {
                prefs.getLong("flutter.widget_featured_photo_count", 0).toInt()
            } catch (e: ClassCastException) {
                try { prefs.getInt("flutter.widget_featured_photo_count", 0) }
                catch (_: Exception) { 0 }
            }

            val views = RemoteViews(context.packageName, R.layout.widget_photo)

            if (pathsRaw.isEmpty() || count == 0) {
                // No photos — show placeholder.
                views.setViewVisibility(R.id.widget_photo, View.GONE)
                views.setViewVisibility(R.id.widget_photo_placeholder, View.VISIBLE)
            } else {
                val paths = pathsRaw.split("|").filter { it.isNotEmpty() }
                if (paths.isEmpty()) {
                    views.setViewVisibility(R.id.widget_photo, View.GONE)
                    views.setViewVisibility(R.id.widget_photo_placeholder, View.VISIBLE)
                } else {
                    // Check for a forced photo override.
                    val forcedPath = prefs.getString("flutter.featured_photo_forced", "") ?: ""
                    val forcedAt = try {
                        prefs.getLong("flutter.featured_photo_forced_at", 0)
                    } catch (_: Exception) { 0L }
                    val photoPath: String

                    // Use forced photo only if it was set within the current interval.
                    val intervalMinutes = try {
                        prefs.getLong("flutter.widget_featured_photo_interval", 1440).toInt()
                    } catch (e: ClassCastException) {
                        try { prefs.getInt("flutter.widget_featured_photo_interval", 1440) }
                        catch (_: Exception) { 1440 }
                    }
                    val intervalMillis = intervalMinutes.toLong() * 60_000L
                    val elapsed = System.currentTimeMillis() - forcedAt

                    if (forcedPath.isNotEmpty() && paths.contains(forcedPath) && elapsed < intervalMillis) {
                        photoPath = forcedPath
                    } else {
                        // Clear stale forced override.
                        if (forcedPath.isNotEmpty()) {
                            prefs.edit().putString("flutter.featured_photo_forced", "").apply()
                        }
                        // Normal rotation: seeded random shuffle.
                        val offset = try {
                            prefs.getLong("flutter.featured_photo_offset", 0).toInt()
                        } catch (e: ClassCastException) {
                            try { prefs.getInt("flutter.featured_photo_offset", 0) }
                            catch (_: Exception) { 0 }
                        }
                        val slot = ((System.currentTimeMillis() / intervalMillis) + offset).toInt()
                        val indices = (0 until paths.size).toMutableList()
                        val rng = java.util.Random(slot.toLong())
                        indices.shuffle(rng)
                        val index = indices[0]
                        photoPath = paths[index]
                    }

                    val bitmap = BitmapFactory.decodeFile(photoPath)
                    if (bitmap != null) {
                        // Fix EXIF rotation, then scale down for widget.
                        val oriented = correctOrientation(bitmap, photoPath)
                        val maxSize = 512
                        val scaled = scaleBitmap(oriented, maxSize)
                        val rounded = roundCorners(scaled, CORNER_RADIUS, "center")
                        views.setImageViewBitmap(R.id.widget_photo, rounded)
                        views.setViewVisibility(R.id.widget_photo, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_photo_placeholder, View.GONE)
                        if (scaled !== oriented) oriented.recycle()
                        if (oriented !== bitmap) bitmap.recycle()
                    } else {
                        views.setViewVisibility(R.id.widget_photo, View.GONE)
                        views.setViewVisibility(R.id.widget_photo_placeholder, View.VISIBLE)
                    }
                }
            }

            // Tap to open Featured Photos page.
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "featured_photos")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 8, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_photo, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_photo_placeholder, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun roundCorners(source: Bitmap, radius: Float, cropAlign: String): Bitmap {
            val size = minOf(source.width, source.height)
            val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
            val path = Path().apply { addRoundRect(rect, radius, radius, Path.Direction.CW) }
            canvas.clipPath(path)

            // Crop based on alignment.
            val left = (source.width - size) / 2f
            val top = when (cropAlign) {
                "top" -> 0f
                "bottom" -> (source.height - size).toFloat()
                else -> (source.height - size) / 2f // center
            }
            canvas.drawBitmap(source, -left, -top, paint)
            return output
        }

        private fun scaleBitmap(source: Bitmap, maxSize: Int): Bitmap {
            val width = source.width
            val height = source.height
            if (width <= maxSize && height <= maxSize) return source
            val scale = maxSize.toFloat() / maxOf(width, height)
            val newWidth = (width * scale).toInt()
            val newHeight = (height * scale).toInt()
            return Bitmap.createScaledBitmap(source, newWidth, newHeight, true)
        }

        private fun correctOrientation(bitmap: Bitmap, path: String): Bitmap {
            return try {
                val exif = ExifInterface(path)
                val orientation = exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL
                )
                val matrix = Matrix()
                when (orientation) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                    ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                    ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                    ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
                    ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
                    else -> return bitmap
                }
                Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            } catch (_: Exception) {
                bitmap
            }
        }
    }
}
