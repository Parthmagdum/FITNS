package com.trakvrs.fitns

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * A reboot kills the step service and zeroes the counter. Restarting it here
 * (boot is one of the few moments Android lets an app start a foreground
 * service from the background) means the steps of a day with a reboot in it
 * aren't lost until the next time FITNS is opened.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (StepLog.isAllDay(context)) StepCounterService.start(context)
    }
}
