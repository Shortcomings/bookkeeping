package com.bookkeeping.bookkeeping

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class BookkeepingNotificationListener : NotificationListenerService() {

    companion object {
        const val WECHAT_PACKAGE = "com.tencent.mm"
        const val ALIPAY_PACKAGE = "com.eg.android.AlipayGphone"
        private const val PENDING_FILE = "pending_auto_tx.json"
        private const val MAX_PENDING = 50
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName
        if (packageName != WECHAT_PACKAGE && packageName != ALIPAY_PACKAGE) return

        val extras = sbn.notification.extras
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val content = extras.getString(Notification.EXTRA_TEXT) ?: ""
        if (title.isBlank() && content.isBlank()) return

        val fullText = "$title $content"
        val sourceApp = if (packageName == WECHAT_PACKAGE) "微信" else "支付宝"

        val parsed = parseNotification(fullText, sourceApp)
        if (parsed != null && parsed.amountCents > 0) {
            if (!isDuplicate(parsed)) {
                savePendingTransaction(parsed, fullText)
                notifyFlutter()
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Not needed
    }

    data class ParsedTx(
        val merchantName: String,
        val amountCents: Int,
        val type: Int,
        val sourceApp: String
    )

    private fun parseNotification(fullText: String, sourceApp: String): ParsedTx? {
        // Extract amounts: (\d+\.?\d{0,2})\s*元
        val amountRegex = Regex("""(\d+\.?\d{0,2})\s*元""")
        val amountMatches = amountRegex.findAll(fullText).toList()
        if (amountMatches.isEmpty()) {
            // Also try ¥(\d+\.?\d{0,2})
            val altRegex = Regex("""[¥￥]\s*(\d+\.?\d{0,2})""")
            val altMatches = altRegex.findAll(fullText).toList()
            if (altMatches.isEmpty()) return null
            val amount = altMatches.maxOfOrNull {
                it.groupValues[1].toDoubleOrNull() ?: 0.0
            } ?: return null
            if (amount <= 0) return null
            val amountCents = (amount * 100).toInt()

            val isIncome = fullText.contains("收款") || fullText.contains("到账") ||
                    fullText.contains("入账") || fullText.contains("转入") ||
                    fullText.contains("退款") || fullText.contains("返现") ||
                    fullText.contains("红包")
            val type = if (isIncome) 1 else 0

            val merchantName = cleanMerchantName(fullText, amountRegex, sourceApp)
            return ParsedTx(merchantName, amountCents, type, sourceApp)
        }

        // Use the largest amount (sometimes there are multiple)
        val maxAmount = amountMatches.maxOfOrNull {
            it.groupValues[1].toDoubleOrNull() ?: 0.0
        } ?: return null
        if (maxAmount <= 0) return null
        val amountCents = (maxAmount * 100).toInt()

        // Determine type
        val isExpense = fullText.contains("支付") || fullText.contains("消费") ||
                fullText.contains("付款") || fullText.contains("扣款")
        val isIncome = fullText.contains("收款") || fullText.contains("到账") ||
                fullText.contains("入账") || fullText.contains("转入") ||
                fullText.contains("退款") || fullText.contains("返现") ||
                fullText.contains("红包")
        val type = if (isIncome && !isExpense) 1 else 0

        val merchantName = cleanMerchantName(fullText, amountRegex, sourceApp)
        return ParsedTx(merchantName, amountCents, type, sourceApp)
    }

    private fun cleanMerchantName(fullText: String, amountRegex: Regex, sourceApp: String): String {
        var cleaned = fullText.replace(amountRegex, "")
            .replace(Regex("""(支付成功|付款成功|收款成功|消费|交易|通知|提醒|账单|明细|￥|¥|\$|微信支付|支付宝)"""), "")
            .replace(Regex("""\s+"""), " ")
            .trim()

        // Truncate
        if (cleaned.length > 30) cleaned = cleaned.substring(0, 30)
        if (cleaned.isBlank()) cleaned = "未知商户"
        return cleaned
    }

    private fun isDuplicate(parsed: ParsedTx): Boolean {
        val file = File(filesDir, PENDING_FILE)
        if (!file.exists()) return false

        return try {
            val json = JSONObject(file.readText())
            val arr = json.optJSONArray("transactions") ?: return false
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

            for (i in 0 until arr.length()) {
                val existing = arr.getJSONObject(i)
                if (existing.optString("sourceApp") == parsed.sourceApp &&
                    existing.optInt("amountCents") == parsed.amountCents &&
                    existing.optString("merchantName") == parsed.merchantName &&
                    existing.optString("date") == today
                ) {
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    @Synchronized
    private fun savePendingTransaction(parsed: ParsedTx, rawContent: String) {
        try {
            val file = File(filesDir, PENDING_FILE)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

            val txJson = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("merchantName", parsed.merchantName)
                put("amountCents", parsed.amountCents)
                put("type", parsed.type)
                put("date", today)
                put("sourceApp", parsed.sourceApp)
                put("rawContent", rawContent.take(200))
            }

            val root = if (file.exists()) {
                JSONObject(file.readText())
            } else {
                JSONObject().apply { put("transactions", JSONArray()) }
            }

            val arr = root.getJSONArray("transactions")
            arr.put(txJson)

            // Enforce max limit, keep newest
            while (arr.length() > MAX_PENDING) {
                arr.remove(0)
            }

            file.writeText(root.toString())
        } catch (_: Exception) {
            // Silently fail — don't crash the notification listener
        }
    }

    private fun notifyFlutter() {
        try {
            MainActivity.eventSink?.success("pending_updated")
        } catch (_: Exception) {}
    }
}
