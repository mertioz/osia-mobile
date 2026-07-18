package space.osia.app

class BackgroundConnectionTimeoutProbeService :
    BackgroundConnectionForegroundService() {

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    companion object {
        @Volatile
        var instance: BackgroundConnectionTimeoutProbeService? = null
            private set
    }
}
