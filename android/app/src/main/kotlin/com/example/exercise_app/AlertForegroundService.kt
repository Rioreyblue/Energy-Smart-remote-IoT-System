package com.example.exercise_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class AlertForegroundService : Service() {
  companion object {
    private const val CHANNEL_ID = "threshold_alerts_foreground"
    private const val NOTIFICATION_ID = 7771

    fun start(context: Context) {
      val intent = Intent(context, AlertForegroundService::class.java)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        ContextCompat.startForegroundService(context, intent)
      } else {
        context.startService(intent)
      }
    }

    fun stop(context: Context) {
      val intent = Intent(context, AlertForegroundService::class.java)
      context.stopService(intent)
    }
  }

  private var mediaPlayer: MediaPlayer? = null
  private var wakeLock: PowerManager.WakeLock? = null

  override fun onCreate() {
    super.onCreate()
    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
    wakeLock = pm.newWakeLock(
      PowerManager.PARTIAL_WAKE_LOCK,
      "${javaClass.simpleName}:WakeLock",
    ).apply {
      setReferenceCounted(false)
    }
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == "STOP") {
      stopSelf()
      return START_NOT_STICKY
    }

    startForeground(NOTIFICATION_ID, buildNotification())
    startAudio()
    return START_STICKY
  }

  override fun onDestroy() {
    super.onDestroy()
    stopAudio()
    wakeLock?.release()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  private fun buildNotification(): Notification {
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Threshold Alerts",
        NotificationManager.IMPORTANCE_HIGH,
      ).apply {
        description = "Persistent alert while energy threshold alarm is active"
        setSound(null, null)
        enableVibration(true)
      }
      manager.createNotificationChannel(channel)
    }

    val stopIntent = Intent(this, AlertForegroundService::class.java).apply {
      action = "STOP"
    }
    val stopPendingIntent = PendingIntent.getService(
      this,
      0,
      stopIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0,
    )

    val launchIntent = packageManager?.getLaunchIntentForPackage(packageName)
      ?: Intent(Intent.ACTION_MAIN).apply {
        addCategory(Intent.CATEGORY_LAUNCHER)
        setPackage(packageName)
      }
    val contentPendingIntent = PendingIntent.getActivity(
      this,
      1,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0,
    )

    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle("Energy usage alert")
      .setContentText("Usage threshold exceeded. Tap to manage the alert.")
      .setSmallIcon(applicationInfo.icon)
      .setPriority(NotificationCompat.PRIORITY_MAX)
      .setCategory(NotificationCompat.CATEGORY_ALARM)
      .setOngoing(true)
      .setAutoCancel(false)
      .setContentIntent(contentPendingIntent)
      .addAction(
        NotificationCompat.Action.Builder(
          0,
          "Stop",
          stopPendingIntent,
        ).build(),
      )
      .build()
  }

  private fun startAudio() {
    if (wakeLock?.isHeld != true) {
      wakeLock?.acquire(10 * 60 * 1000L)
    }

    if (mediaPlayer?.isPlaying == true) return

    val toneUri = resolveAlertTone()
    mediaPlayer = MediaPlayer().apply {
      setDataSource(this@AlertForegroundService, toneUri)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        setAudioAttributes(
          AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build(),
        )
      } else {
        @Suppress("DEPRECATION")
        setAudioStreamType(android.media.AudioManager.STREAM_ALARM)
      }
      isLooping = true
      prepare()
      start()
    }
  }

  private fun stopAudio() {
    mediaPlayer?.stop()
    mediaPlayer?.release()
    mediaPlayer = null
  }

  private fun resolveAlertTone(): Uri {
    val resId = resources.getIdentifier(
      "alert_tone",
      "raw",
      packageName,
    )

    return if (resId != 0) {
      Uri.parse("android.resource://$packageName/$resId")
    } else {
      RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }
  }
}

