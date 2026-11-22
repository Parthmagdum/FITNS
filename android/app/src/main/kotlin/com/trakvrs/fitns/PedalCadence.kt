package com.trakvrs.fitns

import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Counts pedal turns from the phone's motion sensors. Pure logic, no
 * Android: [RideService] feeds it.
 *
 * With the phone in a trouser pocket, each turn of the pedals swings the
 * thigh up and back down once. The **gyroscope** sees that directly: the
 * thigh's turning speed swings once per turn, strongly (a few rad/s),
 * whichever way up the phone sits. Phones without one fall back to the
 * **accelerometer**: the tilt shifts gravity across the phone's axes once
 * per turn. (The accelerometer alone can go nearly blind at some
 * cadences — the thigh's own swing cancels the tilt — so the gyroscope is
 * used whenever there is one.)
 *
 * Either way the reading is taken along the direction it swings most in
 * ([SwingAxis]), and a swing is counted when that signal goes clearly
 * below zero and then clearly above it (hysteresis, so road buzz doesn't
 * count). Then each is judged by its rhythm, like [StepRhythm] judges
 * steps:
 *
 *  * Turns only count once [CONFIRM] of them come at a steady pace between
 *    [MIN_GAP_NS] and [MAX_GAP_NS] apart (40–180 rpm) — then all of them
 *    count, the first ones too.
 *  * While pedalling holds, each turn keeps counting as long as it stays
 *    close to the typical pace. A pause or a turn out of rhythm ends it,
 *    and turns that never settled into a rhythm don't count.
 *  * Walking isn't pedalling: the step detector firing ([onStep]), the
 *    sudden jolt of a footstep on the accelerometer ([JOLT]), or a lopsided swing
 *    ([LOPSIDED]) stops counting.
 *
 * Moving time is the time between counted turns, so stops at lights are
 * left out.
 */
class PedalCadence(
    /** Turns counted so far (carried over when a ride is resumed). */
    var revolutions: Long = 0,
    /** Nanoseconds spent pedalling so far. */
    var movingNs: Long = 0,
) {
    private val tilt = SwingAxis()
    private val rotation = SwingAxis()
    private var hasGyro = false

    private var level = Double.NaN
    private var lastJoltNs = 0L

    private var armed = false
    private var swingUp = 0.0
    private var swingDown = 0.0
    private var lopsided = false

    private var lastTurnNs = 0L
    private val gaps = ArrayDeque<Long>()
    private var confirmed = false
    private var pending = 0
    private var pendingNs = 0L
    private var lastStepNs = 0L
    private var recentSteps = 0

    /** The pace now, in turns a minute; 0 when not pedalling. */
    val cadence: Int
        get() = if (!confirmed || gaps.isEmpty()) 0 else (60_000_000_000L / median(gaps)).toInt()

    /** Counting from the gyroscope (else the accelerometer). */
    val usingGyroscope: Boolean
        get() = hasGyro

    /** One accelerometer reading (m/s²) at [ns] nanoseconds since boot. */
    fun onSample(ns: Long, x: Float, y: Float, z: Float) {
        val m = sqrt((x * x + y * y + z * z).toDouble())
        if (level.isNaN()) level = m
        // A footstep lands with a sudden jump; even hard pedalling changes
        // smoothly. So it's the jump from one reading to the next that
        // counts (lightly smoothed against buzz), not its size.
        val before = level
        level += (m - level) * 0.5
        if (abs(level - before) > JOLT) lastJoltNs = ns
        val signal = tilt.add(x.toDouble(), y.toDouble(), z.toDouble())
        if (!hasGyro) onSignal(ns, signal, ACCEL_THRESHOLD)
    }

    /** One gyroscope reading (rad/s) at [ns] nanoseconds since boot. */
    fun onRotation(ns: Long, x: Float, y: Float, z: Float) {
        if (!hasGyro) {
            // Switch over cleanly: whatever the accelerometer had pending
            // is dropped.
            hasGyro = true
            endRun()
            armed = false
        }
        onSignal(ns, rotation.add(x.toDouble(), y.toDouble(), z.toDouble()), GYRO_THRESHOLD)
    }

    /** A step-detector event: walking, so whatever is pending isn't pedalling. */
    fun onStep(ns: Long) {
        recentSteps = if (ns - lastStepNs < STEP_WINDOW_NS) recentSteps + 1 else 1
        lastStepNs = ns
        if (recentSteps >= 3) endRun()
    }

    private fun onSignal(ns: Long, s: Double, threshold: Double) {
        if (s > swingUp) swingUp = s
        if (-s > swingDown) swingDown = -s
        if (s < -threshold) {
            if (!armed) {
                // A swing has ended: judge its shape. Pedalling rises and
                // falls evenly.
                val big = maxOf(swingUp, swingDown)
                val small = minOf(swingUp, swingDown)
                if (big > LOPSIDED * small) lopsided = true
                swingUp = 0.0
                swingDown = -s
            }
            armed = true
        } else if (armed && s > threshold) {
            armed = false
            if (lopsided) {
                lopsided = false
                endRun()
            } else {
                onTurn(ns)
            }
        }
    }

    private fun walking(ns: Long) =
        (recentSteps >= 3 && ns - lastStepNs < STEP_WINDOW_NS) ||
            (lastJoltNs != 0L && ns - lastJoltNs < JOLT_WINDOW_NS)

    internal fun onTurn(ns: Long) {
        val gap = if (lastTurnNs == 0L) -1L else ns - lastTurnNs
        lastTurnNs = ns
        if (walking(ns) || gap < MIN_GAP_NS || gap > MAX_GAP_NS) {
            endRun()
            pending = 1
            return
        }
        if (confirmed) {
            val typical = median(gaps)
            if (gap >= typical * 3 / 5 && gap <= typical * 8 / 5) {
                push(gap)
                revolutions++
                movingNs += gap
                return
            }
            endRun()
            pending = 1
            return
        }
        pending++
        pendingNs += gap
        push(gap)
        if (pending < CONFIRM) return
        if (steady(gaps)) {
            // Steady pedalling: every turn of it counts, the first ones too.
            confirmed = true
            revolutions += pending
            movingNs += pendingNs
            pending = 0
            pendingNs = 0
        } else {
            // The oldest swing can't be part of a steady rhythm.
            pending--
            pendingNs -= gaps.removeFirst()
        }
    }

    private fun endRun() {
        confirmed = false
        pending = 0
        pendingNs = 0
        gaps.clear()
    }

    private fun push(gap: Long) {
        gaps.addLast(gap)
        while (gaps.size > CONFIRM) gaps.removeFirst()
    }

    companion object {
        /** Turns at a steady pace before pedalling counts. */
        const val CONFIRM = 5

        /** 180 rpm at most; slower than 40 rpm is coasting or a stop. */
        const val MIN_GAP_NS = 333_000_000L
        const val MAX_GAP_NS = 1_500_000_000L

        /** How far the signal must swing each way to count. */
        const val ACCEL_THRESHOLD = 0.3 // m/s²
        const val GYRO_THRESHOLD = 0.35 // rad/s

        /** A swing this many times bigger one way than the other is a step. */
        const val LOPSIDED = 3.0

        /**
         * The accelerometer jumping this far (m/s²) between readings is a
         * footstep landing (or a pothole).
         */
        const val JOLT = 3.0
        const val JOLT_WINDOW_NS = 1_500_000_000L

        const val STEP_WINDOW_NS = 4_000_000_000L

        /** How uneven pedalling may be (coefficient of variation). */
        const val MAX_UNEVENNESS = 0.25

        fun steady(gaps: Collection<Long>): Boolean {
            if (gaps.size < CONFIRM - 1) return false
            val mean = gaps.average()
            if (mean <= 0) return false
            val spread = sqrt(gaps.sumOf { (it - mean) * (it - mean) } / gaps.size)
            return spread / mean < MAX_UNEVENNESS
        }

        fun median(gaps: Collection<Long>): Long {
            val sorted = gaps.sorted()
            return if (sorted.isEmpty()) 1_000_000_000L else sorted[sorted.size / 2]
        }
    }
}

