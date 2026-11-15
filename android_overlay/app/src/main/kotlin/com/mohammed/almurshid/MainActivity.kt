package com.mohammed.almurshid

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Empty receiver: lets the app be registered as Device Owner via adb (true kiosk lock)
class FocusAdmin : DeviceAdminReceiver()

// Strict study session. The session lives in native storage so it survives an app kill / reboot,
// and it carries a hard end time so it can never lock the phone longer than planned.
class MainActivity : FlutterActivity() {
    private val prefs by lazy { getSharedPreferences("strict", MODE_PRIVATE) }

    private fun leftMs() = prefs.getLong("left", 0L)
    private fun endAt() = prefs.getLong("endAt", 0L)
    private fun sessionActive() = leftMs() > 0L && (endAt() == 0L || System.currentTimeMillis() < endAt())

    // Android 12+: while a session is active, other apps' floating windows are hidden over our app
    private fun applyOverlayBlock() {
        if (Build.VERSION.SDK_INT >= 31) {
            try { window.setHideOverlayWindows(sessionActive()) } catch (e: Exception) {}
        }
    }

    private fun startSession(ms: Long, type: String?, target: String?) {
        val left = ms.coerceIn(1L, 3600000L)
        prefs.edit()
            .putLong("left", left)
            .putLong("endAt", System.currentTimeMillis() + left)
            .putString("type", type)
            .putString("target", target)
            .apply()
        enforceLock()
        applyOverlayBlock()
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "focus_lock").setMethodCallHandler { call, result ->
            when (call.method) {
                "startLock" -> {
                    startSession((call.argument<Number>("left"))!!.toLong(), call.argument<String>("type"), call.argument<String>("target"))
                    result.success(true)
                }
                "extendLock" -> {
                    startSession((call.argument<Number>("left"))!!.toLong(), prefs.getString("type", "study"), prefs.getString("target", ""))
                    result.success(true)
                }
                // Dart reports the remaining time every few seconds
                "setLeft" -> {
                    if (prefs.contains("type")) {
                        prefs.edit().putLong("left", (call.argument<Number>("left"))!!.toLong().coerceIn(0L, 3600000L)).apply()
                    }
                    result.success(true)
                }
                "releaseLock", "stopLock" -> {
                    prefs.edit().clear().apply()
                    applyOverlayBlock()
                    try { stopLockTask() } catch (e: Exception) {}
                    result.success(true)
                }
                // The saved session, so Dart can resume it after a restart
                "getSession" -> {
                    if (sessionActive()) {
                        val byClock = if (endAt() > 0L) endAt() - System.currentTimeMillis() else leftMs()
                        result.success(mapOf(
                            "left" to minOf(leftMs(), byClock),
                            "type" to prefs.getString("type", ""),
                            "target" to prefs.getString("target", "")
                        ))
                    } else {
                        prefs.edit().clear().apply()
                        result.success(null)
                    }
                }
                "isAccessibilityEnabled" -> {
                    val on = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
                    result.success(on.contains("$packageName/"))
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                // Emergency calls stay possible: opens the phone's dialer
                "openDialer" -> {
                    startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                // True only when OUR window has the focus and is not floating / split-screen
                "isFocused" -> {
                    val multi = Build.VERSION.SDK_INT >= 24 && isInMultiWindowMode
                    result.success(hasWindowFocus() && !multi)
                }
                "isDeviceOwner" -> {
                    result.success(getSystemService(DevicePolicyManager::class.java).isDeviceOwnerApp(packageName))
                }
                else -> result.notImplemented()
            }
        }
    }

    // Re-enter lock whenever the app comes back during an active session
    override fun onResume() {
        super.onResume()
        startFloatWatch()
        applyOverlayBlock()
        if (sessionActive()) enforceLock()
    }

    // Watches (every second) whether OUR window became floating / split-screen; if so the task is
    // removed and LockService re-opens the app full screen.
    private val floatHandler = Handler(Looper.getMainLooper())
    private var watching = false
    private val floatCheck = object : Runnable {
        override fun run() {
            if (sessionActive() && Build.VERSION.SDK_INT >= 24 && isInMultiWindowMode) {
                val now = System.currentTimeMillis()
                if (now - prefs.getLong("fixAt", 0L) > 3000) { // guard against loops
                    prefs.edit().putLong("fixAt", now).apply()
                    finishAndRemoveTask()
                    return
                }
            }
            floatHandler.postDelayed(this, 1000)
        }
    }

    private fun startFloatWatch() {
        if (!watching) { watching = true; floatHandler.postDelayed(floatCheck, 1000) }
    }

    override fun onDestroy() {
        floatHandler.removeCallbacks(floatCheck)
        watching = false
        super.onDestroy()
    }

    private fun enforceLock() {
        val dpm = getSystemService(DevicePolicyManager::class.java)
        if (dpm.isDeviceOwnerApp(packageName)) {
            // Device Owner = real kiosk. The dialer is whitelisted so calls still work.
            val admin = ComponentName(this, FocusAdmin::class.java)
            val dialer = try { getSystemService(TelecomManager::class.java).defaultDialerPackage } catch (e: Exception) { null }
            dpm.setLockTaskPackages(admin, listOfNotNull(packageName, dialer).toTypedArray())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) dpm.setLockTaskFeatures(admin, 0)
            try { startLockTask() } catch (e: Exception) {}
        }
        // Not Device Owner: the accessibility service (LockService) does the enforcing instead.
    }
}
