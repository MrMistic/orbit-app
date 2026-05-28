package com.life.orbit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class BankrollWidget : AppWidgetProvider() {
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
            val profit = prefs.getString("flutter.widget_bankroll_profit", "") ?: ""
            val roi = prefs.getString("flutter.widget_bankroll_roi", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_bankroll)
            if (profit.isEmpty()) {
                views.setTextViewText(R.id.widget_value, "—")
                views.setTextViewText(R.id.widget_subtitle, "No bets logged")
            } else {
                views.setTextViewText(R.id.widget_value, profit)
                views.setTextViewText(R.id.widget_subtitle, roi)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "bankroll")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 4, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_value, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_subtitle, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
