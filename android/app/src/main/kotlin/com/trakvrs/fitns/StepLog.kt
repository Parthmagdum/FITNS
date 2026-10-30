package com.trakvrs.fitns

import android.content.Context
import java.io.File

/**
 * Step-counter readings the background service took, waiting for Dart to
 * book them. One line per reading: `counter,readAtMillis,bootMillis`.
 *
 * Dart drains this on every launch and resume and replays each line through
 * the same `recordStepCounter` the live stream uses, so the counting rules
 * (reboots, day boundaries, stale readings) exist in Dart only.
 */
object StepLog {
    private const val FILE = "step_log.csv"
    private const val PREFS = "fitns_steps"
    private const val KEY_ALL_DAY = "all_day"

    @Synchronized
    fun append(context: Context, counter: Long, readAtMillis: Long, bootMillis: Long) {
        File(context.filesDir, FILE).appendText("$counter,$readAtMillis,$bootMillis\n")
    }

    /** Every reading since the last drain, oldest first; empties the log. */
    @Synchronized
    fun drain(context: Context): List<List<Long>> {
        val file = File(context.filesDir, FILE)
        if (!file.exists()) return emptyList()
        val lines = file.readLines()
        file.delete()
        return lines.mapNotNull { line ->
            val parts = line.split(',').mapNotNull { it.trim().toLongOrNull() }
            if (parts.size == 3) parts else null
        }
    }

    /**
     * Mirrors the Dart setting, because the boot receiver has to decide
     * whether to restart the service before any Dart code can run.
     */
    fun isAllDay(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ALL_DAY, false)

    fun setAllDay(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ALL_DAY, on).apply()
    }
}
