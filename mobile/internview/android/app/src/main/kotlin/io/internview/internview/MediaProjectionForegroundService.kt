package io.internview.internview

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MediaProjectionForegroundService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val notification = buildNotification()
    if (Build.VERSION.SDK_INT >= 34) {
      startForeground(NOTIF_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
    } else {
      startForeground(NOTIF_ID, notification)
    }
    return START_STICKY
  }

  private fun buildNotification(): Notification {
    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 26) {
      val channel = NotificationChannel(CHANNEL_ID, "Ekran paylaşımı", NotificationManager.IMPORTANCE_LOW)
      nm.createNotificationChannel(channel)
    }
    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle("Ekran paylaşımı aktif")
      .setContentText("Ekran paylaşımı devam ediyor.")
      .setSmallIcon(android.R.drawable.presence_video_online)
      .setOngoing(true)
      .build()
  }

  companion object {
    private const val CHANNEL_ID = "internview_screen_share"
    private const val NOTIF_ID = 4242
  }
}

