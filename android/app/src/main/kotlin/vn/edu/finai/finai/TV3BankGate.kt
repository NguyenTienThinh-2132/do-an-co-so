package vn.edu.finai.finai

import android.content.Context
import org.json.JSONArray
import java.util.Locale

data class TV3BankName(val id: String, val name: String)

/** Tên chỉ nhận diện ứng viên. Không khẳng định app chính chủ theo package/chữ ký. */
class TV3BankGate(context: Context) {
    private val names: Map<String, List<TV3BankName>> by lazy {
        val rows = JSONArray(context.assets.open("finai_bank_catalog.json").bufferedReader().use { it.readText() })
        val all = mutableMapOf<String, MutableList<TV3BankName>>()
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i)
            val bank = TV3BankName(row.getString("id"), row.getString("name"))
            val aliases = row.getJSONArray("aliases")
            val labels = mutableListOf(bank.name)
            for (j in 0 until aliases.length()) labels.add(aliases.getString(j))
            labels.forEach { all.getOrPut(normalize(it)) { mutableListOf() }.add(bank) }
        }
        all
    }
    fun match(label: String): TV3BankName? {
        if (label.length > 200) return null
        val key = normalize(label)
        if (key.isEmpty()) return null
        return names[key]?.distinctBy { it.id }?.singleOrNull()
    }
    companion object {
        private fun normalize(value: String) = value.lowercase(Locale.ROOT)
            .replace(Regex("[\\s\\u00a0._\\-–—]+"), "")
        private val otp = Regex("\\botp\\b|\\bone[ -]time\\b|mã xác (thực|nhận)|ma xac (thuc|nhan)|verification code|authentication code", RegexOption.IGNORE_CASE)
        private val ads = Regex("ưu đãi|uu dai|khuyến mãi|khuyen mai|hoàn tiền|hoan tien|cashback|voucher|lãi suất|lai suat|mở thẻ|mo the", RegexOption.IGNORE_CASE)
        fun shouldIgnore(title: String, text: String): Boolean {
            val content = "$title\n$text"
            return otp.containsMatchIn(content) || ads.containsMatchIn(content)
        }
    }
}
