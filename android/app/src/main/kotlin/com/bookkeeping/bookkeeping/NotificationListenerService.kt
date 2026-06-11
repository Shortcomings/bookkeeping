package com.bookkeeping.bookkeeping

import android.app.Notification
import android.content.pm.ApplicationInfo
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class BookkeepingNotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "AutoBookkeeping"
        const val WECHAT_PACKAGE = "com.tencent.mm"
        const val ALIPAY_PACKAGE = "com.eg.android.AlipayGphone"
        private const val PENDING_FILE = "pending_auto_tx.json"
        private const val MAX_PENDING = 50
    }

    private val isDebug: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName
        if (packageName != WECHAT_PACKAGE && packageName != ALIPAY_PACKAGE) return

        val extras = sbn.notification.extras
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val content = extras.getString(Notification.EXTRA_TEXT) ?: ""
        val bigText = extras.getString(Notification.EXTRA_BIG_TEXT) ?: ""
        val summaryText = extras.getString(Notification.EXTRA_SUMMARY_TEXT) ?: ""

        // Some ROMs use EXTRA_TEXT_LINES (CharSequence[]) for notification content lines
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        val linesText = textLines?.joinToString(" ") ?: ""

        // Combine all text sources; bigText usually has the most complete info for BigTextStyle notifications
        val combined = listOf(title, content, bigText, summaryText, linesText)
            .filter { it.isNotBlank() }
            .joinToString(" ")

        if (isDebug) {
            Log.d(TAG, "Notification from ${sbn.packageName}: combined=$combined")
        }

        if (combined.isBlank()) return

        val sourceApp = if (packageName == WECHAT_PACKAGE) "微信" else "支付宝"
        val parsed = parseNotification(combined, sourceApp)
        if (parsed != null && parsed.amountCents > 0) {
            if (!isDuplicate(parsed)) {
                savePendingTransaction(parsed, combined)
                if (isDebug) {
                    Log.i(TAG, "Saved pending tx: ${parsed.merchantName} ${parsed.amountCents / 100.0}元 type=${parsed.type}")
                }
                notifyFlutter()
            } else {
                if (isDebug) {
                    Log.d(TAG, "Duplicate tx ignored: ${parsed.merchantName}")
                }
            }
        } else {
            Log.d(TAG, "parseNotification returned null for combined text")
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
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

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
        } catch (e: Exception) {
            Log.e(TAG, "isDuplicate check failed: ${e.message}")
            false
        }
    }

    @Synchronized
    private fun savePendingTransaction(parsed: ParsedTx, rawContent: String) {
        try {
            val file = File(filesDir, PENDING_FILE)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

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
            Log.i(TAG, "Pending tx saved, total=${arr.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save pending transaction: ${e.message}")
        }
    }

    private fun notifyFlutter() {
        try {
            val sink = MainActivity.eventSink
            if (sink != null) {
                sink.success("pending_updated")
                Log.d(TAG, "Event sent to Flutter")
            } else {
                MainActivity.pendingEvent = true
                Log.d(TAG, "EventSink null, set pendingEvent flag")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify Flutter: ${e.message}")
        }
    }
}
