package vn.edu.finai.finai

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finai/tv3/native")
            .setMethodCallHandler { call, result ->
                try {
                    val reminders = TV3Reminders(this)
                    when (call.method) {
                        "isAccessGranted" -> result.success(listenerAccess())
                        "openAccessSettings" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                        "canNotify" -> result.success(reminders.canNotify())
                        "canScheduleExact" -> result.success(reminders.canScheduleExact())
                        "openExactAlarmSettings" -> {
                            if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                            result.success(null)
                        }
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                                result.success(reminders.canNotify())
                            } else if (permissionResult != null) {
                                result.error("busy", "Đang chờ cấp quyền.", null)
                            } else {
                                permissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4301)
                            }
                        }
                        "getPending" -> TV3Store(this).use { result.success(it.pending()) }
                        "acknowledge" -> TV3Store(this).use {
                            val ids = call.argument<List<String>>("ids") ?: emptyList()
                            it.acknowledge(ids); result.success(null)
                        }
                        "setAllowedPackages" -> {
                            val packages = call.argument<List<String>>("packages") ?: emptyList()
                            require(packages.size <= 50 && packages.all { it.length in 1..200 })
                            getSharedPreferences("tv3_native", MODE_PRIVATE).edit()
                                .putStringSet("allowed_packages", (packages + packageName).toSet()).commit()
                            result.success(null)
                        }
                        "scheduleTaskReminder" -> {
                            reminders.schedule(call.argument<String>("taskId")!!, call.argument<String>("title")!!,
                                call.argument<Number>("triggerAt")!!.toLong(), call.argument<Number>("taskStartAt")?.toLong())
                            result.success(null)
                        }
                        "cancelTaskReminder" -> { reminders.cancel(call.argument<String>("taskId")!!); result.success(null) }
                        "getTaskReminder" -> TV3Store(this).use { store ->
                            val row = store.reminder(call.argument<String>("taskId")!!)
                            result.success(row?.let { mapOf("taskId" to it.id, "title" to it.title, "triggerAt" to it.at, "fired" to it.fired, "taskStartAt" to it.taskStartAt) })
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: IllegalArgumentException) {
                    result.error("validation", "Dữ liệu Native không hợp lệ.", null)
                } catch (e: IllegalStateException) {
                    result.error("permissionDenied", "Cần cấp quyền thông báo và nhắc chính xác.", null)
                } catch (_: SecurityException) {
                    result.error("permissionDenied", "Chưa có quyền cần thiết.", null)
                } catch (_: Exception) {
                    result.error("unavailable", "Chưa thực hiện được thao tác Native.", null)
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "finai/tv3/incoming")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    TV3Events.sink = sink
                    TV3Store(this@MainActivity).use { it.pending().forEach { event -> sink.success(event) } }
                }
                override fun onCancel(arguments: Any?) { TV3Events.sink = null }
            })
        captureTap(intent)
    }
    private fun listenerAccess(): Boolean {
        val component = ComponentName(this, TV3NotificationListener::class.java)
        if (Build.VERSION.SDK_INT >= 27) return getSystemService(NotificationManager::class.java).isNotificationListenerAccessGranted(component)
        return Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?.split(":")?.any { ComponentName.unflattenFromString(it) == component } == true
    }
    private fun captureTap(intent: Intent?) {
        if (intent?.action != "finai.tv3.OPEN_TASK") return
        val id = intent.getStringExtra("taskId") ?: return
        val token = intent.getStringExtra("token") ?: return
        if (id.length !in 1..128 || token.length !in 1..128) return
        val valid = TV3Store(this).use { it.reminder(id)?.let { row -> row.token == token && row.fired } == true }
        if (!valid) return
        TV3Events.append(this, "tap:$token", "taskOpen", mapOf("taskId" to id))
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); captureTap(intent) }
    override fun onResume() { super.onResume(); TV3Reminders(this).restore() }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4301) {
            permissionResult?.success(TV3Reminders(this).canNotify())
            permissionResult = null
        }
    }
    override fun onDestroy() {
        permissionResult?.error("unavailable", "Activity đã đóng.", null)
        permissionResult = null
        TV3Events.sink = null
        super.onDestroy()
    }
}