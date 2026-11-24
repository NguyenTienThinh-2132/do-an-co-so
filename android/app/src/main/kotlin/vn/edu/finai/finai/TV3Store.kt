package vn.edu.finai.finai

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONObject
import java.util.UUID

data class TV3Reminder(val id: String, val title: String, val at: Long, val token: String, val fired: Boolean, val taskStartAt: Long? = null)

class TV3Store(context: Context) : SQLiteOpenHelper(context.applicationContext, "finai_tv3_native.db", null, 2) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE inbox(id TEXT PRIMARY KEY, source_key TEXT UNIQUE NOT NULL, payload TEXT NOT NULL, kind TEXT NOT NULL, created_at INTEGER NOT NULL)")
        db.execSQL("CREATE TABLE seen(source_key TEXT PRIMARY KEY, created_at INTEGER NOT NULL)")
        db.execSQL("CREATE TABLE reminders(task_id TEXT PRIMARY KEY, title TEXT NOT NULL, trigger_at INTEGER NOT NULL, token TEXT NOT NULL, fired INTEGER NOT NULL DEFAULT 0, task_start_at INTEGER)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { if (oldVersion < 2) db.execSQL("ALTER TABLE reminders ADD COLUMN task_start_at INTEGER") }

    fun append(source: String, kind: String, data: Map<String, Any?>): Map<String, Any?>? {
        val db = writableDatabase
        val id = UUID.randomUUID().toString()
        val at = System.currentTimeMillis()
        val event = mapOf("id" to id, "kind" to kind, "receivedAt" to at, "data" to data)
        db.beginTransaction()
        try {
            val seen = ContentValues().apply { put("source_key", source); put("created_at", at) }
            if (db.insertWithOnConflict("seen", null, seen, SQLiteDatabase.CONFLICT_IGNORE) == -1L) return null
            val values = ContentValues().apply {
                put("id", id); put("source_key", source); put("kind", kind)
                put("payload", JSONObject(event).toString()); put("created_at", at)
            }
            db.insertWithOnConflict("inbox", null, values, SQLiteDatabase.CONFLICT_IGNORE)
            // Giữ tombstone 90 ngày, không tự xóa sự kiện chưa acknowledge.
            db.delete("seen", "created_at < ?", arrayOf((at - 90L * 86400000L).toString()))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        return event
    }
    fun pending(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.rawQuery("SELECT payload FROM inbox ORDER BY (kind = 'taskOpen') DESC, created_at, id LIMIT 200", null).use {
            while (it.moveToNext()) result.add(decode(JSONObject(it.getString(0))))
        }
        return result
    }
    private fun decode(json: JSONObject): Map<String, Any?> =
        json.keys().asSequence().associateWith { key ->
            when (val value = json.get(key)) {
                is JSONObject -> decode(value)
                JSONObject.NULL -> null
                else -> value
            }
        }
    fun acknowledge(ids: List<String>) {
        require(ids.size <= 200 && ids.all { it.length in 1..128 })
        if (ids.isEmpty()) return
        writableDatabase.delete("inbox", "id IN (" + ids.joinToString(",") { "?" } + ")", ids.toTypedArray())
    }
    fun putReminder(id: String, title: String, at: Long, taskStartAt: Long?): TV3Reminder {
        val row = TV3Reminder(id, title, at, UUID.randomUUID().toString(), false, taskStartAt)
        saveReminder(row)
        return row
    }
    fun saveReminder(row: TV3Reminder) {
        writableDatabase.insertWithOnConflict("reminders", null, ContentValues().apply {
            put("task_id", row.id); put("title", row.title); put("trigger_at", row.at)
            put("token", row.token); put("fired", if (row.fired) 1 else 0); put("task_start_at", row.taskStartAt)
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }    fun reminders(): List<TV3Reminder> {
        val rows = mutableListOf<TV3Reminder>()
        readableDatabase.rawQuery("SELECT task_id,title,trigger_at,token,fired,task_start_at FROM reminders", null).use {
            while (it.moveToNext()) rows.add(TV3Reminder(it.getString(0), it.getString(1), it.getLong(2), it.getString(3), it.getInt(4) != 0, if (it.isNull(5)) null else it.getLong(5)))
        }
        return rows
    }
    fun reminder(id: String) = reminders().firstOrNull { it.id == id }
    fun removeReminder(id: String) { writableDatabase.delete("reminders", "task_id = ?", arrayOf(id)) }
    fun markFired(row: TV3Reminder): Boolean = writableDatabase.update("reminders",
        ContentValues().apply { put("fired", 1) }, "task_id = ? AND token = ? AND fired = 0",
        arrayOf(row.id, row.token)) == 1
    fun retryLater(row: TV3Reminder) { writableDatabase.update("reminders",
        ContentValues().apply { put("fired", 0) }, "task_id = ? AND token = ?", arrayOf(row.id, row.token)) }
}

object TV3Events {
    var sink: io.flutter.plugin.common.EventChannel.EventSink? = null
    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    fun append(context: Context, source: String, kind: String, data: Map<String, Any?>) {
        TV3Store(context).use { store ->
            val event = store.append(source, kind, data) ?: return
            main.post { sink?.success(event) }
        }
    }
}