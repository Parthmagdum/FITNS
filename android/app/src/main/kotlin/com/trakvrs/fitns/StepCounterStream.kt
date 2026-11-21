package com.trakvrs.fitns

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/**
 * Streams the hardware step counter to Dart while something listens.
 *
 * Each event is `{steps: Long, bootMillis: Long}`: the counter's running total
 * since boot, and when that boot was (wall clock). Dart compares the boot time
 * with its last reading to tell a reboot — which zeroes the counter — from an
 * ordinary increase.
 *
 * Android only counts steps while some app has this sensor registered, so
 * with nothing else holding it, steps walked while FITNS is closed are lost.
 * All-day counting needs a foreground service; that arrives with GPS
 * tracking, which needs one anyway.
 */
class StepCounterStream(
    private val context: Context,
    private val sensors: SensorManager,
) : EventChannel.StreamHandler, SensorEventListener {

    private var sink: EventChannel.EventSink? = null
    private var filtering = false

    /** The newest counter reading not yet sent, and whether a send is due. */
    private var latestRaw = -1L
    private var sendDue = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            events.error("unavailable", "This device has no step counter", null)
            return
        }
        sink = events
        val registered = try {
            sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        } catch (e: SecurityException) {
            false
        }
        if (!registered) {
            events.error("denied", "Activity recognition permission is not granted", null)
            sink = null
            return
        }
        // Judges each step's rhythm, so vehicle vibration isn't counted.
        StepFilter.acquire(context)
        filtering = true
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
        if (filtering) StepFilter.release()
        filtering = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        latestRaw = event.values[0].toLong()
        // Readings come with nearly every step: send the newest once the
        // detector has delivered its steps, not one flush per step.
        if (sendDue) return
        sendDue = true
        StepFilter.afterFlush {
            sendDue = false
            val bootMillis = System.currentTimeMillis() - SystemClock.elapsedRealtime()
            val steps = StepFilter.filtered(context, latestRaw, bootMillis)
            sink?.success(mapOf("steps" to steps, "bootMillis" to bootMillis))
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
