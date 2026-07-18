package space.osia.app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BackgroundConnectionForegroundServiceInstrumentedTest {
    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @After
    fun tearDown() {
        context.stopService(
            Intent(context, BackgroundConnectionTimeoutProbeService::class.java)
        )
    }

    @Test
    fun testApi35TimeoutStopsServiceAndRemovesForegroundNotification() {
        assumeTrue(Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM)

        context.startForegroundService(
            Intent(context, BackgroundConnectionTimeoutProbeService::class.java)
        )
        waitUntil { BackgroundConnectionTimeoutProbeService.instance != null }
        val runningService = BackgroundConnectionTimeoutProbeService.instance
        assertNotNull(runningService)
        assertTrue(BackgroundConnectionForegroundService.isRunning)
        if (context.getSystemService(NotificationManager::class.java)
                .areNotificationsEnabled()
        ) {
            waitUntil { activeNotificationIds().contains(110) }
            assertTrue(activeNotificationIds().contains(110))
        }

        runningService!!.onTimeout(
            1,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING
        )

        waitUntil { !BackgroundConnectionForegroundService.isRunning }

        assertFalse(BackgroundConnectionForegroundService.isRunning)
        assertFalse(activeNotificationIds().contains(110))
    }

    private fun activeNotificationIds(): Set<Int> = context
        .getSystemService(NotificationManager::class.java)
        .activeNotifications
        .mapTo(mutableSetOf()) { it.id }

    private fun waitUntil(predicate: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 2_000
        while (!predicate() && SystemClock.uptimeMillis() < deadline) {
            SystemClock.sleep(20)
        }
        assertTrue(predicate())
    }
}
