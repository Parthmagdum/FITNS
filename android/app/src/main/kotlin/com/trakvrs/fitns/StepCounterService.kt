package com.trakvrs.fitns

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import java.util.Calendar

/**
 * Keeps the hardware step counter registered while FITNS is closed.
 *
 * Android's step counter only counts while some app has it registered, so
 * without this, steps walked with FITNS closed were simply lost. It runs as a
 * foreground service of type `health` (a silent, minimum-priority
 * notification) and writes readings to [StepLog] — at most every few minutes,
 * plus one either side of midnight so each day gets its own steps.
 */
class StepCounterService : Service(), SensorEventListener {
    private data class Reading(val counter: Long, val at: Long, val boot: Long)

    private var latest: Reading? = null
    private var lastLoggedAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null || !startInForeground()) {
            stopSelf()
            return
        }
        // Let the hardware batch for minutes at a time: the counter is
        // cumulative, so a late delivery loses nothing, and the CPU can sleep.
        sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL, BATCH_US)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        (getSystemService(SENSOR_SERVICE) as SensorManager).unregisterListener(this)
        latest?.let { if (it.at > lastLoggedAt) log(it) }
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val boot = System.currentTimeMillis() - SystemClock.elapsedRealtime()
        val now = System.currentTimeMillis()
        // A batched event can arrive minutes late; its own timestamp (since
        // boot) says when the steps happened. Distrust anything implausible.
        val stamped = boot + event.timestamp / 1_000_000
        val at = if (stamped in (now - DAY_MS)..(now + 60_000)) stamped else now
        val reading = Reading(event.values[0].toLong(), at, boot)

        val previous = latest
        latest = reading
        val newDay = previous != null && dayOf(previous.at) != dayOf(reading.at)
        // Close out yesterday with its last reading before booking today's.
        if (newDay && previous.at > lastLoggedAt) log(previous)
        if (lastLoggedAt == 0L || newDay || reading.at - lastLoggedAt >= LOG_EVERY_MS) {
            log(reading)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun log(r: Reading) {
        StepLog.append(this, r.counter, r.at, r.boot)
        lastLoggedAt = r.at
    }

    private fun dayOf(millis: Long): Int {
        val c = Calendar.getInstance().apply { timeInMillis = millis }
        return c.get(Calendar.YEAR) * 1000 + c.get(Calendar.DAY_OF_YEAR)
    }

    /** False if Android refused — the service then just stops. */
    private fun startInForeground(): Boolean {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Step counting", NotificationManager.IMPORTANCE_MIN).apply {
                    description = "Shown while FITNS counts steps in the background"
                    setShowBadge(false)
                },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_steps)
            .setContentTitle("Counting steps")
            .setContentText("Turn off in FITNS → Settings")
            .setContentIntent(open)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (e: SecurityException) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "steps"
        private const val NOTIFICATION_ID = 4102
        private const val BATCH_US = 5 * 60 * 1_000_000
        private const val LOG_EVERY_MS = 5 * 60 * 1000L
        private const val DAY_MS = 24 * 60 * 60 * 1000L

        /** The sensor exists and activity recognition is granted. */
        fun canCount(context: Context): Boolean {
            val sensors = context.getSystemService(SENSOR_SERVICE) as SensorManager
            if (sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) == null) return false
            return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
                PackageManager.PERMISSION_GRANTED
        }

        /**
         * Starts the service if it can count. Checked first because a
         * foreground service that fails to call startForeground in time
         * crashes the app.
         */
        fun start(context: Context) {
            if (!canCount(context)) return
            val intent = Intent(context, StepCounterService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: IllegalStateException) {
                // Background start not allowed right now; the next launch retries.
            } catch (e: SecurityException) {
                // Permission revoked between the check and the start.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, StepCounterService::class.java))
        }
    }
}
