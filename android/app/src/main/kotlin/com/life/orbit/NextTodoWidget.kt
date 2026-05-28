package com.life.orbit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class NextTodoWidget : AppWidgetProvider() {
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
            val title = prefs.getString("flutter.widget_next_todo_title", "") ?: ""
            val due = prefs.getString("flutter.widget_next_todo_due", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_next_todo)
            views.setTextViewText(
                R.id.widget_title,
                if (title.isEmpty()) "All done!" else title
            )
            views.setTextViewText(
                R.id.widget_subtitle,
                if (due.isEmpty()) "" else "Due ${due.substring(0, 10)}"
            )

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "todos")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_subtitle, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
