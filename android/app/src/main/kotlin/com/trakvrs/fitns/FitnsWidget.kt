package com.trakvrs.fitns

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * FITNS's home-screen widgets: Today (this one), [StepsWidget],
 * [WaterWidget], [CaloriesWidget] and [StreakWidget].
 *
 * Dart works the numbers out (it owns the database) and hands them over
 * with [save] whenever they change. Between app opens they keep going by
 * themselves:
 *  * steps from the all-day step counter ([onStepReading]);
 *  * water from the widget's own + buttons (logged through [WaterBar], so
 *    FITNS books them next time it opens), shown at once;
 *  * a new day starts from zero at midnight instead of showing yesterday.
 */
class FitnsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, todayViews(context))
    }

    companion object {
        const val PREFS = "fitns_widget"

        /** What Dart says: see `HomeWidget.update` in home_widget.dart. */
        fun save(context: Context, data: Map<*, *>) {
            fun int(key: String) = (data[key] as? Number)?.toInt() ?: 0
            val stepBase = context.getSharedPreferences("fitns_step_filter", Context.MODE_PRIVATE)
                .getLong("reported", -1L)
            prefs(context).edit().apply {
                putString("day", data["day"] as? String)
                putInt("steps", int("steps"))
                putInt("stepGoal", int("stepGoal"))
                // The step counter's total as of these steps: the service
                // adds whatever it counts after this.
                putLong("stepBase", stepBase)
                remove("liveDay")
                putInt("kcalEaten", int("kcalEaten"))
                putInt("kcalGoal", int("kcalGoal"))
                for (m in MACROS) {
                    putInt("${m}G", int("${m}G"))
                    putInt("${m}GoalG", int("${m}GoalG"))
                }
                putString("next", data["next"] as? String)
                putInt("streakWeeks", int("streakWeeks"))
                apply()
            }
            refreshAll(context)
        }

        /**
         * The step service read [counter] (its filtered total) at [atMs]:
         * moves the widgets' step count on without FITNS open.
         */
        fun onStepReading(context: Context, counter: Long, atMs: Long) {
            val p = prefs(context)
            val savedDay = p.getString("day", null) ?: return
            val day = dayKey(atMs)
            if (day < savedDay) return
            var base = p.getLong("stepBase", -1L)
            var steps = p.getInt("steps", 0)
            val e = p.edit()
            if (day != savedDay) {
                // A new day: from zero, counting from the last reading of
                // the old one.
                steps = 0
                base = p.getLong("lastCounter", counter)
                e.putString("day", day).putInt("steps", 0).putLong("stepBase", base)
                    .putInt("kcalEaten", 0)
                for (m in MACROS) e.putInt("${m}G", 0)
            }
            // Unknown, or the counter restarted (a reboot).
            if (base < 0 || counter < base) {
                base = counter
                e.putLong("stepBase", base)
            }
            val live = steps + (counter - base).toInt()
            e.putString("liveDay", day).putInt("liveSteps", live).putLong("lastCounter", counter)
            e.apply()
            refreshAll(context)
        }

        /** Redraws every FITNS widget on the home screen. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            fun redraw(cls: Class<*>, views: () -> RemoteViews) {
                val ids = manager.getAppWidgetIds(ComponentName(context, cls))
                if (ids.isEmpty()) return
                val v = views()
                for (id in ids) manager.updateAppWidget(id, v)
            }
            redraw(FitnsWidget::class.java) { todayViews(context) }
            redraw(StepsWidget::class.java) { stepsViews(context) }
            redraw(WaterWidget::class.java) { waterViews(context) }
            redraw(CaloriesWidget::class.java) { caloriesViews(context) }
            redraw(StreakWidget::class.java) { streakViews(context) }
        }

        // ── The numbers, as of now ──────────────────────────────────────────

        private val MACROS = listOf("protein", "carbs", "fat")

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun today() = dayKey(System.currentTimeMillis())

        fun dayKey(millis: Long): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))

        /** Dart has said something at least once. */
        private fun known(context: Context) = prefs(context).getString("day", null) != null

        /** Today's numbers belong to today (else a new day: zeros). */
        private fun current(context: Context) = prefs(context).getString("day", null) == today()

        fun steps(context: Context): Int {
            val p = prefs(context)
            if (p.getString("liveDay", null) == today()) return p.getInt("liveSteps", 0)
            return if (current(context)) p.getInt("steps", 0) else 0
        }

        private fun kcalEaten(context: Context) =
            if (current(context)) prefs(context).getInt("kcalEaten", 0) else 0

        private fun macro(context: Context, m: String) =
            if (current(context)) prefs(context).getInt("${m}G", 0) else 0

        private fun n(value: Int): String = NumberFormat.getIntegerInstance().format(value)

        private fun percent(value: Int, goal: Int) =
            if (goal <= 0) 0 else (value * 100 / goal).coerceIn(0, 100)

        // ── Taps ─────────────────────────────────────────────────────────────

        /** Opens FITNS on [page] (see `_openPage` in app.dart). */
        fun open(context: Context, page: String, code: Int): PendingIntent =
            PendingIntent.getActivity(
                context,
                code,
                Intent(context, MainActivity::class.java)
                    .putExtra(WaterBar.EXTRA_OPEN, page)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        /** Logs [ml] of water straight from the widget. */
        private fun addWater(context: Context, ml: Int, code: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                code,
                Intent(context, WaterReceiver::class.java)
                    .setAction(WaterBar.ACTION_ADD)
                    .putExtra(WaterBar.EXTRA_ML, ml),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        // ── Drawing ──────────────────────────────────────────────────────────

        fun todayViews(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.fitns_widget)
            val p = prefs(context)
            if (known(context)) {
                val steps = steps(context)
                val stepGoal = p.getInt("stepGoal", 0)
                v.setTextViewText(R.id.t_steps_value, n(steps))
                v.setTextViewText(R.id.t_steps_sub, if (stepGoal > 0) "of ${n(stepGoal)}" else "steps")
                v.setProgressBar(R.id.t_steps_bar, 100, percent(steps, stepGoal), false)

                val eaten = kcalEaten(context)
                val goal = p.getInt("kcalGoal", 0)
                if (goal > 0) {
                    val left = goal - eaten
                    v.setTextViewText(R.id.t_kcal_value, n(kotlin.math.abs(left)))
                    v.setTextViewText(R.id.t_kcal_sub, if (left >= 0) "kcal left" else "kcal over")
                    v.setProgressBar(R.id.t_kcal_bar, 100, percent(eaten, goal), false)
                } else {
                    v.setTextViewText(R.id.t_kcal_value, n(eaten))
                    v.setTextViewText(R.id.t_kcal_sub, "kcal eaten")
                    v.setProgressBar(R.id.t_kcal_bar, 100, 0, false)
                }

                val weeks = p.getInt("streakWeeks", 0)
                v.setTextViewText(R.id.widget_streak, if (weeks > 0) "🔥 $weeks" else "")
                val next = p.getString("next", null)
                v.setTextViewText(
                    R.id.widget_workout,
                    if (next.isNullOrBlank()) "▶ Workout" else "▶ ${next.removePrefix("Next: ")}",
                )
            }
            val (drunk, waterGoal) = WaterBar.today(context)
            v.setTextViewText(R.id.t_water_value, WaterBar.volume(context, drunk))
            v.setTextViewText(
                R.id.t_water_sub,
                if (waterGoal > 0) "of ${WaterBar.volume(context, waterGoal)}" else "today",
            )
            v.setProgressBar(R.id.t_water_bar, 100, percent(drunk, waterGoal), false)
            val glass = WaterBar.firstPreset(context) ?: 250
            v.setTextViewText(R.id.widget_water_add, "+${WaterBar.volume(context, glass)}")

            v.setOnClickPendingIntent(R.id.widget_root, open(context, "today", 300))
            v.setOnClickPendingIntent(R.id.t_steps_tile, open(context, "steps", 301))
            v.setOnClickPendingIntent(R.id.t_kcal_tile, open(context, "food", 302))
            v.setOnClickPendingIntent(R.id.t_water_tile, open(context, "water", 303))
            v.setOnClickPendingIntent(R.id.widget_workout, open(context, "workout", 304))
            v.setOnClickPendingIntent(R.id.widget_food, open(context, "logFood", 305))
            v.setOnClickPendingIntent(R.id.widget_water_add, addWater(context, glass, 306))
            return v
        }

        fun stepsViews(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_steps)
            if (known(context)) {
                val steps = steps(context)
                val goal = prefs(context).getInt("stepGoal", 0)
                v.setTextViewText(R.id.steps_count, n(steps))
                v.setTextViewText(R.id.steps_goal, if (goal > 0) "of ${n(goal)} steps" else "steps")
                v.setProgressBar(R.id.steps_ring, 100, percent(steps, goal), false)
            }
            v.setOnClickPendingIntent(R.id.steps_root, open(context, "steps", 310))
            return v
        }

        fun waterViews(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_water)
            val (drunk, goal) = WaterBar.today(context)
            v.setTextViewText(R.id.water_amount, WaterBar.volume(context, drunk))
            if (goal > 0) {
                v.setTextViewText(R.id.water_goal, "/ ${WaterBar.volume(context, goal)}")
                v.setViewVisibility(R.id.water_goal, View.VISIBLE)
            } else {
                v.setViewVisibility(R.id.water_goal, View.GONE)
            }
            v.setProgressBar(R.id.water_bar, 100, percent(drunk, goal), false)
            val sizes = WaterBar.presetSizes(context).ifEmpty { listOf(250, 500) }
            val first = sizes[0]
            val second = sizes.getOrElse(1) { first * 2 }
            v.setTextViewText(R.id.water_add_1, "+${WaterBar.volume(context, first)}")
            v.setTextViewText(R.id.water_add_2, "+${WaterBar.volume(context, second)}")
            v.setOnClickPendingIntent(R.id.water_add_1, addWater(context, first, 320))
            v.setOnClickPendingIntent(R.id.water_add_2, addWater(context, second, 321))
            v.setOnClickPendingIntent(R.id.water_root, open(context, "water", 322))
            return v
        }

        fun caloriesViews(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_calories)
            val p = prefs(context)
            if (known(context)) {
                val eaten = kcalEaten(context)
                val goal = p.getInt("kcalGoal", 0)
                if (goal > 0) {
                    val left = goal - eaten
                    v.setTextViewText(R.id.kcal_number, n(kotlin.math.abs(left)))
                    v.setTextViewText(R.id.kcal_caption, if (left >= 0) "kcal left" else "kcal over")
                    v.setTextViewText(R.id.kcal_eaten, "🍽 ${n(eaten)} of ${n(goal)} kcal")
                    v.setProgressBar(R.id.kcal_ring, 100, percent(eaten, goal), false)
                } else {
                    v.setTextViewText(R.id.kcal_number, n(eaten))
                    v.setTextViewText(R.id.kcal_caption, "kcal eaten")
                    v.setTextViewText(R.id.kcal_eaten, "Set a calorie goal in FITNS")
                    v.setProgressBar(R.id.kcal_ring, 100, 0, false)
                }
                val rows = listOf(
                    Triple("protein", R.id.protein_text, R.id.protein_bar),
                    Triple("carbs", R.id.carbs_text, R.id.carbs_bar),
                    Triple("fat", R.id.fat_text, R.id.fat_bar),
                )
                for ((m, text, bar) in rows) {
                    val g = macro(context, m)
                    val target = p.getInt("${m}GoalG", 0)
                    val name = m.replaceFirstChar { it.uppercase() }
                    v.setTextViewText(
                        text,
                        if (target > 0) "$name · $g / $target g" else "$name · $g g",
                    )
                    v.setProgressBar(bar, 100, percent(g, target), false)
                }
            }
            v.setOnClickPendingIntent(R.id.kcal_root, open(context, "logFood", 330))
            return v
        }

        fun streakViews(context: Context): RemoteViews {
            val weeks = prefs(context).getInt("streakWeeks", 0)
            val v = RemoteViews(context.packageName, R.layout.streak_widget)
            v.setTextViewText(R.id.streak_number, "$weeks")
            v.setTextViewText(
                R.id.streak_caption,
                context.getString(
                    if (weeks > 0) R.string.streak_widget_weeks else R.string.streak_widget_none,
                ),
            )
            v.setOnClickPendingIntent(R.id.streak_root, open(context, "workout", 340))
            return v
        }
    }
}

/** Steps today, as a ring: [FitnsWidget.stepsViews]. */
class StepsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = FitnsWidget.stepsViews(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }
}

/** Water today, with add buttons: [FitnsWidget.waterViews]. */
class WaterWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = FitnsWidget.waterViews(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }
}

/** Calories left and macros: [FitnsWidget.caloriesViews]. */
class CaloriesWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = FitnsWidget.caloriesViews(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }
}
