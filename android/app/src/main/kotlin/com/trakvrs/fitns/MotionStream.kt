package com.trakvrs.fitns

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

/**
 * Raw samples from one sensor while Dart listens — for counting reps during
 * a set. All interpretation (thresholds, filtering, what counts as a rep)
 * happens in Dart (`lib/core/motion/`), where it is unit-tested.
 *
 * Each event is a double array: `[timeMillisSinceBoot, maximumRange, values…]`.
 */
class MotionStream(
    private val sensors: SensorManager,
    private val type: Int,
    private val periodUs: Int,
) : EventChannel.StreamHandler, SensorEventListener {

    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensors.getDefaultSensor(type)
        if (sensor == null) {
            events.error("unavailable", "This device has no such sensor", null)
            return
        }
        sink = events
        sensors.registerListener(this, sensor, periodUs)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val payload = DoubleArray(event.values.size + 2)
        payload[0] = event.timestamp / 1_000_000.0
        payload[1] = event.sensor.maximumRange.toDouble()
        for (i in event.values.indices) payload[i + 2] = event.values[i].toDouble()
        sink?.success(payload)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
