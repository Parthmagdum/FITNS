package com.trakvrs.fitns

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * The small home-screen widget: weeks in a row with a workout. It shows
 * the streak [FitnsWidget.save] last stored, so Dart keeps both widgets up
 * to date with one call.
 */
class StreakWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, views(context))
    }

    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, StreakWidget::class.java))
            for (id in ids) manager.updateAppWidget(id, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(FitnsWidget.PREFS, Context.MODE_PRIVATE)
            val weeks = prefs.getInt("streakWeeks", 0)
            val views = RemoteViews(context.packageName, R.layout.streak_widget)
            views.setTextViewText(R.id.streak_number, "🔥 $weeks")
            views.setTextViewText(
                R.id.streak_caption,
                context.getString(
                    if (weeks > 0) R.string.streak_widget_weeks else R.string.streak_widget_none,
                ),
            )
            val open = PendingIntent.getActivity(
                context,
                1,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.streak_root, open)
            return views
        }
    }
}
