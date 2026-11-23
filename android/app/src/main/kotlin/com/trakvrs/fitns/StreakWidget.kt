package com.trakvrs.fitns

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/**
 * The small streak widget: weeks in a row with a workout. Drawn by
 * [FitnsWidget.streakViews] from what [FitnsWidget.save] last stored.
 */
class StreakWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = FitnsWidget.streakViews(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }
}
