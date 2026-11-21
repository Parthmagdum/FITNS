package com.trakvrs.fitns

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener2
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock

/**
 * The step counter with vehicle vibration taken out ([StepRhythm]). Both the
 * live stream and the background service report its [filtered] total instead
 * of the raw counter, so Dart's counting rules — reboots, day boundaries —
 * stay exactly as they were.
 *
 * Listens to the step *detector* (one event per step, with its time) while
 * anything that counts is running. Everything runs on the main thread.
 */
object StepFilter : SensorEventListener2 {
    private const val PREFS = "fitns_step_filter"

    /** A different boot by more than this is a reboot, not clock jitter. */
    private const val REBOOT_SLACK_MS = 60_000L

    /** How long to wait for the detector to deliver before reporting anyway. */
    private const val FLUSH_TIMEOUT_MS = 2_000L

    private val timeouts = Handler(Looper.getMainLooper())
    private var users = 0
    private var sensors: SensorManager? = null
    private var rhythm: StepRhythm? = null
    private var boot = 0L
    private val waiting = mutableListOf<() -> Unit>()

    /** Something that counts steps started; listen to the detector. */
    fun acquire(context: Context) {
        users++
        load(context)
        if (users > 1 || sensors != null) return
        val manager = context.getSystemService(SensorManager::class.java) ?: return
        val detector = manager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR) ?: return
        val registered = try {
            manager.registerListener(this, detector, SensorManager.SENSOR_DELAY_NORMAL)
        } catch (e: SecurityException) {
            false
        }
        if (registered) sensors = manager
    }

    fun release() {
        users = maxOf(0, users - 1)
        if (users > 0) return
        sensors?.unregisterListener(this)
        sensors = null
        runWaiting()
    }

    /**
     * Runs [then] once the detector has delivered the steps it was holding,
     * so they're judged before the counter's reading is passed on.
     */
    fun afterFlush(then: () -> Unit) {
        val manager = sensors
        if (manager == null) {
            then()
            return
        }
        waiting.add(then)
        if (waiting.size > 1) return
        if (!manager.flush(this)) {
            runWaiting()
            return
        }
        timeouts.postDelayed(::runWaiting, FLUSH_TIMEOUT_MS)
    }

    /** The filtered total for the counter's [raw] reading, since the boot at [bootMillis]. */
    fun filtered(context: Context, raw: Long, bootMillis: Long): Long {
        val r = load(context)
        if (boot == 0L || kotlin.math.abs(bootMillis - boot) > REBOOT_SLACK_MS) {
            // A reboot zeroed the counter: the filtered total restarts too,
            // so Dart sees the same reset it always has.
            if (boot != 0L) {
                r.reported = 0
                r.lastRaw = 0
            }
            boot = bootMillis
        }
        val value = r.report(raw, SystemClock.elapsedRealtimeNanos())
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("reported", r.reported)
            .putLong("lastRaw", r.lastRaw)
            .putLong("boot", boot)
            .apply()
        return value
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_DETECTOR) return
        rhythm?.onStep(event.timestamp)
    }

    override fun onFlushCompleted(sensor: Sensor) = runWaiting()

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun runWaiting() {
        timeouts.removeCallbacksAndMessages(null)
        val due = waiting.toList()
        waiting.clear()
        for (then in due) then()
    }

    private fun load(context: Context): StepRhythm {
        rhythm?.let { return it }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        boot = prefs.getLong("boot", 0L)
        // No history yet: the first reading passes straight through, so the
        // total carries on from the raw counter Dart already knows.
        return StepRhythm(
            reported = prefs.getLong("reported", -1L),
            lastRaw = prefs.getLong("lastRaw", -1L),
        ).also { rhythm = it }
    }
}
