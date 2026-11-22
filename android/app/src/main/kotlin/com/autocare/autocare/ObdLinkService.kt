package com.autocare.autocare

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * Keeps the process and CPU running while an OBD link is open, so polling and
 * trip recording go on with the screen off. Started and stopped from Dart
 * (lib/core/services/background_service.dart) only: no boot receiver,
 * START_NOT_STICKY, and the wake lock is held only between start and stop.
 */
class ObdLinkService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification(
            intent?.getStringExtra(EXTRA_TITLE) ?: "AutoCare",
            intent?.getStringExtra(EXTRA_TEXT) ?: "",
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Android 14 refuses connectedDevice without BLUETOOTH_CONNECT; the
            // link itself keeps working, only without the foreground guarantee.
            Log.w(TAG, "startForeground refused: $e")
            stopSelf()
            return START_NOT_STICKY
        }
        if (wakeLock?.isHeld != true) {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AutoCare:ObdLink").apply {
                setReferenceCounted(false)
                // Safety cap in case stop never arrives; a drive is far shorter.
                acquire(MAX_WAKE_MS)
            }
        }
        return START_NOT_STICKY
    }

    // Swiping the app away ends its Flutter engine and with it the OBD link,
    // so there is nothing left to keep alive.
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    private fun buildNotification(title: String, text: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0),
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            // Same id as the earlier plugin channel, so users keep their settings.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AutoCare Background Service",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Keeps OBD monitoring alive while connected."
            manager.createNotificationChannel(channel)
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_obd)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val TAG = "ObdLinkService"
        private const val CHANNEL_ID = "autocare_foreground"
        private const val NOTIFICATION_ID = 888
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val MAX_WAKE_MS = 6L * 60 * 60 * 1000

        /** False when Android refuses the start, e.g. from the background on 12+. */
        fun start(context: Context, title: String, text: String): Boolean {
            val intent = Intent(context, ObdLinkService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (e: Exception) {
                Log.w(TAG, "start refused: $e")
                false
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ObdLinkService::class.java))
        }
    }
}
