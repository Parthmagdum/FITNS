package com.trakvrs.fitns

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * The home-screen widget: today's steps against the goal, calories left and
 * the next workout. Dart works the numbers out (it owns the database) and
 * hands them over with [save] whenever they change; this only draws them.
 * A day the app hasn't been opened shows the last numbers it gave, marked
 * with their date, rather than pretending they're today's.
 */
class FitnsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, views(context))
    }

    companion object {
        private const val PREFS = "fitns_widget"

        fun save(context: Context, data: Map<*, *>) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                putString("day", data["day"] as? String)
                putInt("steps", (data["steps"] as? Number)?.toInt() ?: 0)
                putInt("stepGoal", (data["stepGoal"] as? Number)?.toInt() ?: 0)
                putString("food", data["food"] as? String)
                putString("next", data["next"] as? String)
                apply()
            }
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FitnsWidget::class.java))
            for (id in ids) manager.updateAppWidget(id, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.fitns_widget)
            val day = prefs.getString("day", null)
            if (day != null) {
                val steps = prefs.getInt("steps", 0)
                val goal = prefs.getInt("stepGoal", 0)
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
                    .format(java.util.Date())
                val stale = day != today
                views.setTextViewText(
                    R.id.widget_steps,
                    if (stale) "Open FITNS for today" else "%,d steps".format(steps),
                )
                views.setProgressBar(
                    R.id.widget_step_bar,
                    100,
                    if (stale || goal <= 0) 0 else minOf(100, steps * 100 / goal),
                    false,
                )
                views.setTextViewText(R.id.widget_food, if (stale) "" else prefs.getString("food", "") ?: "")
                views.setTextViewText(R.id.widget_next, prefs.getString("next", "") ?: "")
            }
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            return views
        }
    }
}
