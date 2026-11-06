package com.trakvrs.fitns

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.Period
import java.time.ZoneId

/**
 * Health Connect: steps and weight in from other apps and devices, finished
 * workouts out. Only loaded on Android 8+ (MainActivity checks first) —
 * Health Connect doesn't exist below that.
 *
 * Nothing happens until the user taps Connect in Settings and grants the
 * permissions on Android's own screen.
 */
class HealthBridge(private val activity: Activity) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingPermissions: MethodChannel.Result? = null

    private val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
    )

    private val contract = PermissionController.createRequestPermissionResultContract()

    private fun status(): String = when (HealthConnectClient.getSdkStatus(activity)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "needsUpdate"
        else -> "unavailable"
    }

    private fun client() = HealthConnectClient.getOrCreate(activity)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "status") return result.success(status())
        if (status() != "available") return result.success(null)
        scope.launch {
            try {
                when (call.method) {
                    "hasPermissions" -> result.success(
                        client().permissionController.getGrantedPermissions().containsAll(permissions),
                    )
                    "requestPermissions" -> {
                        pendingPermissions?.success(false)
                        pendingPermissions = result
                        activity.startActivityForResult(
                            contract.createIntent(activity, permissions),
                            REQUEST,
                        )
                    }
                    "readSteps" -> result.success(readSteps(call.argument<Number>("days")!!.toInt()))
                    "readWeights" -> result.success(readWeights(call.argument<Number>("since")!!.toLong()))
                    "writeWorkouts" -> {
                        writeWorkouts(call.argument<List<Map<String, Any>>>("workouts")!!)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("health_failed", e.message, null)
            }
        }
    }

    /** True when the result belonged to the permission screen. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pendingPermissions ?: return true
        pendingPermissions = null
        val granted = contract.parseResult(resultCode, data)
        result.success(granted.containsAll(permissions))
        return true
    }

    /** Steps per local day for the last [days] days, by `yyyy-MM-dd`. */
    private suspend fun readSteps(days: Int): Map<String, Long> {
        val today = LocalDate.now()
        val rows = client().aggregateGroupByPeriod(
            AggregateGroupByPeriodRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(
                    today.minusDays(days.toLong() - 1).atStartOfDay(),
                    LocalDateTime.now(),
                ),
                timeRangeSlicer = Period.ofDays(1),
            ),
        )
        return rows.associate { row ->
            row.startTime.toLocalDate().toString() to (row.result[StepsRecord.COUNT_TOTAL] ?: 0L)
        }
    }

    /** Weigh-ins since [sinceMillis]: `at` (ms) and `grams`. */
    private suspend fun readWeights(sinceMillis: Long): List<Map<String, Long>> {
        val response = client().readRecords(
            ReadRecordsRequest(
                recordType = WeightRecord::class,
                timeRangeFilter = TimeRangeFilter.after(Instant.ofEpochMilli(sinceMillis)),
            ),
        )
        // Skip what FITNS wrote itself — it already has those.
        return response.records
            .filter { it.metadata.dataOrigin.packageName != activity.packageName }
            .map {
                mapOf(
                    "at" to it.time.toEpochMilli(),
                    "grams" to Math.round(it.weight.inGrams),
                )
            }
    }

    /**
     * Finished workouts as exercise sessions. Each carries a client id from
     * FITNS's workout id, so writing it again updates rather than doubles.
     */
    private suspend fun writeWorkouts(workouts: List<Map<String, Any>>) {
        val zone = ZoneId.systemDefault()
        val records = workouts.map { w ->
            val start = Instant.ofEpochMilli((w["start"] as Number).toLong())
            val end = Instant.ofEpochMilli((w["end"] as Number).toLong())
            ExerciseSessionRecord(
                startTime = start,
                startZoneOffset = zone.rules.getOffset(start),
                endTime = end,
                endZoneOffset = zone.rules.getOffset(end),
                exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING,
                title = w["title"] as? String,
                metadata = Metadata.manualEntry(
                    clientRecordId = "fitns-workout-${(w["id"] as Number).toLong()}",
                    clientRecordVersion = (w["end"] as Number).toLong(),
                ),
            )
        }
        if (records.isNotEmpty()) client().insertRecords(records)
    }

    companion object {
        private const val REQUEST = 4110
    }
}
