package com.trakvrs.fitns

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * The rest timer, for when FITNS isn't on screen. Dart owns the timer itself;
 * this only makes sure a locked phone still says when rest is over.
 *
 *  - On [schedule], a system alarm is set for the end — it wakes the phone,
 *    which a Dart timer can't.
 *  - When the app is left mid-rest ([showCountdown], from MainActivity's
 *    onPause), a silent notification counts down on the lock screen.
 *  - At the end ([onRestEnded]), if the app still isn't in front, that
 *    notification becomes a "Rest over" alert. If it is in front, the app
 *    has already rung ([ring]) and nothing is shown.
 *
 * Either way it *rings*: the phone's alarm sound, briefly, on the alarm
 * volume — which a phone on silent still plays — and a buzz. A silent
 * alert is one nobody notices mid-workout. Settings can turn the sound off.
 */
object RestAlert {
    private const val COUNTDOWN_CHANNEL = "rest"
    private const val DONE_CHANNEL = "rest_done"
    private const val NOTIFICATION_ID = 4103
    private const val ALARM_REQUEST = 4104

    private const val DONE_CHANNEL_V2 = "rest_ring"
    private const val PREFS = "fitns_rest"
    private const val RING_MS = 3500L

    /** When the current rest ends (wall clock); 0 when none is running. */
    @Volatile
    private var endsAt = 0L

    private var playing: Ringtone? = null

    /** Whether rest ends with the alarm sound (Settings), kept for the receiver. */
    fun setRing(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("ring", on).apply()
    }

    private fun ringOn(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("ring", true)

    /**
     * Rest is over: the alarm sound for a few seconds (if on) and a buzz.
     * [done] runs once the sound has stopped.
     */
    fun ring(context: Context, done: () -> Unit = {}) {
        buzz(context)
        if (!ringOn(context)) {
            done()
            return
        }
        val uri = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val tone = try {
            RingtoneManager.getRingtone(context, uri)
        } catch (e: Exception) {
            null
        }
        if (tone == null) {
            done()
            return
        }
        playing?.stop()
        tone.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        try {
            tone.play()
            playing = tone
        } catch (e: Exception) {
            done()
            return
        }
        Handler(Looper.getMainLooper()).postDelayed({
            tone.stop()
            if (playing === tone) playing = null
            done()
        }, RING_MS)
    }

    private fun buzz(context: Context) {
        val pattern = longArrayOf(0, 400, 200, 400, 200, 400)
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        } ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

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

    fun onRestEnded(context: Context, done: () -> Unit = {}) {
        endsAt = 0L
        if (MainActivity.inForeground) {
            hide(context)
            done()
            return
        }
        ensureChannels(context)
        val builder = builder(context, DONE_CHANNEL_V2)
            .setContentTitle("Rest over")
            .setContentText("Time for your next set")
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setDefaults(Notification.DEFAULT_ALL).setPriority(Notification.PRIORITY_HIGH)
        }
        context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, builder.build())
        // The notification itself stays quiet (its channel has no sound): the
        // ring is played here, on the alarm volume, so silent mode can't
        // swallow it.
        ring(context, done)
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
        // The old buzzing channel: its sound can't be changed once made.
        manager.deleteNotificationChannel(DONE_CHANNEL)
        manager.createNotificationChannel(
            NotificationChannel(DONE_CHANNEL_V2, "Rest over", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Tells you when it's time for the next set. FITNS rings by itself."
                setSound(null, null)
                enableVibration(false)
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
    override fun onReceive(context: Context, intent: Intent) {
        // Kept alive until the ring has played.
        val pending = goAsync()
        RestAlert.onRestEnded(context) { pending.finish() }
    }
}
