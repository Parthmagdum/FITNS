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
import org.json.JSONArray
import java.util.Calendar

/**
 * Repeating reminders — train, drink water, weigh in. Dart decides what they
 * are (`lib/core/notifications/reminders.dart`) and hands over the whole list
 * with [sync]; this keeps it in preferences, sets one system alarm per
 * reminder for its next time, and on each alarm shows the notification and
 * sets the next one. [rescheduleAll] restores them after a reboot.
 *
 * Inexact alarms: a reminder a few minutes late is fine, and they don't need
 * "Alarms & reminders" — unlike the rest timer.
 */
object Reminders {
    private const val PREFS = "fitns_reminders"
    private const val KEY = "list"
    private const val CHANNEL = "reminders"
    private const val EXTRA_ID = "id"

    private class Reminder(
        val id: Int,
        val title: String,
        val text: String,
        val hour: Int,
        val minute: Int,
        /** 1 = Monday … 7 = Sunday; null = every day. */
        val weekday: Int?,
    )

    fun sync(context: Context, json: String) {
        for (old in load(context)) alarms(context).cancel(alarmIntent(context, old.id))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, json).apply()
        rescheduleAll(context)
    }

    fun rescheduleAll(context: Context) {
        for (r in load(context)) schedule(context, r)
    }

    fun fire(context: Context, id: Int) {
        val reminder = load(context).firstOrNull { it.id == id } ?: return
        // A reminder to open the app while it's open is just noise.
        if (!MainActivity.inForeground) show(context, reminder)
        schedule(context, reminder)
    }

    private fun schedule(context: Context, r: Reminder) {
        alarms(context).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            nextTime(r, System.currentTimeMillis()),
            alarmIntent(context, r.id),
        )
    }

    /** The next moment after [now] that [r] is due. */
    private fun nextTime(r: Reminder, now: Long): Long {
        val c = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, r.hour)
            set(Calendar.MINUTE, r.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (r.weekday == null) {
            if (c.timeInMillis <= now) c.add(Calendar.DAY_OF_YEAR, 1)
            return c.timeInMillis
        }
        // Calendar counts Sunday as 1; reminders count Monday as 1.
        val target = r.weekday % 7 + 1
        var days = (target - c.get(Calendar.DAY_OF_WEEK) + 7) % 7
        if (days == 0 && c.timeInMillis <= now) days = 7
        c.add(Calendar.DAY_OF_YEAR, days)
        return c.timeInMillis
    }

    private fun show(context: Context, r: Reminder) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Workout, water and weigh-in reminders you set in FITNS"
                },
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val open = PendingIntent.getActivity(
            context,
            r.id,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_rest)
            .setContentTitle(r.title)
            .setContentText(r.text)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()
        manager.notify(NOTIFICATION_BASE + r.id, notification)
    }

    private fun load(context: Context): List<Reminder> {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map { i ->
                val o = array.getJSONObject(i)
                Reminder(
                    id = o.getInt("id"),
                    title = o.getString("title"),
                    text = o.getString("text"),
                    hour = o.getInt("hour"),
                    minute = o.getInt("minute"),
                    weekday = if (o.isNull("weekday")) null else o.getInt("weekday"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

    private fun alarmIntent(context: Context, id: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        ALARM_BASE + id,
        Intent(context, ReminderReceiver::class.java).putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Request codes clear of the rest timer's 41xx. */
    private const val ALARM_BASE = 50_000
    private const val NOTIFICATION_BASE = 60_000

    fun idOf(intent: Intent) = intent.getIntExtra(EXTRA_ID, -1)
}

/** A reminder's alarm went off. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.fire(context, Reminders.idOf(intent))
    }
}
