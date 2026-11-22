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
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/**
 * Tracks a bike ride between Start and Stop on the Cycling page, with the
 * screen off:
 *
 *  * **Pedal turns** ([PedalCadence]) from the gyroscope (or the
 *    accelerometer on phones without one), with the phone in a trouser
 *    pocket.
 *  * **Distance and speed** ([RideGps]) from the phone's own GPS, if the
 *    rider allowed location — no internet and no Play Services, and it
 *    works with the phone anywhere on the bike.
 *
 * A foreground service of type `health` (and `location`, with GPS) holding
 * a partial wake lock — the motion sensors stop when the phone sleeps.
 *
 * The ride's numbers live in shared preferences ([PREFS]), saved every few
 * seconds, so Dart can read them while the ride runs and a ride survives
 * FITNS being closed. Stopping (from FITNS or the notification) leaves them
 * there with `running` false for Dart to book.
 */
class RideService : Service(), SensorEventListener, LocationListener {
    private var cadence: PedalCadence? = null
    private var gps: RideGps? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastSavedNs = 0L
    private var lastNotifiedNs = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val withGps = locationAllowed(this) && hasGps(this)
        // Restarted by Android after the ride was stopped: nothing to do.
        if (!prefs(this).getBoolean("running", false)) {
            startInForeground(withGps = false)
            stopSelf()
            return
        }
        if (accelerometer == null || !startInForeground(withGps)) {
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
        sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE)?.let {
            sensors.registerListener(this, it, SAMPLE_US)
        }
        sensors.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)?.let {
            try {
                sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            } catch (e: SecurityException) {
                // No activity permission: footstep jolts still keep walking out.
            }
        }
        if (withGps) {
            gps = RideGps(
                meters = p.getFloat("gpsMeters", 0f).toDouble(),
                movingMs = p.getLong("gpsMovingMs", 0),
                maxSpeedMps = p.getFloat("gpsMaxMps", 0f).toDouble(),
            )
            try {
                (getSystemService(LOCATION_SERVICE) as LocationManager).requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    GPS_EVERY_MS,
                    0f,
                    this,
                    Looper.getMainLooper(),
                )
            } catch (e: Exception) {
                // Permission taken back, or no GPS after all: pedals only.
                gps = null
            }
        }
        p.edit()
            .putBoolean("gpsOn", gps != null)
            .putBoolean("gyro", sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null)
            .apply()
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
        if (gps != null) {
            try {
                (getSystemService(LOCATION_SERVICE) as LocationManager).removeUpdates(this)
            } catch (e: Exception) {
                // Already gone.
            }
        }
        save()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val c = cadence ?: return
        val v = event.values
        when (event.sensor.type) {
            Sensor.TYPE_STEP_DETECTOR -> c.onStep(event.timestamp)
            Sensor.TYPE_GYROSCOPE -> c.onRotation(event.timestamp, v[0], v[1], v[2])
            Sensor.TYPE_ACCELEROMETER -> {
                c.onSample(event.timestamp, v[0], v[1], v[2])
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

    override fun onLocationChanged(location: Location) {
        val g = gps ?: return
        val accuracy = if (location.hasAccuracy()) location.accuracy else 50f
        val doppler = if (location.hasSpeed()) location.speed.toDouble() else null
        g.onFix(location.latitude, location.longitude, accuracy, location.time, doppler)
    }

    // Needed below API 29, where these aren't defaults.
    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit

    private fun save() {
        val c = cadence ?: return
        val e = prefs(this).edit()
            .putLong("revolutions", c.revolutions)
            .putLong("movingMs", c.movingNs / 1_000_000)
            .putInt("cadence", c.cadence)
        gps?.let { g ->
            val now = System.currentTimeMillis()
            e.putFloat("gpsMeters", g.meters.toFloat())
                .putLong("gpsMovingMs", g.movingMs)
                .putFloat("gpsMaxMps", g.maxSpeedMps.toFloat())
                .putFloat("gpsSpeedMps", if (g.stale(now)) 0f else g.speedMps.toFloat())
                .putBoolean("gpsFix", !g.stale(now))
        }
        e.apply()
    }

    private fun notification(): Notification {
        val c = cadence
        val g = gps
        val minutes = (c?.movingNs ?: 0) / 60_000_000_000L
        val text = if (g != null && g.meters > 0) {
            "%.1f km · %d pedal turns".format(g.meters / 1000, c?.revolutions ?: 0)
        } else {
            "$minutes min pedalling · ${c?.revolutions ?: 0} pedal turns"
        }
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
            .setContentText(text)
            .setContentIntent(open)
            .addAction(0, "Stop ride", stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setUsesChronometer(true)
            .setWhen(prefs(this).getLong("startedAt", System.currentTimeMillis()))
            .build()
    }

    /** False if Android refused — the service then just stops. */
    private fun startInForeground(withGps: Boolean): Boolean {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Bike rides", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shown while FITNS tracks a bike ride"
                    setShowBadge(false)
                },
            )
        }
        fun start(types: Int) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification(), types)
            } else {
                startForeground(NOTIFICATION_ID, notification())
            }
        }
        return try {
            val health = ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
            if (withGps && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                try {
                    start(health or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
                } catch (e: SecurityException) {
                    start(health)
                }
            } else {
                start(health)
            }
            true
        } catch (e: Exception) {
            // A background start Android doesn't allow.
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
        private const val GPS_EVERY_MS = 1_000L
        private const val SAVE_EVERY_NS = 3_000_000_000L
        private const val NOTIFY_EVERY_NS = 30_000_000_000L

        /** The wake lock lets go by itself after this, if a ride is forgotten. */
        private const val MAX_RIDE_MS = 8 * 60 * 60 * 1000L

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun available(context: Context): Boolean =
            (context.getSystemService(SENSOR_SERVICE) as SensorManager)
                .getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

        fun hasGps(context: Context): Boolean =
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)

        fun locationAllowed(context: Context): Boolean =
            context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED

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

        /** The ride now (or the last one, until cleared): null if there is none. */
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
                "gpsOn" to p.getBoolean("gpsOn", false),
                "gpsFix" to p.getBoolean("gpsFix", false),
                "gpsMeters" to p.getFloat("gpsMeters", 0f).toDouble(),
                "gpsMovingMs" to p.getLong("gpsMovingMs", 0),
                "gpsSpeedMps" to p.getFloat("gpsSpeedMps", 0f).toDouble(),
                "gpsMaxMps" to p.getFloat("gpsMaxMps", 0f).toDouble(),
                "gyro" to p.getBoolean("gyro", false),
            )
        }

        /** Forgets the stopped ride once Dart has booked it. */
        fun clear(context: Context) {
            val p = prefs(context)
            if (!p.getBoolean("running", false)) p.edit().clear().apply()
        }
    }
}
