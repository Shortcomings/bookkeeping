package com.bookkeeping.bookkeeping

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.bookkeeping/auto_bookkeeping"
        private const val EVENT_CHANNEL = "com.bookkeeping/auto_bookkeeping/events"
        private const val PENDING_FILE = "pending_auto_tx.json"

        @Volatile
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingTransactions" -> result.success(getPendingTransactions())
                    "clearPendingTransactions" -> {
                        clearPendingTransactions()
                        result.success(null)
                    }
                    "isNotificationListenerEnabled" -> {
                        result.success(isNotificationListenerEnabled())
                    }
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    Companion.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    Companion.eventSink = null
                }
            })
    }

    private fun getPendingTransactions(): List<Map<String, Any?>> {
        val file = File(filesDir, PENDING_FILE)
        if (!file.exists()) return emptyList()

        return try {
            val json = JSONObject(file.readText())
            val arr = json.getJSONArray("transactions")
            val list = mutableListOf<Map<String, Any?>>()

            for (i in 0 until arr.length()) {
                val tx = arr.getJSONObject(i)
                list.add(mapOf(
                    "id" to tx.getString("id"),
                    "merchantName" to tx.getString("merchantName"),
                    "amountCents" to tx.getInt("amountCents"),
                    "type" to tx.getInt("type"),
                    "date" to tx.getString("date"),
                    "sourceApp" to tx.getString("sourceApp"),
                    "rawContent" to tx.optString("rawContent", "")
                ))
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun clearPendingTransactions() {
        val file = File(filesDir, PENDING_FILE)
        if (file.exists()) file.delete()
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        )
        val componentName = ComponentName(
            this, BookkeepingNotificationListener::class.java
        ).flattenToString()
        return flat?.contains(componentName) == true
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }
}
