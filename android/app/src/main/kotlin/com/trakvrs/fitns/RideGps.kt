package com.trakvrs.fitns

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * A ride's distance and moving time from GPS fixes. Pure logic, no
 * Android: [RideService] feeds it the phone's own GPS (no internet, no
 * Play Services), so it works with the phone anywhere — pocket, bag or
 * handlebar.
 *
 * GPS wanders a few metres even standing still, so:
 *  * fixes less accurate than [MAX_ACCURACY_M] are ignored;
 *  * positions are smoothed (an average weighted to the last few fixes)
 *    before any distance is measured;
 *  * when the GPS's own speed (from the Doppler shift, accurate even when
 *    the position wanders) says stopped, nothing is added;
 *  * the distance only grows once the smoothed position is clearly away
 *    from the last counted point (more than [MIN_STEP_M]);
 *  * a jump faster than [MAX_SPEED_MPS] (a glitch) is skipped;
 *  * after a gap of [MAX_GAP_MS] (a tunnel, GPS lost) counting restarts
 *    from the next fix, without the straight line across the gap.
 *
 * Moving time is the time spent going faster than [MOVING_MPS].
 */
class RideGps(
    var meters: Double = 0.0,
    var movingMs: Long = 0,
    var maxSpeedMps: Double = 0.0,
) {
    private var lat = 0.0
    private var lon = 0.0
    private var smoothLat = 0.0
    private var smoothLon = 0.0
    private var atMs = 0L
    private var anchored = false

    /** The speed now (m/s); 0 when stopped or without a recent fix. */
    var speedMps = 0.0
        private set

    /** When the last usable fix came, or 0. */
    var lastFixMs = 0L
        private set

    /**
     * A fix: [dopplerMps] is the GPS's own speed reading, or null if the
     * fix has none.
     */
    fun onFix(
        latitude: Double,
        longitude: Double,
        accuracyM: Float,
        timeMs: Long,
        dopplerMps: Double? = null,
    ) {
        if (accuracyM > MAX_ACCURACY_M) return
        val gap = lastFixMs == 0L || timeMs - lastFixMs > MAX_GAP_MS
        lastFixMs = timeMs
        if (!anchored || gap) {
            smoothLat = latitude
            smoothLon = longitude
            anchor(latitude, longitude, timeMs)
            speedMps = 0.0
            return
        }
        smoothLat += (latitude - smoothLat) * SMOOTHING
        smoothLon += (longitude - smoothLon) * SMOOTHING
        val dtMs = timeMs - atMs
        if (dtMs <= 0) return
        if (dopplerMps != null && dopplerMps < MOVING_MPS) {
            // Stopped, whatever the position says. Start again from here
            // when moving on, so the wander isn't counted.
            speedMps = 0.0
            anchor(smoothLat, smoothLon, timeMs)
            return
        }
        val d = distanceM(lat, lon, smoothLat, smoothLon)
        if (d < max(MIN_STEP_M, accuracyM * 0.5)) {
            // Not clearly moved yet: stopped, or creeping. The anchor
            // stays, so slow progress still adds up once it shows.
            if (dtMs > 8_000) speedMps = 0.0
            return
        }
        val v = d / (dtMs / 1000.0)
        if (v > MAX_SPEED_MPS) {
            // A glitch: start again from here.
            smoothLat = latitude
            smoothLon = longitude
            anchor(latitude, longitude, timeMs)
            return
        }
        meters += d
        if (v >= MOVING_MPS) movingMs += dtMs
        val now = dopplerMps ?: v
        speedMps = now
        if (now > maxSpeedMps) maxSpeedMps = now
        anchor(smoothLat, smoothLon, timeMs)
    }

    /** No fix for a while: the speed reads 0. */
    fun stale(nowMs: Long): Boolean = lastFixMs == 0L || nowMs - lastFixMs > 10_000

    private fun anchor(latitude: Double, longitude: Double, timeMs: Long) {
        lat = latitude
        lon = longitude
        atMs = timeMs
        anchored = true
    }

    companion object {
        const val MAX_ACCURACY_M = 30f

        /** How much each fix moves the smoothed position. */
        const val SMOOTHING = 0.35
        const val MIN_STEP_M = 6.0
        const val MAX_SPEED_MPS = 25.0 // 90 km/h
        const val MOVING_MPS = 0.8 // ~3 km/h
        const val MAX_GAP_MS = 60_000L

        /** Great-circle distance in metres. */
        fun distanceM(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
            val r = 6_371_000.0
            val p1 = Math.toRadians(lat1)
            val p2 = Math.toRadians(lat2)
            val dp = p2 - p1
            val dl = Math.toRadians(lon2 - lon1)
            val h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
            return 2 * r * asin(sqrt(h))
        }
    }
}
