package com.life.orbit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class SubscriptionsWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val total = prefs.getString("flutter.widget_burn_total", "") ?: ""
            val count = prefs.getString("flutter.widget_burn_count", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_subscriptions)
            views.setTextViewText(
                R.id.widget_value,
                if (total.isEmpty()) "—" else total
            )
            views.setTextViewText(R.id.widget_subtitle, count)

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "bills_subs")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 5, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_subtitle, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_value, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
