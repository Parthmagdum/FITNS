package com.trakvrs.fitns

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.io.File
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Water in the notification bar: an optional, silent tracker that shows
 * today's water and the next reminder, with buttons to log a drink and to
 * open the water settings. The water reminders use the same buttons.
 *
 * Dart owns the database, so a drink logged from a notification waits in a
 * small file (`ml,loggedAtMillis` per line) until Dart drains it. Dart
 * does that on every launch and resume, and straight away through
 * [onLogged] while FITNS is running. The tracker counts the waiting drinks
 * on top of the total Dart last gave it, so its number is right at once.
 *
 * Channel name `fitns/water` must match `lib/core/notifications/water_bar.dart`.
 */
object WaterBar {
    private const val PREFS = "fitns_water"
    private const val LOG = "water_log.csv"
    private const val CHANNEL = "water_tracker"

    const val NOTIFICATION_ID = 70_000
    const val ACTION_ADD = "com.trakvrs.fitns.WATER_ADD"
    const val ACTION_SNOOZE = "com.trakvrs.fitns.WATER_SNOOZE"
    const val ACTION_REFRESH = "com.trakvrs.fitns.WATER_REFRESH"
    const val EXTRA_ML = "ml"

    /** A notification to clear once its button was used (a reminder). */
    const val EXTRA_DISMISS = "dismiss"

    /** Set on the intent that opens FITNS: the page to show. */
    const val EXTRA_OPEN = "fitns_open"
    const val OPEN_WATER = "water"

    /** Request codes clear of the rest timer (41xx) and reminders (5xxxx, 6xxxx). */
    private const val CODE_OPEN = 70_100
    private const val CODE_ADD = 70_110
    private const val CODE_SNOOZE = 70_120
    private const val CODE_REFRESH = 70_130

    const val SNOOZE_MINUTES = 30

    /** Tells the running app a drink is waiting. Main thread; null when FITNS is closed. */
    @Volatile
    var onLogged: (() -> Unit)? = null

    /** What Dart last said: `on`, `day`, `drunkMl`, `goalMl`, `presetsMl`, `imperial`. */
    fun update(context: Context, data: Map<*, *>) {
        val presets = (data["presetsMl"] as? List<*>)
            ?.mapNotNull { (it as? Number)?.toInt() }
            ?.filter { it > 0 }
            ?: emptyList()
        prefs(context).edit().apply {
            putBoolean("on", data["on"] as? Boolean ?: false)
            putString("day", data["day"] as? String)
            putInt("drunkMl", (data["drunkMl"] as? Number)?.toInt() ?: 0)
            putInt("goalMl", (data["goalMl"] as? Number)?.toInt() ?: 0)
            putString("presetsMl", presets.joinToString(","))
            putBoolean("imperial", data["imperial"] as? Boolean ?: false)
            apply()
        }
        refresh(context)
    }

