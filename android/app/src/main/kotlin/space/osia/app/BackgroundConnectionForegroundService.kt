package space.osia.app

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
import android.util.Log

class BackgroundConnectionForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return try {
            createNotificationChannel()
            startForegroundCompat(buildNotification())
            isRunning = true
            START_NOT_STICKY
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service", e)
            isRunning = false
            stopSelf()
            START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = CHANNEL_DESCRIPTION
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(NOTIFICATION_TITLE)
            .setContentText(NOTIFICATION_TEXT)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .apply {
                if (pendingIntent != null) {
                    setContentIntent(pendingIntent)
                }
            }
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val TAG = "OSIA Background"
        private const val CHANNEL_ID = "osia_background_connection"
        private const val CHANNEL_NAME = "OSIA background connection"
        private const val CHANNEL_DESCRIPTION =
            "Persistent notification while OSIA keeps its mobile connection active."
        private const val NOTIFICATION_ID = 110
        private const val NOTIFICATION_TITLE = "OSIA connected"
        private const val NOTIFICATION_TEXT = "Keeping the mobile connection active."

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context): Boolean {
            return try {
                val intent = Intent(
                    context,
                    BackgroundConnectionForegroundService::class.java
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (e: Exception) {
                Log.e(TAG, "Unable to request foreground service start", e)
                false
            }
        }

        fun stop(context: Context) {
            val intent = Intent(
                context,
                BackgroundConnectionForegroundService::class.java
            )
            context.stopService(intent)
            isRunning = false
        }
    }
}
