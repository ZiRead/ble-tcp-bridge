package com.example.ble_tcp_bridge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class TcpForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "tcp_server_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.example.ble_tcp_bridge.START"
        const val ACTION_STOP = "com.example.ble_tcp_bridge.STOP"
        const val ACTION_REPOST = "com.example.ble_tcp_bridge.REPOST"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_BIG_TEXT = "big_text"

        var isRunning: Boolean = false
        var lastTitle: String = "TCP server running"
        var lastText: String = ""
        var lastBigText: String = ""
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Системный рестарт без интента — не показываем уведомление, если сервер остановлен.
        if (intent == null) {
            if (!isRunning) {
                stopSelf()
                return START_NOT_STICKY
            }
            startForeground(NOTIFICATION_ID, buildNotification(lastTitle, lastText, lastBigText))
            return START_STICKY
        }
        when (intent.action) {
            ACTION_STOP -> {
                isRunning = false
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIFICATION_ID)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_REPOST -> {
                if (!isRunning) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, buildNotification(lastTitle, lastText, lastBigText))
                return START_STICKY
            }
            else -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: lastTitle
                val text = intent.getStringExtra(EXTRA_TEXT) ?: lastText
                val bigText = intent.getStringExtra(EXTRA_BIG_TEXT) ?: text
                lastTitle = title
                lastText = text
                lastBigText = bigText
                isRunning = true
                startForeground(NOTIFICATION_ID, buildNotification(title, text, bigText))
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "TCP Server",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, text: String, bigText: String): Notification {
        val deleteIntent = Intent(this, TcpForegroundService::class.java).apply {
            action = ACTION_REPOST
        }
        val pendingDelete = PendingIntent.getService(
            this, 0, deleteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val contentIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingContent = PendingIntent.getActivity(
            this, 0, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingContent)
            .setDeleteIntent(pendingDelete)
            .setOnlyAlertOnce(true)
            .build()
    }
}