    /** Shows or redraws the tracker if it's on, removes it if not. */
    fun refresh(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!prefs(context).getBoolean("on", false)) {
            manager.cancel(NOTIFICATION_ID)
            alarms(context).cancel(refreshIntent(context))
            return
        }
        manager.notify(NOTIFICATION_ID, tracker(context))
        // At midnight the count starts again from zero.
        alarms(context).set(AlarmManager.RTC, nextMidnight(), refreshIntent(context))
    }

    /** Logs [ml] now: kept for Dart, and the tracker shows it at once. */
    fun add(context: Context, ml: Int) {
        if (ml <= 0) return
        synchronized(this) {
            File(context.filesDir, LOG).appendText("$ml,${System.currentTimeMillis()}\n")
        }
        refresh(context)
        onLogged?.invoke()
    }

    /** Every drink since the last drain as `[ml, loggedAtMillis]`, oldest first; empties the file. */
    fun drain(context: Context): List<List<Long>> = synchronized(this) {
        val file = File(context.filesDir, LOG)
        if (!file.exists()) return emptyList()
        val lines = file.readLines()
        file.delete()
        lines.mapNotNull { line ->
            val parts = line.split(',').mapNotNull { it.trim().toLongOrNull() }
            if (parts.size == 2) parts else null
        }
    }

    /** The first quick-add size, for the reminder's button. Null before Dart has said. */
    fun firstPreset(context: Context): Int? = presets(context).firstOrNull()

    /** "1.2 L of 2 L today", from what Dart said plus any drinks still waiting. */
    fun progressLine(context: Context): String? {
        val p = prefs(context)
        val goal = p.getInt("goalMl", 0)
        if (p.getString("day", null) == null) return null
        val drunk = drunkToday(context)
        return if (goal > 0) {
            "${volume(context, drunk)} of ${volume(context, goal)} today"
        } else {
            "${volume(context, drunk)} today"
        }
    }

    fun volume(context: Context, ml: Int): String {
        val symbols = DecimalFormatSymbols(Locale.getDefault())
        if (prefs(context).getBoolean("imperial", false)) {
            return "${DecimalFormat("0.#", symbols).format(ml / ML_PER_FL_OZ)} fl oz"
        }
        if (ml >= 1000) return "${DecimalFormat("0.##", symbols).format(ml / 1000.0)} L"
        return "$ml ml"
    }

    /** A button that logs [ml]; [dismiss] is a notification to clear afterwards. */
    fun addAction(context: Context, ml: Int, slot: Int, dismiss: Int? = null): Notification.Action {
        val intent = Intent(context, WaterReceiver::class.java)
            .setAction(ACTION_ADD)
            .putExtra(EXTRA_ML, ml)
        if (dismiss != null) intent.putExtra(EXTRA_DISMISS, dismiss)
        val pending = PendingIntent.getBroadcast(
            context,
            CODE_ADD + slot,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return action("+${volume(context, ml)}", pending)
    }

    fun snoozeAction(context: Context, dismiss: Int): Notification.Action {
        val pending = PendingIntent.getBroadcast(
            context,
            CODE_SNOOZE,
            Intent(context, WaterReceiver::class.java)
                .setAction(ACTION_SNOOZE)
                .putExtra(EXTRA_DISMISS, dismiss),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return action("Snooze $SNOOZE_MINUTES min", pending)
    }

    /** Opens FITNS on the water page, where reminders are edited. */
    fun openWater(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        CODE_OPEN,
        Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN, OPEN_WATER)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun tracker(context: Context): Notification {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Water tracker", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Today's water in the notification bar, with buttons to log a drink"
                    setShowBadge(false)
                },
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
        }
        val goal = prefs(context).getInt("goalMl", 0)
        val drunk = drunkToday(context)
        val next = Reminders.nextWaterReminder(context)
        val status = when {
            goal in 1..drunk -> "Goal reached. Nice work!"
            next != null -> "Next reminder at ${timeText(context, next)}"
            else -> "Reminders are off. Tap Edit to set them."
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_water)
            .setContentTitle("Water · ${progressLine(context) ?: volume(context, drunk)}")
            .setContentText(status)
            .setContentIntent(openWater(context))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_STATUS)
        if (goal > 0) builder.setProgress(100, minOf(100, drunk * 100 / goal), false)
        presets(context).take(2).forEachIndexed { i, ml -> builder.addAction(addAction(context, ml, i)) }
        builder.addAction(action("Edit", openWater(context)))
        return builder.build()
    }

    private fun drunkToday(context: Context): Int {
        val p = prefs(context)
        val today = dayKey(System.currentTimeMillis())
        // Dart's total is for its day; a new day starts from zero.
        val base = if (p.getString("day", null) == today) p.getInt("drunkMl", 0) else 0
        val waiting = synchronized(this) {
            val file = File(context.filesDir, LOG)
            if (!file.exists()) {
                0
            } else {
                file.readLines().sumOf { line ->
                    val parts = line.split(',').mapNotNull { it.trim().toLongOrNull() }
                    if (parts.size == 2 && dayKey(parts[1]) == today) parts[0].toInt() else 0
                }
            }
        }
        return base + waiting
    }

    private fun presets(context: Context): List<Int> =
        (prefs(context).getString("presetsMl", "") ?: "")
            .split(',')
            .mapNotNull { it.trim().toIntOrNull() }
            .filter { it > 0 }

    private fun action(title: String, intent: PendingIntent): Notification.Action =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(null, title, intent).build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Action.Builder(0, title, intent).build()
        }

    private fun timeText(context: Context, millis: Long): String =
        android.text.format.DateFormat.getTimeFormat(context).format(Date(millis))

    private fun dayKey(millis: Long): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))

    private fun nextMidnight(): Long = Calendar.getInstance().apply {
        add(Calendar.DAY_OF_YEAR, 1)
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 1)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun refreshIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        CODE_REFRESH,
        Intent(context, WaterReceiver::class.java).setAction(ACTION_REFRESH),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Matches `mlPerFluidOunce` in lib/core/units.dart. */
    private const val ML_PER_FL_OZ = 29.5735
}

/** The water buttons: log a drink, snooze a reminder, the midnight redraw. */
class WaterReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val dismiss = intent.getIntExtra(WaterBar.EXTRA_DISMISS, -1)
        if (dismiss >= 0) {
            context.getSystemService(NotificationManager::class.java).cancel(dismiss)
        }
        when (intent.action) {
            WaterBar.ACTION_ADD -> WaterBar.add(context, intent.getIntExtra(WaterBar.EXTRA_ML, 0))
            WaterBar.ACTION_SNOOZE -> {
                Reminders.snoozeWater(context, WaterBar.SNOOZE_MINUTES)
                WaterBar.refresh(context)
            }
            WaterBar.ACTION_REFRESH -> WaterBar.refresh(context)
        }
    }
}
