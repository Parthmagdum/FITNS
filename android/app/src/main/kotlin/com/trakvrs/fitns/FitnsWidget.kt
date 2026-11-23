package com.trakvrs.fitns

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * FITNS's home-screen widgets — Activity (this one), [StepsWidget],
 * [WaterWidget], [CaloriesWidget] and Workout ([StreakWidget]) — all drawn
 * here, their pictures by [WidgetArt].
 *
 * Each comes in sizes (a 2×1 pill, 2×2, 4×2) and the launcher picks the one
 * that fits as the widget is resized.
 *
 * Dart works the numbers out (it owns the database) and hands them over
 * with [save] whenever they change. Between app opens they keep going by
 * themselves: steps from the all-day step counter ([onStepReading]), water
 * from the widgets' own + buttons (logged through [WaterBar]), and a new
 * day starts from zero at midnight.
 */
class FitnsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        draw(context, manager, ids, Kind.ACTIVITY)

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) = draw(context, manager, intArrayOf(id), Kind.ACTIVITY)

    enum class Kind { ACTIVITY, STEPS, WATER, CALORIES, WORKOUT }

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
                putString("week", data["week"] as? String ?: "")
                putString("trained", data["trained"] as? String ?: "")
                putInt("weekTarget", int("weekTarget"))
                putInt("nextExercises", int("nextExercises"))
                putInt("nextMinutes", int("nextMinutes"))
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
            val steps = if (day != savedDay) 0 else p.getInt("steps", 0)
            val e = p.edit()
            if (day != savedDay) {
                // A new day: from zero, counting from the last reading of
                // the old one.
                base = p.getLong("lastCounter", counter)
                e.putString("day", day).putInt("steps", 0).putLong("stepBase", base)
                    .putInt("kcalEaten", 0)
                    .putString("week", shiftWeek(p.getString("week", "") ?: "", daysBetween(savedDay, day)))
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
            for ((cls, kind) in listOf(
                FitnsWidget::class.java to Kind.ACTIVITY,
                StepsWidget::class.java to Kind.STEPS,
                WaterWidget::class.java to Kind.WATER,
                CaloriesWidget::class.java to Kind.CALORIES,
                StreakWidget::class.java to Kind.WORKOUT,
            )) {
                val ids = manager.getAppWidgetIds(ComponentName(context, cls))
                if (ids.isNotEmpty()) draw(context, manager, ids, kind)
            }
        }

        /** Draws [ids] of one [kind], in each size it comes in. */
        fun draw(context: Context, manager: AppWidgetManager, ids: IntArray, kind: Kind) {
            val variants = when (kind) {
                Kind.ACTIVITY -> activity(context)
                Kind.STEPS -> steps(context)
                Kind.WATER -> water(context)
                Kind.CALORIES -> calories(context)
                Kind.WORKOUT -> workout(context)
            }
            for (id in ids) {
                val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    RemoteViews(variants.toMap())
                } else {
                    pick(manager.getAppWidgetOptions(id), variants)
                }
                manager.updateAppWidget(id, views)
            }
        }

        /** Before Android 12: the biggest size that fits the widget now. */
        private fun pick(options: Bundle, variants: List<Pair<SizeF, RemoteViews>>): RemoteViews {
            val w = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val h = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            if (w == 0 || h == 0) return variants.last().second
            return variants
                .filter { it.first.width <= w && it.first.height <= h }
                .maxByOrNull { it.first.width * it.first.height }
                ?.second
                ?: variants.minBy { it.first.width * it.first.height }.second
        }

        // ── The numbers, as of now ──────────────────────────────────────────

        private val MACROS = listOf("protein", "carbs", "fat")

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun today() = dayKey(System.currentTimeMillis())

        fun dayKey(millis: Long): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))

        private fun daysBetween(from: String, to: String): Int {
            val f = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val a = f.parse(from)?.time ?: return 0
            val b = f.parse(to)?.time ?: return 0
            return ((b - a) / 86_400_000L).toInt()
        }

        /** Moves the week's rings on by [days], the new days empty. */
        private fun shiftWeek(week: String, days: Int): String {
            if (days <= 0 || week.isEmpty()) return week
            val parts = week.split(';').toMutableList()
            repeat(minOf(days, 7)) {
                if (parts.isNotEmpty()) parts.removeAt(0)
                parts.add("0,0,0")
            }
            return parts.joinToString(";")
        }

        private fun known(context: Context) = prefs(context).getString("day", null) != null

        /** Today's numbers belong to today (else a new day: zeros). */
        private fun current(context: Context) = prefs(context).getString("day", null) == today()

        private fun stepsNow(context: Context): Int {
            val p = prefs(context)
            if (p.getString("liveDay", null) == today()) return p.getInt("liveSteps", 0)
            return if (current(context)) p.getInt("steps", 0) else 0
        }

        private fun kcalEaten(context: Context) =
            if (current(context)) prefs(context).getInt("kcalEaten", 0) else 0

        private fun macro(context: Context, m: String) =
            if (current(context)) prefs(context).getInt("${m}G", 0) else 0

        private fun n(value: Int): String = NumberFormat.getIntegerInstance().format(value)

        private fun fraction(value: Int, goal: Int) =
            if (goal <= 0) 0f else (value.toFloat() / goal).coerceIn(0f, 1f)

        private fun percent(value: Int, goal: Int) =
            if (goal <= 0) 0 else (value * 100 / goal).coerceIn(0, 100)

        /** "5,240 /8,000 steps": the number bold, the rest smaller and muted. */
        private fun withGoal(context: Context, value: String, rest: String): CharSequence {
            val s = SpannableStringBuilder(value)
            if (rest.isEmpty()) return s
            val start = s.length
            s.append(" ").append(rest)
            s.setSpan(RelativeSizeSpan(0.72f), start, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            s.setSpan(
                ForegroundColorSpan(context.getColor(R.color.widget_muted)),
                start,
                s.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
            return s
        }

        // ── Taps ─────────────────────────────────────────────────────────────

        /** Opens FITNS on [page] (see `widgetPageRoute` in home_widget.dart). */
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

        private fun views(context: Context, layout: Int) = RemoteViews(context.packageName, layout)

        // ── Activity: three rings ────────────────────────────────────────────

        private fun activity(context: Context): List<Pair<SizeF, RemoteViews>> {
            val p = prefs(context)
            val steps = stepsNow(context)
            val stepGoal = p.getInt("stepGoal", 0)
            val (drunk, waterGoal) = WaterBar.today(context)
            val eaten = kcalEaten(context)
            val kcalGoal = p.getInt("kcalGoal", 0)
            // One bitmap for every size: the launcher scales it.
            val rings = WidgetArt.rings(
                context,
                92f,
                listOf(fraction(steps, stepGoal), fraction(drunk, waterGoal), fraction(eaten, kcalGoal)),
                listOf(WidgetArt.STEPS, WidgetArt.WATER, WidgetArt.KCAL),
            )
            fun fill(v: RemoteViews, goals: Boolean): RemoteViews {
                v.setImageViewBitmap(R.id.act_rings, rings)
                val known = known(context)
                v.setTextViewText(
                    R.id.act_val1,
                    if (!known) "—" else if (goals && stepGoal > 0) withGoal(context, n(steps), "/${n(stepGoal)}") else n(steps),
                )
                v.setTextViewText(
                    R.id.act_val2,
                    if (goals && waterGoal > 0) {
                        withGoal(context, WaterBar.volume(context, drunk), "/${WaterBar.volume(context, waterGoal)}")
                    } else {
                        WaterBar.volume(context, drunk)
                    },
                )
                v.setTextViewText(
                    R.id.act_val3,
                    if (!known) "—" else if (goals && kcalGoal > 0) withGoal(context, n(eaten), "/${n(kcalGoal)} kcal") else n(eaten),
                )
                v.setOnClickPendingIntent(R.id.act_root, open(context, "today", 300))
                return v
            }
            val large = fill(views(context, R.layout.widget_activity_l), true)
            large.setImageViewBitmap(R.id.act_week, weekStrip(context))
            return listOf(
                SizeF(110f, 40f) to fill(views(context, R.layout.widget_activity_s), false),
                SizeF(110f, 110f) to fill(views(context, R.layout.widget_activity_m), false),
                SizeF(250f, 110f) to large,
            )
        }

        private fun weekStrip(context: Context): Bitmap {
            val week = (prefs(context).getString("week", "") ?: "")
                .split(';')
                .filter { it.isNotBlank() }
                .map { d ->
                    val v = d.split(',').map { (it.trim().toIntOrNull() ?: 0) / 100f }
                    Triple(v.getOrElse(0) { 0f }, v.getOrElse(1) { 0f }, v.getOrElse(2) { 0f })
                }
                .takeLast(7)
                .let { List(7 - it.size) { Triple(0f, 0f, 0f) } + it }
            val letters = mutableListOf<String>()
            val weekend = mutableListOf<Boolean>()
            val cal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -6) }
            val fmt = SimpleDateFormat("EEEEE", Locale.getDefault())
            repeat(7) {
                letters += fmt.format(cal.time)
                val dow = cal.get(Calendar.DAY_OF_WEEK)
                weekend += dow == Calendar.SATURDAY || dow == Calendar.SUNDAY
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            return WidgetArt.week(context, 300f, 46f, week, letters, weekend)
        }

        // ── Steps ───────────────────────────────────────────────────────────

        private fun steps(context: Context): List<Pair<SizeF, RemoteViews>> {
            val steps = stepsNow(context)
            val goal = prefs(context).getInt("stepGoal", 0)
            val ring = WidgetArt.rings(context, 124f, listOf(fraction(steps, goal)), listOf(WidgetArt.STEPS))
            fun fill(v: RemoteViews, small: Boolean): RemoteViews {
                v.setImageViewBitmap(R.id.st_ring, ring)
                if (known(context)) {
                    v.setTextViewText(R.id.st_count, n(steps))
                    v.setTextViewText(
                        R.id.st_goal,
                        when {
                            goal <= 0 -> "steps"
                            small -> "/${n(goal)} steps"
                            else -> "/${n(goal)}"
                        },
                    )
                }
                v.setOnClickPendingIntent(R.id.st_root, open(context, "steps", 310))
                return v
            }
            return listOf(
                SizeF(110f, 40f) to fill(views(context, R.layout.widget_steps_s), true),
                SizeF(110f, 110f) to fill(views(context, R.layout.widget_steps_m), false),
            )
        }

        // ── Water ───────────────────────────────────────────────────────────

        private fun water(context: Context): List<Pair<SizeF, RemoteViews>> {
            val (drunk, goal) = WaterBar.today(context)
            val glass = WidgetArt.glass(context, 46f, 70f, fraction(drunk, goal))
            val sizes = WaterBar.presetSizes(context).ifEmpty { listOf(250, 500) }
            val first = sizes[0]
            val second = sizes.getOrElse(1) { first * 2 }
            fun fill(v: RemoteViews): RemoteViews {
                v.setImageViewBitmap(R.id.wa_glass, glass)
                v.setTextViewText(R.id.wa_amount, WaterBar.volume(context, drunk))
                if (goal > 0) {
                    v.setTextViewText(R.id.wa_goal, "of ${WaterBar.volume(context, goal)} · ${percent(drunk, goal)}%")
                    v.setViewVisibility(R.id.wa_goal, View.VISIBLE)
                } else {
                    v.setViewVisibility(R.id.wa_goal, View.GONE)
                }
                v.setOnClickPendingIntent(R.id.wa_add1, addWater(context, first, 320))
                v.setOnClickPendingIntent(R.id.wa_root, open(context, "water", 322))
                return v
            }
            val medium = fill(views(context, R.layout.widget_water_m))
            medium.setTextViewText(R.id.wa_add1, "+${WaterBar.volume(context, first)}")
            medium.setTextViewText(R.id.wa_add2, "+${WaterBar.volume(context, second)}")
            medium.setOnClickPendingIntent(R.id.wa_add2, addWater(context, second, 321))
            return listOf(
                SizeF(110f, 40f) to fill(views(context, R.layout.widget_water_s)),
                SizeF(110f, 110f) to medium,
            )
        }

        // ── Calories ────────────────────────────────────────────────────────

        private fun calories(context: Context): List<Pair<SizeF, RemoteViews>> {
            val p = prefs(context)
            val eaten = kcalEaten(context)
            val goal = p.getInt("kcalGoal", 0)
            val ring = WidgetArt.rings(context, 108f, listOf(fraction(eaten, goal)), listOf(WidgetArt.KCAL))
            val grams = MACROS.associateWith { macro(context, it) }
            fun fill(v: RemoteViews): RemoteViews {
                v.setImageViewBitmap(R.id.kc_ring, ring)
                if (known(context)) {
                    if (goal > 0) {
                        val left = goal - eaten
                        v.setTextViewText(R.id.kc_number, n(kotlin.math.abs(left)))
                        v.setTextViewText(R.id.kc_caption, if (left >= 0) "kcal left" else "kcal over")
                    } else {
                        v.setTextViewText(R.id.kc_number, n(eaten))
                        v.setTextViewText(R.id.kc_caption, "kcal eaten")
                    }
                }
                // The Food tab: today's meals, where logging starts from.
                v.setOnClickPendingIntent(R.id.kc_root, open(context, "food", 330))
                return v
            }
            val medium = fill(views(context, R.layout.widget_calories_m))
            medium.setTextViewText(
                R.id.kc_line,
                "P ${grams["protein"]} · C ${grams["carbs"]} · F ${grams["fat"]} g",
            )
            val large = fill(views(context, R.layout.widget_calories_l))
            large.setTextViewText(
                R.id.kc_line,
                if (goal > 0) "${n(eaten)} of ${n(goal)} kcal eaten" else "Set a calorie goal in FITNS",
            )
            for ((m, text, bar) in listOf(
                Triple("protein", R.id.kc_p_text, R.id.kc_p_bar),
                Triple("carbs", R.id.kc_c_text, R.id.kc_c_bar),
                Triple("fat", R.id.kc_f_text, R.id.kc_f_bar),
            )) {
                val g = grams[m] ?: 0
                val target = p.getInt("${m}GoalG", 0)
                val name = m.replaceFirstChar { it.uppercase() }
                large.setTextViewText(
                    text,
                    withGoal(context, name, if (target > 0) "$g / $target g" else "$g g"),
                )
                large.setProgressBar(bar, 100, percent(g, target), false)
            }
            return listOf(
                SizeF(110f, 110f) to medium,
                SizeF(220f, 110f) to large,
            )
        }

        // ── Workout: today's training card ──────────────────────────────────

        private fun workout(context: Context): List<Pair<SizeF, RemoteViews>> {
            val p = prefs(context)
            val bg = WidgetArt.contours(context, 360f, 180f, 28f)
            // Monday to Sunday; a new week starts empty.
            var trained = (p.getString("trained", "") ?: "").padEnd(7, '0').map { it == '1' }
            val savedWeek = p.getString("day", null)?.let { weekOf(it) }
            if (savedWeek != null && savedWeek != weekOf(today())) trained = List(7) { false }
            val accent = context.getColor(R.color.widget_accent)
            val dashes = WidgetArt.dashes(context, 150f, trained, accent)
            val todayIndex = (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) + 5) % 7
            val done = trained.count { it }
            val target = p.getInt("weekTarget", 3).coerceAtLeast(1)
            val weeks = p.getInt("streakWeeks", 0)
            val next = p.getString("next", null)?.removePrefix("Next: ")?.takeIf { it.isNotBlank() }
            val exercises = p.getInt("nextExercises", 0)
            val minutes = p.getInt("nextMinutes", 0)
            val trainedToday = trained.getOrElse(todayIndex) { false }
            fun fill(v: RemoteViews): RemoteViews {
                v.setImageViewBitmap(R.id.wo_bg, bg)
                v.setImageViewBitmap(R.id.wo_dashes, dashes)
                v.setTextViewText(
                    R.id.wo_week,
                    "$done/$target this week" + if (weeks > 0) "  ·  🔥 $weeks" else "",
                )
                when {
                    trainedToday -> {
                        v.setTextViewText(R.id.wo_kind, "Done today ✓")
                        v.setTextViewText(R.id.wo_name, next?.let { "Next: $it" } ?: "Nice work")
                        v.setTextViewText(R.id.wo_detail, "Rest up — see you next session")
                    }
                    next != null -> {
                        v.setTextViewText(R.id.wo_kind, "Training day")
                        v.setTextViewText(R.id.wo_name, next)
                        v.setTextViewText(
                            R.id.wo_detail,
                            if (exercises > 0) "$exercises exercises · ~$minutes min" else "Your program's next day",
                        )
                    }
                    else -> {
                        v.setTextViewText(R.id.wo_kind, if (done >= target) "Goal reached" else "Training day")
                        v.setTextViewText(R.id.wo_name, "Pick a workout")
                        v.setTextViewText(R.id.wo_detail, "A routine, or one ready-made")
                    }
                }
                v.setOnClickPendingIntent(R.id.wo_root, open(context, "workout", 340))
                return v
            }
            val large = fill(views(context, R.layout.widget_workout_l))
            large.setOnClickPendingIntent(R.id.wo_start, open(context, "workout", 341))
            return listOf(
                SizeF(110f, 110f) to fill(views(context, R.layout.widget_workout_m)),
                SizeF(220f, 110f) to large,
            )
        }

        /** The Monday of [day]'s week, as a key. */
        private fun weekOf(day: String): String {
            val f = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val date = f.parse(day) ?: return day
            val c = Calendar.getInstance().apply {
                time = date
                firstDayOfWeek = Calendar.MONDAY
                set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
            }
            return f.format(c.time)
        }
    }
}

/** Steps today, as a ring. */
class StepsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        FitnsWidget.draw(context, manager, ids, FitnsWidget.Kind.STEPS)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        FitnsWidget.draw(context, manager, intArrayOf(id), FitnsWidget.Kind.STEPS)
}

/** Water today: a filling glass, with add buttons. */
class WaterWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        FitnsWidget.draw(context, manager, ids, FitnsWidget.Kind.WATER)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        FitnsWidget.draw(context, manager, intArrayOf(id), FitnsWidget.Kind.WATER)
}

/** Calories left, with protein, carbs and fat. */
class CaloriesWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        FitnsWidget.draw(context, manager, ids, FitnsWidget.Kind.CALORIES)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        FitnsWidget.draw(context, manager, intArrayOf(id), FitnsWidget.Kind.CALORIES)
}
