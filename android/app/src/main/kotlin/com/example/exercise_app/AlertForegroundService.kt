package com.example.exercise_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AlertForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "threshold_alert_audio"
        private const val NOTIFICATION_ID = 9017
        private const val ACTION_START = "com.example.exercise_app.action.START"
        private const val ACTION_STOP = "com.example.exercise_app.action.STOP"

        fun start(context: Context) {
            val intent = Intent(context, AlertForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, AlertForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var mediaPlayer: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopAlert()
            else -> startAlert()
        }
        return START_STICKY
    }

    private fun startAlert() {
        if (mediaPlayer?.isPlaying == true) return

        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Energy Smart Alert")
            .setContentText("Threshold alert is active")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        mediaPlayer?.release()
        mediaPlayer = MediaPlayer.create(this, R.raw.alert_tone).apply {
            isLooping = true
            setWakeMode(this@AlertForegroundService, PowerManager.PARTIAL_WAKE_LOCK)
            start()
        }
    }

    private fun stopAlert() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Threshold Alert Audio",
                    NotificationManager.IMPORTANCE_LOW,
                )
                channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                manager.createNotificationChannel(channel)
            }
        }
    }
}
