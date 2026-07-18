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

open class BackgroundConnectionForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (running) {
            markRunning(this)
            return START_NOT_STICKY
        }

        return try {
            createNotificationChannel()
            startForegroundCompat(buildNotification())
            markRunning(this)
            START_NOT_STICKY
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service", e)
            stopForegroundAndSelf()
            START_NOT_STICKY
        }
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(TAG, "Foreground service timed out; stopping cleanly")
        markTimedOut(this)
        stopForegroundAndSelf()
    }

    override fun onDestroy() {
        removeForegroundNotification()
        markStopped()
        super.onDestroy()
    }

    private fun stopForegroundAndSelf() {
        removeForegroundNotification()
        markStopped()
        stopSelf()
    }

    private fun removeForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING
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
            "Persistent notification while OSIA is ready for messages from your PC."
        private const val NOTIFICATION_ID = 110
        private const val NOTIFICATION_TITLE = "OSIA background connection active"
        private const val NOTIFICATION_TEXT = "Ready for messages from your PC."
        private const val STATE_PREFERENCES = "osia_background_connection_state"
        private const val TIMED_OUT_KEY = "stopped_by_timeout"
        private val stateLock = Any()

        @Volatile
        private var running = false

        @Volatile
        private var startRequested = false

        val isRunning: Boolean
            get() = running || startRequested

        fun start(context: Context): Boolean {
            synchronized(stateLock) {
                if (isRunning) return true
                startRequested = true
            }

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
                markStopped()
                false
            }
        }

        fun stop(context: Context) {
            clearTimedOut(context)
            markStopped()
            val intent = Intent(
                context,
                BackgroundConnectionForegroundService::class.java
            )
            context.stopService(intent)
        }

        fun consumeStoppedByTimeout(context: Context): Boolean {
            val preferences = context.getSharedPreferences(
                STATE_PREFERENCES,
                Context.MODE_PRIVATE
            )
            val timedOut = preferences.getBoolean(TIMED_OUT_KEY, false)
            if (timedOut) {
                preferences.edit().putBoolean(TIMED_OUT_KEY, false).apply()
            }
            return timedOut
        }

        private fun markRunning(context: Context) {
            synchronized(stateLock) {
                running = true
                startRequested = false
            }
            clearTimedOut(context)
        }

        private fun markStopped() {
            synchronized(stateLock) {
                running = false
                startRequested = false
            }
        }

        private fun markTimedOut(context: Context) {
            val persisted = context
                .getSharedPreferences(STATE_PREFERENCES, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(TIMED_OUT_KEY, true)
                .commit()
            if (!persisted) {
                Log.e(TAG, "Unable to persist foreground timeout state")
            }
        }

        private fun clearTimedOut(context: Context) {
            context.getSharedPreferences(STATE_PREFERENCES, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(TIMED_OUT_KEY, false)
                .apply()
        }
    }
}
