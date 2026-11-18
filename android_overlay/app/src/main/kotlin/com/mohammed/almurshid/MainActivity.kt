package com.mohammed.almurshid

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.webkit.CookieManager
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
        val left = ms.coerceIn(1L, 21600000L)
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
                        prefs.edit().putLong("left", (call.argument<Number>("left"))!!.toLong().coerceIn(0L, 21600000L)).apply()
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
                "getCookies" -> {
                    result.success(CookieManager.getInstance().getCookie(call.argument<String>("url") ?: "") ?: "")
                }
                "notify" -> {
                    Notifier.show(this, (call.argument<Number>("id"))!!.toInt(), call.argument<String>("title") ?: "", call.argument<String>("body") ?: "")
                    result.success(true)
                }
                "schedule" -> {
                    Notifier.schedule(this, (call.argument<Number>("id"))!!.toInt(), (call.argument<Number>("at"))!!.toLong(),
                        call.argument<String>("title") ?: "", call.argument<String>("body") ?: "")
                    result.success(true)
                }
                "cancelReminder" -> {
                    Notifier.cancel(this, (call.argument<Number>("id"))!!.toInt())
                    result.success(true)
                }
                "requestNotifPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 77)
                    }
                    result.success(true)
                }
                "isDeviceOwner" -> {
                    result.success(getSystemService(DevicePolicyManager::class.java).isDeviceOwnerApp(packageName))
                }
                // Copies a finished download into the phone's gallery (Movies/المرشد/<folder>); returns its Uri
                "saveToGallery" -> {
                    val path = call.argument<String>("path")!!
                    val name = call.argument<String>("name")!!
                    val folder = call.argument<String>("folder") ?: "المرشد"
                    Thread {
                        val uri = try { saveToGallery(path, name, folder) } catch (e: Exception) { null }
                        runOnUiThread { result.success(uri) }
                    }.start()
                }
                // Keeps the gallery copy in step with renames / deletes done in the app (the app owns these items)
                "galleryRename" -> {
                    val ok = try {
                        val cv = ContentValues().apply { put(MediaStore.MediaColumns.DISPLAY_NAME, call.argument<String>("name")!!) }
                        contentResolver.update(Uri.parse(call.argument<String>("uri")!!), cv, null, null) > 0
                    } catch (e: Exception) { false }
                    result.success(ok)
                }
                "galleryDelete" -> {
                    val ok = try { contentResolver.delete(Uri.parse(call.argument<String>("uri")!!), null, null) > 0 } catch (e: Exception) { false }
                    result.success(ok)
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

    // MediaStore insert (Android 10+, no storage permission). null = not possible / not a media file.
    private fun saveToGallery(path: String, name: String, folder: String): String? {
        if (Build.VERSION.SDK_INT < 29) return null
        val src = java.io.File(path)
        if (!src.exists()) return null
        val ext = name.substringAfterLast('.', "").lowercase()
        val video = mapOf("mp4" to "video/mp4", "m4v" to "video/mp4", "webm" to "video/webm", "mkv" to "video/x-matroska",
            "mov" to "video/quicktime", "3gp" to "video/3gpp")
        val audio = mapOf("m4a" to "audio/mp4", "mp3" to "audio/mpeg", "aac" to "audio/aac", "ogg" to "audio/ogg",
            "opus" to "audio/ogg", "wav" to "audio/wav")
        val isAudio = audio.containsKey(ext)
        val mime = video[ext] ?: audio[ext] ?: return null
        val collection = if (isAudio) MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                         else MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val base = if (isAudio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES
        val cv = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "$base/المرشد/$folder")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(collection, cv) ?: return null
        try {
            contentResolver.openOutputStream(uri)?.use { out -> src.inputStream().use { it.copyTo(out) } }
                ?: throw java.io.IOException("no stream")
            val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
            contentResolver.update(uri, done, null, null)
        } catch (e: Exception) {
            try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
            return null
        }
        return uri.toString()
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
