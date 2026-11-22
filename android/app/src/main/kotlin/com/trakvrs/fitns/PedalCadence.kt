package com.trakvrs.fitns

import kotlin.math.sqrt

/**
 * Counts pedal turns from the accelerometer. Pure logic, no Android:
 * [RideService] feeds it.
 *
 * With the phone in a trouser pocket, each turn of the pedals lifts and
 * drops the thigh once, so the acceleration (gravity taken out) swings up
 * and down once per turn. A swing is counted when the signal goes clearly
 * below zero and then clearly above it (hysteresis, so road buzz doesn't
 * count), and then judged by its rhythm, like [StepRhythm] judges steps:
 *
 *  * Turns only count once [CONFIRM] of them come at a steady pace between
 *    [MIN_GAP_NS] and [MAX_GAP_NS] apart (40–180 rpm) — then all of them
 *    count, the first ones too.
 *  * While pedalling holds, each turn keeps counting as long as it stays
 *    close to the typical pace. A pause or a jolt out of rhythm ends it,
 *    and turns that never settled into a rhythm don't count.
 *  * Hard or lopsided swings ([MAX_SWING], [LOPSIDED]) are footsteps or
 *    bumps, not pedalling, and walking (the step detector firing,
 *    [onStep]) stops counting too.
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
    private var gravity = Double.NaN
    private var smooth = 0.0
    private var armed = false
    private var swingUp = 0.0
    private var swingDown = 0.0

    private var joltSeen = false

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

    /** One accelerometer reading (m/s²) at [ns] nanoseconds since boot. */
    fun onSample(ns: Long, x: Float, y: Float, z: Float) {
        val m = sqrt((x * x + y * y + z * z).toDouble())
        if (gravity.isNaN()) gravity = m
        // Gravity: a slow average (~1.5 s at 50 Hz); the rest is motion,
        // smoothed to drop buzz above a few hertz.
        gravity += (m - gravity) * 0.013
        smooth += ((m - gravity) - smooth) * 0.3
        if (smooth > swingUp) swingUp = smooth
        if (-smooth > swingDown) swingDown = -smooth
        if (smooth < -THRESHOLD) {
            if (!armed) {
                // A swing has ended: judge its shape. Pedalling rises and
                // falls evenly; a footstep is a sharp jolt up and a long
                // shallow dip.
                val jolt = swingUp > MAX_SWING || swingUp > LOPSIDED * swingDown
                swingUp = 0.0
                swingDown = -smooth
                if (jolt) joltSeen = true
            }
            armed = true
        } else if (armed && smooth > THRESHOLD) {
            armed = false
            if (joltSeen) {
                joltSeen = false
                endRun()
            } else {
                onTurn(ns)
            }
        }
    }

    /** A step-detector event: walking, so whatever is pending isn't pedalling. */
    fun onStep(ns: Long) {
        recentSteps = if (ns - lastStepNs < STEP_WINDOW_NS) recentSteps + 1 else 1
        lastStepNs = ns
        if (recentSteps >= 3) endRun()
    }

    private fun walking(ns: Long) = recentSteps >= 3 && ns - lastStepNs < STEP_WINDOW_NS

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
        const val CONFIRM = 6

        /** 180 rpm at most; slower than 40 rpm is coasting or a stop. */
        const val MIN_GAP_NS = 333_000_000L
        const val MAX_GAP_NS = 1_500_000_000L

        /** How far (m/s²) the motion must swing each way to count. */
        const val THRESHOLD = 0.35

        /** A swing harder than this is a footstep or a bump. */
        const val MAX_SWING = 7.0

        /** A swing this many times higher than its dip is a footstep. */
        const val LOPSIDED = 3.0

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
