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

        // Skip group summary notifications (they lack individual tx details)
        if ((sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) {
            Log.d(TAG, "Skipping group summary notification from ${sbn.packageName}")
            return
        }

        if (isDebug) {
            Log.d(TAG, "Notification from ${sbn.packageName}: combined=$combined")
        }

        if (combined.isBlank()) return

        val sourceApp = if (packageName == WECHAT_PACKAGE) "微信" else "支付宝"
        val parsed = parseNotification(combined, sourceApp)
        if (parsed != null && parsed.amountCents > 0) {
            val saved = savePendingTransaction(parsed, combined)
            if (saved) {
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
        // Strip commas from amounts (e.g. "1,234.56元" → "1234.56元")
        val sanitized = fullText.replace(",", "")

        // Amount regex: (\d+\.?\d{0,2})\s*元
        val amountRegex = Regex("""(\d+\.?\d{0,2})\s*元""")
        val amountMatches = amountRegex.findAll(sanitized).toList()

        // ¥/￥ amount regex
        val altRegex = Regex("""[¥￥]\s*(\d+\.?\d{0,2})""")
        val altMatches = altRegex.findAll(sanitized).toList()

        if (amountMatches.isEmpty() && altMatches.isEmpty()) return null

        // Pick the payment amount intelligently:
        // - ¥/￥ prefix amounts are most likely the payment amount → use those first
        // - For "元" amounts, use minOf (balance amounts are always larger than payment)
        // - But prefer amounts near payment keywords
        val amount = selectPaymentAmount(amountMatches, altMatches, sanitized)
            ?: return null
        if (amount <= 0) return null
        val amountCents = (amount * 100).toInt()

        // Determine type
        val isExpense = sanitized.contains("支付") || sanitized.contains("消费") ||
                sanitized.contains("付款") || sanitized.contains("扣款") ||
                sanitized.contains("提现") || sanitized.contains("转出") ||
                sanitized.contains("充值") || sanitized.contains("缴费")
        val isIncome = sanitized.contains("收款") || sanitized.contains("到账") ||
                sanitized.contains("入账") || sanitized.contains("转入") ||
                sanitized.contains("退款") || sanitized.contains("返现") ||
                sanitized.contains("红包")
        val type = if (isIncome && !isExpense) 1 else 0

        val merchantName = cleanMerchantName(sanitized, amountRegex, sourceApp)
        return ParsedTx(merchantName, amountCents, type, sourceApp)
    }

    private fun selectPaymentAmount(
        amountMatches: List<MatchResult>,
        altMatches: List<MatchResult>,
        text: String
    ): Double? {
        // Priority 1: ¥/￥ prefixed amounts — these almost always mark the payment
        if (altMatches.isNotEmpty()) {
            return altMatches.maxOfOrNull {
                it.groupValues[1].toDoubleOrNull() ?: 0.0
            }
        }

        // Priority 2: amount near payment keyword (within 15 chars)
        val paymentKeywords = listOf("支付", "付款", "消费", "收款", "到账", "扣款")
        for (kw in paymentKeywords) {
            val kwIdx = text.indexOf(kw)
            if (kwIdx >= 0) {
                val nearMatch = amountMatches.firstOrNull { m ->
                    kotlin.math.abs(m.range.first - kwIdx) <= 15
                }
                if (nearMatch != null) {
                    return nearMatch.groupValues[1].toDoubleOrNull()
                }
            }
        }

        // Priority 3: minOf — balances are always larger than payment amounts
        return amountMatches.minOfOrNull {
            it.groupValues[1].toDoubleOrNull() ?: 0.0
        }
    }

    private fun cleanMerchantName(fullText: String, amountRegex: Regex, sourceApp: String): String {
        var cleaned = fullText.replace(amountRegex, "")
            .replace(Regex("""[¥￥]\s*\d+\.?\d{0,2}"""), "")
            .replace(Regex("""\d+\.?\d{0,2}\s*元"""), "")
            .replace(Regex("""(支付成功|付款成功|收款成功|消费|交易|通知|提醒|账单|明细|￥|¥|\$|微信支付|支付宝)"""), "")
            .replace(Regex("""(商品说明|商户名称|商户|收款方|交易对方|付款方式|付款账户|支付方式|交易时间|交易单号|订单号)[：:]\s*"""), "")
            .replace(Regex("""https?://\S+"""), "")
            .replace(Regex("""\s+"""), " ")
            .trim()

        // Truncate
        if (cleaned.length > 30) cleaned = cleaned.substring(0, 30)
        if (cleaned.isBlank()) cleaned = "未知商户"
        return cleaned
    }

    @Synchronized
    private fun savePendingTransaction(parsed: ParsedTx, rawContent: String): Boolean {
        try {
            val file = File(filesDir, PENDING_FILE)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

            // Duplicate check inside synchronized block (atomic with save)
            if (file.exists()) {
                val existing = JSONObject(file.readText())
                val arr = existing.optJSONArray("transactions")
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val tx = arr.getJSONObject(i)
                        if (tx.optString("sourceApp") == parsed.sourceApp &&
                            tx.optInt("amountCents") == parsed.amountCents &&
                            tx.optString("merchantName") == parsed.merchantName &&
                            tx.optString("date") == today
                        ) {
                            return false // duplicate
                        }
                    }
                }
            }

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
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save pending transaction: ${e.message}")
            return false
        }
    }

    private fun notifyFlutter() {
        try {
            // Use file flag for cross-process IPC (service runs in :nl process)
            val flagFile = File(filesDir, "pending_event.flag")
            val count = if (flagFile.exists()) {
                flagFile.readText().toIntOrNull() ?: 0
            } else {
                0
            }
            flagFile.writeText((count + 1).toString())
            Log.d(TAG, "Event flag set, count=${count + 1}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify Flutter: ${e.message}")
        }
    }
}
