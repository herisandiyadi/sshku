package com.example.sshku

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.jcraft.jsch.Session
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.ConcurrentHashMap

class SshKeepAliveService : Service() {

    companion object {
        var sessions: ConcurrentHashMap<String, Session>? = null
        var durationMinutes: Int = 15
        var onExpired: (() -> Unit)? = null
    }

    private var timer: Timer? = null
    private var countdownTimer: Timer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var startTimeMs: Long = 0

    override fun onCreate() {
        super.onCreate()
        startTimeMs = System.currentTimeMillis()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("ssh_keepalive", "SSH Keep-Alive", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        updateNotification("SSH Active - ${durationMinutes}m remaining")
        startForeground(1, buildNotification("SSH Active - ${durationMinutes}m remaining"))

        // Keep-alive ping every 30s
        timer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    sessions?.values?.forEach { s ->
                        try { if (s.isConnected) s.sendKeepAliveMsg() } catch (_: Exception) {}
                    }
                }
            }, 30000L, 30000L)
        }

        // Countdown notification every minute
        countdownTimer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    val elapsedMs = System.currentTimeMillis() - startTimeMs
                    val totalMs = durationMinutes * 60_000L
                    val remainingMs = totalMs - elapsedMs
                    val remainingMin = (remainingMs / 60_000).toInt()

                    when {
                        remainingMs <= -30_000 -> {
                            // 15.5 min passed - stop
                            handler.post {
                                onExpired?.invoke()
                                stopSelf()
                            }
                        }
                        remainingMs <= 0 -> {
                            // 15 min passed - warning
                            handler.post { updateNotification("Session expiring soon") }
                        }
                        else -> {
                            handler.post { updateNotification("SSH Active - ${remainingMin + 1}m remaining") }
                        }
                    }
                }
            }, 60_000L, 60_000L)
        }

        // Hard stop at 15.5 min
        handler.postDelayed({
            onExpired?.invoke()
            stopSelf()
        }, (durationMinutes * 60_000L) + 30_000L)
    }

    private fun buildNotification(text: String) =
        NotificationCompat.Builder(this, "ssh_keepalive")
            .setContentTitle(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()

    private fun updateNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(1, buildNotification(text))
    }

    override fun onDestroy() {
        timer?.cancel()
        countdownTimer?.cancel()
        handler.removeCallbacksAndMessages(null)
        timer = null
        countdownTimer = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
