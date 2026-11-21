package com.trakvrs.fitns

import kotlin.math.sqrt

/**
 * Keeps vehicle vibration out of the step count. Pure logic, no Android:
 * [StepFilter] feeds it.
 *
 * Android's step counter counts any rhythmic jolt as a step, so riding a
 * motorbike, a bus or a bumpy road adds "steps". Walking and running have a
 * steady rhythm (each step within a few percent of the last); a vehicle's
 * jolts don't, and nobody steps faster than four times a second. So every
 * step-detector event is judged by its rhythm:
 *
 *  * A run of steps only counts once [CONFIRM_STEPS] of them come at a
 *    steady, human pace — then all of them count, the first ones too.
 *  * While it holds, steps keep counting as long as each stays close to the
 *    run's typical pace. A jolt out of rhythm ends the run.
 *  * Jolts that never settle into a steady pace are taken back off.
 *
 * The step *counter* stays the source of truth: [report] passes on its
 * increases, minus the jolts judged not to be steps, and holds back steps
 * still being judged. If detector events go missing (a phone that drops
 * them while asleep), nothing is taken off, so the count is never lower
 * than the counter alone would give — only bike jolts come out.
 */
class StepRhythm(
    /**
     * The filtered total last reported, and the raw counter it came from.
     * Negative = none yet: the first reading passes straight through.
     */
    var reported: Long,
    var lastRaw: Long,
) {
    private var lastStepNs = 0L
    private val gaps = ArrayDeque<Long>()
    private var confirmed = false

    /** Steps in the current run, not yet judged. */
    private var pending = 0

    /** Counter increases held back for [pending] steps. */
    private var held = 0L

    /** Jolts judged not to be steps that the counter may still add. */
    private var toTakeOff = 0L
    private var takenOffAtNs = 0L

    /** Every jolt taken off so far, for tests and logs. */
    var rejected = 0L
        private set

    /** A step-detector event at [ns] (nanoseconds since boot). */
    fun onStep(ns: Long) {
        val gap = if (lastStepNs == 0L) -1L else ns - lastStepNs
        lastStepNs = ns
        if (gap < MIN_GAP_NS || gap > MAX_GAP_NS) {
            // Too fast to be a step, or after a pause: a new run starts here.
            endRun(ns)
            pending = 1
            return
        }
        if (confirmed) {
            val typical = median(gaps)
            if (gap >= typical * 2 / 3 && gap <= typical * 3 / 2) {
                push(gap)
                return
            }
            endRun(ns)
            pending = 1
            return
        }
        pending++
        push(gap)
        if (pending < CONFIRM_STEPS) return
        if (steady(gaps)) {
            // A steady walk: every step of it counts, the first ones too.
            confirmed = true
            reported += held
            held = 0
            pending = 0
        } else {
            // Not steady yet: the oldest jolt can't be part of a walk.
            pending--
            gaps.removeFirst()
            takeOff(1, ns)
        }
    }

    /**
     * The step counter read [raw] at [nowNs]: returns the filtered total,
     * which never goes down except when the counter itself restarted.
     */
    fun report(raw: Long, nowNs: Long): Long {
        if (lastRaw < 0 || reported < 0) {
            lastRaw = raw
            reported = raw
            return reported
        }
        var increase = raw - lastRaw
        if (increase < 0) {
            // The counter restarted (a reboot): so does the filtered total.
            reported = 0
            held = 0
            toTakeOff = 0
            increase = raw
        }
        lastRaw = raw
        val off = minOf(toTakeOff, increase)
        toTakeOff -= off
        increase -= off
        val hold = minOf((pending - held).coerceAtLeast(0), increase)
        held += hold
        increase -= hold
        reported += increase
        // Jolts the counter never counted itself (its own filter caught
        // them) mustn't come off later, real steps.
        if (nowNs - takenOffAtNs > STALE_NS) toTakeOff = 0
        return reported
    }

    private fun endRun(ns: Long) {
        if (!confirmed && pending > 0) takeOff(pending.toLong(), ns)
        confirmed = false
        pending = 0
        gaps.clear()
    }

    private fun takeOff(steps: Long, ns: Long) {
        rejected += steps
        val dropped = minOf(held, steps)
        held -= dropped
        toTakeOff += steps - dropped
        takenOffAtNs = ns
    }

    private fun push(gap: Long) {
        gaps.addLast(gap)
        while (gaps.size > CONFIRM_STEPS) gaps.removeFirst()
    }

    companion object {
        /** Steps at a steady pace before a run counts. */
        const val CONFIRM_STEPS = 10

        /** Faster than 4 a second isn't stepping; slower than one per 2 s is a pause. */
        const val MIN_GAP_NS = 250_000_000L
        const val MAX_GAP_NS = 2_000_000_000L

        /** How uneven a walk's rhythm may be (coefficient of variation). */
        const val MAX_UNEVENNESS = 0.2

        const val STALE_NS = 30_000_000_000L

        fun steady(gaps: Collection<Long>): Boolean {
            if (gaps.size < CONFIRM_STEPS - 1) return false
            val mean = gaps.average()
            if (mean <= 0) return false
            val spread = sqrt(gaps.sumOf { (it - mean) * (it - mean) } / gaps.size)
            return spread / mean < MAX_UNEVENNESS
        }

        fun median(gaps: Collection<Long>): Long {
            val sorted = gaps.sorted()
            return if (sorted.isEmpty()) 500_000_000L else sorted[sorted.size / 2]
        }
    }
}
