package vn.edu.finai.finai

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

class TV3Reminders(private val context: Context) {
    private val alarm = context.getSystemService(AlarmManager::class.java)
    private val notifications = context.getSystemService(NotificationManager::class.java)
    fun canNotify(): Boolean =
        (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            notifications.areNotificationsEnabled()
    fun canScheduleExact(): Boolean = Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()
    private fun pending(id: String, token: String): PendingIntent {
        val intent = Intent(context, TV3ReminderReceiver::class.java)
            .setData(Uri.Builder().scheme("finai-task").authority("alarm").appendPath(id).build())
            .putExtra("taskId", id).putExtra("token", token)
        return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun schedule(id: String, title: String, at: Long, taskStartAt: Long?) {
        require(id.length in 1..128 && title.trim().isNotEmpty() && title.length <= 2000 && at > System.currentTimeMillis())
        check(canNotify()) { "notification_permission" }
        check(canScheduleExact()) { "exact_alarm_permission" }
        TV3Store(context).use { store ->
            val previous = store.reminder(id)
            val row = store.putReminder(id, title, at, taskStartAt)
            try { set(row); notifications.cancel(id, 1) } catch (e: Exception) {
                if (previous == null) store.removeReminder(id) else {
                    store.saveReminder(previous)
                    if (!previous.fired) try { set(previous) } catch (_: Exception) {}
                }
                throw e
            }
        }
    }
    private fun set(row: TV3Reminder) {
        val trigger = maxOf(row.at, System.currentTimeMillis() + 1000)
        if (Build.VERSION.SDK_INT >= 23) {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pending(row.id, row.token))
        } else {
            alarm.setExact(AlarmManager.RTC_WAKEUP, trigger, pending(row.id, row.token))
        }
    }
    fun cancel(id: String) {
        alarm.cancel(pending(id, ""))
        notifications.cancel(id, 1)
        TV3Store(context).use { it.removeReminder(id) }
    }
    fun restore() {
        if (!canScheduleExact() || !canNotify()) return
        TV3Store(context).use { store ->
            store.reminders().filter { !it.fired && it.at > System.currentTimeMillis() - 86400000L }
                .forEach { try { set(it) } catch (_: Exception) {} }
        }
    }
    fun fire(id: String, token: String) {
        if (!canNotify()) return
        TV3Store(context).use { store ->
            val row = store.reminder(id) ?: return
            if (row.token != token || row.fired) return
            if (Build.VERSION.SDK_INT >= 26) {
                notifications.createNotificationChannel(NotificationChannel("finai_tasks", "Nhắc công việc", NotificationManager.IMPORTANCE_HIGH))
            }
            val open = Intent(context, MainActivity::class.java)
                .setAction("finai.tv3.OPEN_TASK")
                .setData(Uri.Builder().scheme("finai-task").authority("open").appendPath(id).build())
                .putExtra("taskId", id).putExtra("token", token)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val tap = PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, "finai_tasks") else Notification.Builder(context)
            val notice = builder.setSmallIcon(android.R.drawable.ic_menu_today)
                .setContentTitle(row.title).setContentText("Nhấn để xem công việc.")
                .setContentIntent(tap).setAutoCancel(true)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setCategory(Notification.CATEGORY_REMINDER).build()
            if (store.markFired(row)) {
                try { notifications.notify(id, 1, notice) }
                catch (_: SecurityException) { store.retryLater(row) }
            }
        }
    }
}

class TV3ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("taskId") ?: return
        val token = intent.getStringExtra("token") ?: return
        TV3Reminders(context).fire(id, token)
    }
}
class TV3RestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { TV3Reminders(context).restore() }
}