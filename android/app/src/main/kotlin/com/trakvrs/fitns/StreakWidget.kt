package com.trakvrs.fitns

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/**
 * The workout card (named for the streak widget it grew from, so widgets
 * already on home screens carry on): today's training over contour lines,
 * this week's progress and the streak. Drawn by [FitnsWidget].
 */
class StreakWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        FitnsWidget.draw(context, manager, ids, FitnsWidget.Kind.WORKOUT)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        FitnsWidget.draw(context, manager, intArrayOf(id), FitnsWidget.Kind.WORKOUT)
}