/**
 * A 3-axis reading's swing, along the direction it swings most in: each
 * axis's slow average is taken out, the rest smoothed, and projected onto
 * the main axis of the last few seconds' spread (found by power iteration,
 * its sign kept steady so the signal never flips).
 */
class SwingAxis {
    private var started = false
    private val mean = DoubleArray(3)
    private val swing = DoubleArray(3)

    /** The spread (covariance): xx, yy, zz, xy, xz, yz. */
    private val spread = DoubleArray(6)
    private val axis = doubleArrayOf(0.577, 0.577, 0.577)
    private var samples = 0

    /** Adds a reading; returns the swing along the main axis. */
    fun add(x: Double, y: Double, z: Double): Double {
        val v = doubleArrayOf(x, y, z)
        if (!started) {
            v.copyInto(mean)
            started = true
        }
        for (i in 0..2) {
            // The slow average (~1.5 s at 50 Hz); the rest is the swing,
            // smoothed to drop buzz above a few hertz.
            mean[i] += (v[i] - mean[i]) * 0.013
            swing[i] += ((v[i] - mean[i]) - swing[i]) * 0.3
        }
        val (a, b, c) = Triple(swing[0], swing[1], swing[2])
        val products = doubleArrayOf(a * a, b * b, c * c, a * b, a * c, b * c)
        // Weighted to the last ~2 s, so the axis settles quickly.
        for (i in 0..5) spread[i] += (products[i] - spread[i]) * 0.01
        if (++samples % 5 == 0) updateAxis()
        return swing[0] * axis[0] + swing[1] * axis[1] + swing[2] * axis[2]
    }

    private fun updateAxis() {
        var u = axis.copyOf()
        repeat(4) {
            val n = doubleArrayOf(
                spread[0] * u[0] + spread[3] * u[1] + spread[4] * u[2],
                spread[3] * u[0] + spread[1] * u[1] + spread[5] * u[2],
                spread[4] * u[0] + spread[5] * u[1] + spread[2] * u[2],
            )
            val len = sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2])
            if (len < 1e-12) return
            u = doubleArrayOf(n[0] / len, n[1] / len, n[2] / len)
        }
        val same = u[0] * axis[0] + u[1] * axis[1] + u[2] * axis[2]
        for (i in 0..2) axis[i] = if (same < 0) -u[i] else u[i]
    }
}
