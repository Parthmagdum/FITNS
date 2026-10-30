package com.trakvrs.fitns

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
class StepCounterStream(private val sensors: SensorManager) :
    EventChannel.StreamHandler, SensorEventListener {

    private var sink: EventChannel.EventSink? = null

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
        }
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val bootMillis = System.currentTimeMillis() - SystemClock.elapsedRealtime()
        sink?.success(mapOf("steps" to event.values[0].toLong(), "bootMillis" to bootMillis))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
