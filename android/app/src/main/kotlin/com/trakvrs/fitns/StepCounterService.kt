package com.trakvrs.fitns

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
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
 *
 * With the screen off the hardware batches readings for minutes at a time
 * (the CPU sleeps). With it on, someone may be looking at a home-screen
 * widget, so readings come as they happen, and turning the screen on
 * flushes whatever was batched — the widgets are up to date at a glance.
 */
class StepCounterService : Service(), SensorEventListener {
    private data class Reading(val counter: Long, val at: Long, val boot: Long)

    private var latest: Reading? = null
    private var lastLoggedAt = 0L
    private var filtering = false
    private var sensor: Sensor? = null
    private var live: Boolean? = null

    /** Screen on: live readings, and the batch flushed. Off: batch again. */
    private val screen = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> listen(live = false)
                else -> {
                    listen(live = true)
                    (getSystemService(SENSOR_SERVICE) as SensorManager).flush(this@StepCounterService)
                }
            }
        }
    }

    /** (Re)registers the step counter: unbatched while [live], else batched. */
    private fun listen(live: Boolean) {
        val s = sensor ?: return
        if (this.live == live) return
        this.live = live
        val sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        sensors.unregisterListener(this, s)
        // Batched: the counter is cumulative, so a late delivery loses
        // nothing, and the CPU can sleep.
        sensors.registerListener(this, s, SensorManager.SENSOR_DELAY_NORMAL, if (live) LIVE_US else BATCH_US)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null || !startInForeground()) {
            stopSelf()
            return
        }
        this.sensor = sensor
        listen(live = (getSystemService(POWER_SERVICE) as PowerManager).isInteractive)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screen, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screen, filter)
        }
        // Judges each step's rhythm, so vehicle vibration isn't booked.
        StepFilter.acquire(this)
        filtering = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        if (sensor != null) {
            try {
                unregisterReceiver(screen)
            } catch (e: IllegalArgumentException) {
                // Never registered.
            }
        }
        (getSystemService(SENSOR_SERVICE) as SensorManager).unregisterListener(this)
        if (filtering) StepFilter.release()
        latest?.let { if (it.at > lastLoggedAt) log(it) }
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        // The event object is reused by Android: copy it before waiting.
        val raw = event.values[0].toLong()
        val timestamp = event.timestamp
        // Let the detector deliver the steps it holds first, so they're
        // judged before this reading is booked.
        StepFilter.afterFlush { book(raw, timestamp) }
    }

    private fun book(raw: Long, timestamp: Long) {
        val boot = System.currentTimeMillis() - SystemClock.elapsedRealtime()
        val now = System.currentTimeMillis()
        // A batched event can arrive minutes late; its own timestamp (since
        // boot) says when the steps happened. Distrust anything implausible.
        val stamped = boot + timestamp / 1_000_000
        val at = if (stamped in (now - DAY_MS)..(now + 60_000)) stamped else now
        val reading = Reading(StepFilter.filtered(this, raw, boot), at, boot)
        // The home-screen widgets count on without FITNS open.
        FitnsWidget.onStepReading(this, reading.counter, reading.at)

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

        /** Screen on: a couple of seconds, so a widget keeps up as you walk. */
        private const val LIVE_US = 2 * 1_000_000
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
