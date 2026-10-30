package com.trakvrs.fitns

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the sensor bridges. No plugins: a step counter, an accelerometer and
 * a proximity sensor are a few hundred lines here, where a plugin would bring
 * Google Play Services or a dependency F-Droid has to vet.
 *
 * Channel names must match `lib/core/steps/step_sensor.dart` and
 * `lib/core/motion/motion_sensors.dart` byte for byte — no test can cover
 * the pairing.
 */
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    /** Backup file being saved: the Dart call to answer, and what to write. */
    private var pendingSave: Pair<MethodChannel.Result, String>? = null
    private var pendingOpen: MethodChannel.Result? = null
    private var pendingNotifications: MethodChannel.Result? = null

    override fun onResume() {
        super.onResume()
        inForeground = true
        RestAlert.hide(this)
    }

    override fun onPause() {
        inForeground = false
        RestAlert.showCountdown(this)
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val sensors = getSystemService(SENSOR_SERVICE) as SensorManager

        MethodChannel(messenger, STEP_METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status(sensors))
                "requestPermission" -> requestPermission(sensors, result)
                // Once the user has said "don't ask again", only the app's
                // system settings page can grant it.
                "openSettings" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ),
                    )
                    result.success(null)
                }
                "setBackgroundCounting" -> {
                    val on = call.arguments as? Boolean ?: false
                    StepLog.setAllDay(this, on)
                    if (on) StepCounterService.start(this) else StepCounterService.stop(this)
                    result.success(null)
                }
                "drainLog" -> result.success(StepLog.drain(this))
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, STEP_EVENTS).setStreamHandler(StepCounterStream(sensors))

        MethodChannel(messenger, MOTION_METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(
                    mapOf(
                        "accelerometer" to (sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                        "proximity" to (sensors.getDefaultSensor(Sensor.TYPE_PROXIMITY) != null),
                    ),
                )
                // While counting reps the phone sits in a pocket or on the
                // floor; a screen timeout would stop the sensors with it.
                "keepScreenOn" -> {
                    if (call.arguments as? Boolean == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // Backups go through Android's own save / open pickers: the user
        // chooses where (Downloads, Drive, a USB stick) and no storage
        // permission is needed at all.
        MethodChannel(messenger, FILE_METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveText" -> {
                    pendingSave?.first?.success(false)
                    pendingSave = result to (call.argument<String>("content") ?: "")
                    startActivityForResult(
                        Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mime") ?: "application/json"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        },
                        SAVE_REQUEST,
                    )
                }
                "openText" -> {
                    pendingOpen?.success(null)
                    pendingOpen = result
                    startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            // Some file managers label .json as plain text or
                            // as unknown binary; accept all three.
                            type = "*/*"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/json", "text/plain", "application/octet-stream"),
                            )
                        },
                        OPEN_REQUEST,
                    )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, REST_METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    RestAlert.schedule(this, (call.arguments as Number).toLong())
                    result.success(null)
                }
                "cancel" -> {
                    RestAlert.cancel(this)
                    result.success(null)
                }
                "status" -> result.success(
                    mapOf(
                        "notifications" to notificationsAllowed(),
                        "onTime" to RestAlert.canAlertOnTime(this),
                    ),
                )
                "requestNotifications" -> {
                    if (notificationsAllowed()) {
                        result.success(true)
                    } else {
                        pendingNotifications?.success(false)
                        pendingNotifications = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFY_REQUEST)
                    }
                }
                "openAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.fromParts("package", packageName, null),
                            ),
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 100 Hz: a landing impact lasts only a few tens of milliseconds.
        EventChannel(messenger, ACCELEROMETER_EVENTS)
            .setStreamHandler(MotionStream(sensors, Sensor.TYPE_ACCELEROMETER, 10_000))
        EventChannel(messenger, PROXIMITY_EVENTS)
            .setStreamHandler(MotionStream(sensors, Sensor.TYPE_PROXIMITY, SensorManager.SENSOR_DELAY_GAME))
    }

    /** Notifications only became a runtime permission in Android 13. */
    private fun notificationsAllowed(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    /** `unavailable` (no sensor), `denied` or `granted`. */
    private fun status(sensors: SensorManager): String = when {
        sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) == null -> "unavailable"
        StepCounterService.canCount(this) -> "granted"
        else -> "denied"
    }

    private fun requestPermission(sensors: SensorManager, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || StepCounterService.canCount(this)) {
            result.success(status(sensors))
            return
        }
        // A second request while the dialog is up would orphan the first.
        pendingPermission?.success(status(sensors))
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFY_REQUEST) {
            pendingNotifications?.success(notificationsAllowed())
            pendingNotifications = null
            return
        }
        if (requestCode != PERMISSION_REQUEST) return
        val sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        pendingPermission?.success(status(sensors))
        pendingPermission = null
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val uri = if (resultCode == RESULT_OK) data?.data else null
        when (requestCode) {
            SAVE_REQUEST -> {
                val (result, content) = pendingSave ?: return
                pendingSave = null
                if (uri == null) return result.success(false)
                // Off the main thread: a backup can be a few megabytes.
                Thread {
                    try {
                        // "wt" truncates an existing file; some providers
                        // (cloud drives) only understand plain "w".
                        val stream = try {
                            contentResolver.openOutputStream(uri, "wt")
                        } catch (e: IllegalArgumentException) {
                            contentResolver.openOutputStream(uri, "w")
                        }
                        stream!!.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                        runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("write_failed", e.message, null) }
                    }
                }.start()
            }
            OPEN_REQUEST -> {
                val result = pendingOpen ?: return
                pendingOpen = null
                if (uri == null) return result.success(null)
                Thread {
                    try {
                        val text = contentResolver.openInputStream(uri)!!
                            .use { it.readBytes().toString(Charsets.UTF_8) }
                        runOnUiThread { result.success(text) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("read_failed", e.message, null) }
                    }
                }.start()
            }
        }
    }

    companion object {
        /** Whether FITNS is on screen — the rest alert stays quiet if so. */
        @Volatile
        var inForeground = false

        private const val STEP_METHODS = "fitns/steps"
        private const val STEP_EVENTS = "fitns/steps/events"
        private const val MOTION_METHODS = "fitns/motion"
        private const val ACCELEROMETER_EVENTS = "fitns/motion/accelerometer"
        private const val PROXIMITY_EVENTS = "fitns/motion/proximity"
        private const val FILE_METHODS = "fitns/files"
        private const val REST_METHODS = "fitns/rest"
        private const val PERMISSION_REQUEST = 4101
        private const val SAVE_REQUEST = 4105
        private const val OPEN_REQUEST = 4106
        private const val NOTIFY_REQUEST = 4107
    }
}
