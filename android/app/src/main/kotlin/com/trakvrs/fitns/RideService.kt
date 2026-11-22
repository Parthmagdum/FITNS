package com.trakvrs.fitns

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Counts pedal turns ([PedalCadence]) during a bike ride, with the phone in
 * a pocket and the screen off. Runs only between Start and Stop on the
 * Cycling page, as a foreground service of type `health` holding a partial
 * wake lock — the accelerometer stops when the phone sleeps, so a ride
 * can't be counted any other way without the internet or Play Services.
 *
 * The ride's numbers live in shared preferences ([PREFS]), saved every few
 * seconds, so Dart can read them while the ride runs and a ride survives
 * FITNS being closed. Stopping (from FITNS or the notification) leaves them
 * there with `running` false for Dart to book.
 */
class RideService : Service(), SensorEventListener {
    private var cadence: PedalCadence? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastSavedNs = 0L
    private var lastNotifiedNs = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        // Restarted by Android after the ride was stopped: nothing to do.
        if (!prefs(this).getBoolean("running", false)) {
            startInForeground()
            stopSelf()
            return
        }
        if (accelerometer == null || !startInForeground()) {
            prefs(this).edit().putBoolean("running", false).apply()
            stopSelf()
            return
        }
        val p = prefs(this)
        cadence = PedalCadence(p.getLong("revolutions", 0), p.getLong("movingMs", 0) * 1_000_000)
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "fitns:ride")
            .apply {
                setReferenceCounted(false)
                acquire(MAX_RIDE_MS)
            }
        sensors.registerListener(this, accelerometer, SAMPLE_US)
        sensors.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)?.let {
            try {
                sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            } catch (e: SecurityException) {
                // No activity permission: hard swings still keep walking out.
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            prefs(this).edit()
                .putBoolean("running", false)
                .putLong("stoppedAt", System.currentTimeMillis())
                .apply()
            stopSelf()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        (getSystemService(SENSOR_SERVICE) as SensorManager).unregisterListener(this)
        save()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val c = cadence ?: return
        when (event.sensor.type) {
            Sensor.TYPE_STEP_DETECTOR -> c.onStep(event.timestamp)
            Sensor.TYPE_ACCELEROMETER -> {
                c.onSample(event.timestamp, event.values[0], event.values[1], event.values[2])
                if (event.timestamp - lastSavedNs > SAVE_EVERY_NS) {
                    lastSavedNs = event.timestamp
                    save()
                }
                if (event.timestamp - lastNotifiedNs > NOTIFY_EVERY_NS) {
                    lastNotifiedNs = event.timestamp
                    (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                        .notify(NOTIFICATION_ID, notification())
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun save() {
        val c = cadence ?: return
        prefs(this).edit()
            .putLong("revolutions", c.revolutions)
            .putLong("movingMs", c.movingNs / 1_000_000)
            .putInt("cadence", c.cadence)
            .apply()
    }

    private fun notification(): Notification {
        val c = cadence
        val minutes = (c?.movingNs ?: 0) / 60_000_000_000L
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, RideService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        @Suppress("DEPRECATION")
        return builder
            .setSmallIcon(R.drawable.ic_stat_steps)
            .setContentTitle("Cycling")
            .setContentText("$minutes min pedalling · ${c?.revolutions ?: 0} pedal turns")
            .setContentIntent(open)
            .addAction(0, "Stop ride", stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setUsesChronometer(true)
            .setWhen(prefs(this).getLong("startedAt", System.currentTimeMillis()))
            .build()
    }

    /** False if Android refused — the service then just stops. */
    private fun startInForeground(): Boolean {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Bike rides", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shown while FITNS counts a bike ride"
                    setShowBadge(false)
                },
            )
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
            } else {
                startForeground(NOTIFICATION_ID, notification())
            }
            true
        } catch (e: Exception) {
            // SecurityException without the activity permission, or a
            // background start Android doesn't allow.
            false
        }
    }

    companion object {
        private const val PREFS = "fitns_ride"
        private const val CHANNEL = "rides"
        private const val NOTIFICATION_ID = 4103
        private const val ACTION_STOP = "com.trakvrs.fitns.STOP_RIDE"

        /** 50 readings a second: plenty for 180 rpm. */
        private const val SAMPLE_US = 20_000
        private const val SAVE_EVERY_NS = 5_000_000_000L
        private const val NOTIFY_EVERY_NS = 30_000_000_000L

        /** The wake lock lets go by itself after this, if a ride is forgotten. */
        private const val MAX_RIDE_MS = 8 * 60 * 60 * 1000L

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun available(context: Context): Boolean =
            (context.getSystemService(SENSOR_SERVICE) as SensorManager)
                .getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

        /** Starts a new ride, unless one is running. */
        fun start(context: Context): Boolean {
            if (!available(context)) return false
            val p = prefs(context)
            if (!p.getBoolean("running", false)) {
                p.edit().clear()
                    .putBoolean("running", true)
                    .putLong("startedAt", System.currentTimeMillis())
                    .commit()
            }
            val intent = Intent(context, RideService::class.java)
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (e: Exception) {
                p.edit().putBoolean("running", false).apply()
                false
            }
        }

        /** Stops the ride; its numbers stay until [clear]. */
        fun stop(context: Context) {
            val p = prefs(context)
            if (p.getBoolean("running", false)) {
                p.edit()
                    .putBoolean("running", false)
                    .putLong("stoppedAt", System.currentTimeMillis())
                    .commit()
            }
            context.stopService(Intent(context, RideService::class.java))
        }

        /**
         * The ride now (or the last one, until cleared): null if there is
         * none. Restarts the counting if FITNS was killed mid-ride.
         */
        fun status(context: Context): Map<String, Any>? {
            val p = prefs(context)
            if (!p.contains("startedAt")) return null
            return mapOf(
                "running" to p.getBoolean("running", false),
                "startedAt" to p.getLong("startedAt", 0),
                "revolutions" to p.getLong("revolutions", 0),
                "movingMs" to p.getLong("movingMs", 0),
                "cadence" to p.getInt("cadence", 0),
                "stoppedAt" to p.getLong("stoppedAt", 0),
            )
        }

        /** Forgets the stopped ride once Dart has booked it. */
        fun clear(context: Context) {
            val p = prefs(context)
            if (!p.getBoolean("running", false)) p.edit().clear().apply()
        }
    }
}
