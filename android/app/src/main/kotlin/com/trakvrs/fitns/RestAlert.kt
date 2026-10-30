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

/**
 * The rest timer, for when FITNS isn't on screen. Dart owns the timer itself;
 * this only makes sure a locked phone still says when rest is over.
 *
 *  - On [schedule], a system alarm is set for the end — it wakes the phone,
 *    which a Dart timer can't.
 *  - When the app is left mid-rest ([showCountdown], from MainActivity's
 *    onPause), a silent notification counts down on the lock screen.
 *  - At the end ([onRestEnded]), if the app still isn't in front, that
 *    notification becomes a "Rest over" alert that vibrates. If it is in
 *    front, the app has already buzzed and nothing is shown.
 */
object RestAlert {
    private const val COUNTDOWN_CHANNEL = "rest"
    private const val DONE_CHANNEL = "rest_done"
    private const val NOTIFICATION_ID = 4103
    private const val ALARM_REQUEST = 4104

    /** When the current rest ends (wall clock); 0 when none is running. */
    @Volatile
    private var endsAt = 0L

    fun schedule(context: Context, endsAtMillis: Long) {
        endsAt = endsAtMillis
        val alarms = context.getSystemService(AlarmManager::class.java)
        val intent = alarmIntent(context)
        // Exact needs "Alarms & reminders" on Android 12+, which Android 14
        // no longer grants by default; without it the alert can run late, so
        // Settings offers to turn it on.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAtMillis, intent)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAtMillis, intent)
        }
    }

    fun cancel(context: Context) {
        endsAt = 0L
        context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context))
        hide(context)
    }

    fun canAlertOnTime(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun showCountdown(context: Context) {
        val end = endsAt
        if (end <= System.currentTimeMillis()) return
        ensureChannels(context)
        val notification = builder(context, COUNTDOWN_CHANNEL)
            .setContentTitle("Resting")
            .setContentText("Your next set is up when this reaches zero")
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(end)
            .setShowWhen(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }

    fun hide(context: Context) {
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
    }

    fun onRestEnded(context: Context) {
        endsAt = 0L
        if (MainActivity.inForeground) {
            hide(context)
            return
        }
        ensureChannels(context)
        val builder = builder(context, DONE_CHANNEL)
            .setContentTitle("Rest over")
            .setContentText("Time for your next set")
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setDefaults(Notification.DEFAULT_ALL).setPriority(Notification.PRIORITY_HIGH)
        }
        context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, builder.build())
    }

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(COUNTDOWN_CHANNEL, "Rest countdown", NotificationManager.IMPORTANCE_LOW).apply {
                description = "A silent countdown while you rest between sets"
                setShowBadge(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(DONE_CHANNEL, "Rest over", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Tells you when it's time for the next set"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400)
            },
        )
    }

    private fun builder(context: Context, channel: String): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return builder.setSmallIcon(R.drawable.ic_stat_rest).setContentIntent(open)
    }

    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        ALARM_REQUEST,
        Intent(context, RestAlarmReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

/** The system alarm set by [RestAlert.schedule] — rest is over. */
class RestAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = RestAlert.onRestEnded(context)
}
