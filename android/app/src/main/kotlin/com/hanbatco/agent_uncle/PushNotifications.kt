package com.hanbatco.agent_uncle

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID

internal object PushState {
    var channel: MethodChannel? = null
    var foreground = false
    fun prefs(context: Context) = context.getSharedPreferences("saip_push", Context.MODE_PRIVATE)
    fun emit() { Handler(Looper.getMainLooper()).post { channel?.invokeMethod("changed", null) } }
    fun channels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        mapOf("chat" to "새 메시지", "request" to "사입 업무", "connection" to "거래처 연결").forEach { (id, title) ->
            manager.createNotificationChannel(NotificationChannel("saip_$id", title, NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true); setShowBadge(true)
            })
        }
    }
}

class PushNotifications(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "agent_uncle/notifications")
    private val prefs = PushState.prefs(activity)
    init {
        PushState.channel = channel
        PushState.channels(activity)
        if (!prefs.contains("id")) prefs.edit().putString("id", UUID.randomUUID().toString()).apply()
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "bind" -> {
                    val owner = call.argument<String>("ownerId") ?: ""
                    if (owner != prefs.getString("owner", "")) {
                        prefs.edit().putString("owner", owner).putString("binding", UUID.randomUUID().toString()).remove("seen").remove("tap").apply()
                        NotificationManagerCompat.from(activity).cancelAll()
                    }
                    if (owner.isNotEmpty()) {
                        if (FirebaseApp.getApps(activity).isNotEmpty() && Build.VERSION.SDK_INT >= 33 && !prefs.getBoolean("permissionAsked", false)) {
                            prefs.edit().putBoolean("permissionAsked", true).apply()
                            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8017)
                        }
                        refreshToken()
                    } else if (FirebaseApp.getApps(activity).isNotEmpty()) {
                        FirebaseMessaging.getInstance().isAutoInitEnabled = false
                    }
                    result.success(state())
                }
                "state" -> { refreshToken(); result.success(state()) }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8017)
                    refreshToken(); result.success(null)
                }
                "openSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
                    result.success(null)
                }
                "clear" -> {
                    prefs.edit().putString("owner", "").putString("binding", UUID.randomUUID().toString()).remove("tap").apply()
                    NotificationManagerCompat.from(activity).cancelAll()
                    if (FirebaseApp.getApps(activity).isNotEmpty()) FirebaseMessaging.getInstance().isAutoInitEnabled = false
                    result.success(null)
                }
                "takeTap" -> {
                    val raw = prefs.getString("tap", null)
                    prefs.edit().remove("tap").apply()
                    result.success(raw?.let { jsonMap(JSONObject(it)) })
                }
                "startActivity", "syncActivities" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        capture(activity.intent)
    }
    fun capture(intent: Intent?) {
        val raw = intent?.getStringExtra("saip_push") ?: return
        val data = runCatching { JSONObject(raw) }.getOrNull() ?: return
        // 오래된 계정 바인딩의 PendingIntent는 계정이 같아도 열지 않는다.
        if (data.optString("binding") == prefs.getString("binding", "")) {
            prefs.edit().putString("tap", raw).apply(); PushState.emit()
        }
        intent.removeExtra("saip_push")
    }
    private fun refreshToken() {
        if (prefs.getString("owner", "").isNullOrEmpty() || FirebaseApp.getApps(activity).isEmpty()) return
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = true
        messaging.token.addOnSuccessListener { token ->
            if (token != prefs.getString("token", "")) { prefs.edit().putString("token", token).apply(); PushState.emit() }
        }.addOnFailureListener { /* 다음 앱 복귀/동기화 때 재시도한다. 토큰은 로그에 남기지 않는다. */ }
    }
    private fun state(): Map<String, Any> = mapOf(
        "id" to (prefs.getString("id", "") ?: ""), "binding" to (prefs.getString("binding", "") ?: ""),
        "token" to (prefs.getString("token", "") ?: ""), "platform" to "android", "environment" to "production",
        "enabled" to NotificationManagerCompat.from(activity).areNotificationsEnabled(),
        "configured" to FirebaseApp.getApps(activity).isNotEmpty(), "liveSupported" to false,
    )
    fun dispose() { channel.setMethodCallHandler(null); if (PushState.channel === channel) PushState.channel = null }
    private fun jsonMap(json: JSONObject): Map<String, String> = json.keys().asSequence().associateWith { json.optString(it) }
}

class SaipMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) { PushState.prefs(this).edit().putString("token", token).apply(); PushState.emit() }
    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val prefs = PushState.prefs(this)
        val id = data["id"] ?: return
        if (data["ownerId"] != prefs.getString("owner", "") || data["binding"] != prefs.getString("binding", "")) return
        synchronized(PushState) {
            val seen = prefs.getStringSet("seen", emptySet())!!.toMutableSet()
            if (id in seen) return
            if (seen.size >= 200) seen.clear()
            seen.add(id); prefs.edit().putStringSet("seen", seen).apply()
        }
        // 전경에서는 기존 Realtime 배지/알림함이 표시 주체다.
        if (PushState.foreground) { PushState.emit(); return }
        if (!NotificationManagerCompat.from(this).areNotificationsEnabled()) return
        PushState.channels(this)
        val channel = when (data["kind"]) { "chat" -> "chat"; "connection" -> "connection"; else -> "request" }
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .setAction("saip.push.$id").putExtra("saip_push", JSONObject(data).toString())
        val tap = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, "saip_$channel")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(data["title"] ?: "사입삼춘").setContentText(data["body"] ?: "새 소식이 있어요.")
            .setContentIntent(tap).setAutoCancel(true).setOnlyAlertOnce(true)
            .setCategory(if (channel == "chat") NotificationCompat.CATEGORY_MESSAGE else NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setPriority(NotificationCompat.PRIORITY_HIGH).build()
        try { NotificationManagerCompat.from(this).notify(id, 0, notification) } catch (_: SecurityException) { }
    }
}
