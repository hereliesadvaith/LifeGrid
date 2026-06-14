package com.example.lifegrid

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Frosted-glass home-screen clock widget.
 *
 * The time is shown by [android.widget.TextClock] views whose formats live in
 * the layout, so the system keeps them ticking with no app process running.
 * This provider fills in the greeting (the profile first name) and wires the
 * tap-to-open-app intent. The app calls [refresh] after the profile is edited.
 */
class ClockWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = buildViews(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    companion object {
        /** Re-renders every placed instance — call when the profile name changes. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ClockWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, buildViews(context))
        }

        private fun buildViews(context: Context): RemoteViews {
            return RemoteViews(context.packageName, R.layout.clock_widget).apply {
                setTextViewText(R.id.clock_name, firstName(context))
                setOnClickPendingIntent(R.id.clock_root, openAppPendingIntent(context))
            }
        }

        /** Reads the profile first name saved by Flutter's shared_preferences. */
        private fun firstName(context: Context): String {
            val name = context
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.profile_first", null)
                ?.trim()
                .orEmpty()
            return name.ifBlank { "there" }
        }

        private fun openAppPendingIntent(context: Context): PendingIntent {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ?: Intent()
            return PendingIntent.getActivity(
                context, 1, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
