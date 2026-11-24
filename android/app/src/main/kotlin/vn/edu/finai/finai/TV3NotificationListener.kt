package vn.edu.finai.finai

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.security.MessageDigest

class TV3NotificationListener : NotificationListenerService() {
    private val bankGate by lazy { TV3BankGate(applicationContext) }
    override fun onListenerConnected() {
        try { activeNotifications?.forEach { onNotificationPosted(it) } } catch (_: Exception) {}
    }
    override fun onListenerDisconnected() {
        requestRebind(android.content.ComponentName(this, TV3NotificationListener::class.java))
    }
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try { receive(sbn) } catch (_: Exception) {
            // Không log payload, OTP, tài khoản hoặc thông tin cá nhân.
        }
    }
    private fun receive(sbn: StatusBarNotification) {
        val own = sbn.packageName == packageName
        // Chỉ lấy app label từ PackageManager, không lấy từ title/extras của thông báo.
        val appLabel = if (own) "FinAI" else {
            val info = packageManager.getApplicationInfo(sbn.packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        }
        val bank = if (own) null else (bankGate.match(appLabel) ?: return)
        val preferences = getSharedPreferences("tv3_native", MODE_PRIVATE)
        if (!own && preferences.contains("allowed_packages") &&
            preferences.getStringSet("allowed_packages", emptySet())?.contains(sbn.packageName) != true) return
        // Chưa đụng tới nội dung nếu app không thuộc danh mục.
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.joinToString("\n"))?.toString() ?: ""
        // Loại OTP trước khi ghi SQLite hoặc phát sang Flutter, kể cả OTP ngoài đoạn cắt.
        if (!own && TV3BankGate.shouldIgnore(title, text)) return
        val fingerprint = MessageDigest.getInstance("SHA-256")
            .digest((sbn.packageName + ":" + sbn.key + ":" + sbn.postTime).toByteArray())
            .joinToString("") { "%02x".format(it) }
        TV3Events.append(this, fingerprint, if (own) "notification" else "bankNotification", mapOf(
            "packageName" to sbn.packageName, "appLabel" to appLabel,
            "bankId" to bank?.id, "bankName" to bank?.name,
            "identityVerification" to if (own) "ownApp" else "labelOnly",
            "title" to title.take(500), "text" to text.take(2000),
            "truncated" to (title.length > 500 || text.length > 2000),
            "postedAt" to sbn.postTime, "sourceKey" to fingerprint))
    }
}
