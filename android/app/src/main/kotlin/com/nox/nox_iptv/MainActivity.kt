package com.nox.nox_iptv

import android.app.ActivityManager
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Exposes ActivityManager's real device memory info to Dart — Flutter has
 * no built-in way to ask "how much RAM does this specific device have",
 * and the app's image cache ceiling needs that to scale itself per device
 * instead of using one fixed number for every Firestick regardless of how
 * much headroom it actually has (see main.dart's _configureImageCache).
 * Mirrors how Glide, the standard Android image-loading library, sizes
 * its own cache via ActivityManager.isLowRamDevice()/getMemoryInfo().
 *
 * Also exposes the "install a downloaded update APK" flow for
 * AppUpdateService's in-app "Check for Updates" — no Flutter plugin
 * covers this on its own, since it involves both a permission check only
 * meaningful on Android 8+ and handing another app (the system installer)
 * a content:// URI via FileProvider, which needs the provider declared in
 * AndroidManifest.xml/res/xml/file_paths.xml.
 */
class MainActivity : FlutterActivity() {
    private val MEMORY_CHANNEL = "com.nox.nox_iptv/device_memory"
    private val UPDATE_CHANNEL = "com.nox.nox_iptv/app_update"
    private val DEVICE_CHANNEL = "com.nox.nox_iptv/device_type"
    private val BACKUP_CHANNEL = "com.nox.nox_iptv/backup"
    private val backupStore by lazy { BackupStore(this) }
    private val localImportStore by lazy { LocalImportStore(this) }
    private val recorderBridge by lazy { RecorderBridge(this) }
    private val displayModes by lazy { DisplayModes(this) }

    /**
     * Native video surface (beta, Settings > Interface > Background video): Flutter starts
     * transparent so the vendored player's SurfaceView behind it shows through the video
     * hole (see NativeVideoSurface in third_party/video_player_android). Read once at
     * launch from Flutter's SharedPreferences file, so the switch applies after a restart.
     * getBackgroundMode, not getTransparencyMode: FlutterActivity derives the transparent
     * window, the render mode (texture) and the transparency all from it (Flutter 3.47);
     * overriding only getTransparencyMode left the window opaque (+423).
     */
    override fun getBackgroundMode(): BackgroundMode {
        val on = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.vesper_native_video_surface", false)
        Log.i("VesperNativeSurface", "startup: native video surface ${if (on) "ON (transparent Flutter view)" else "off"}, " +
            "${Build.MANUFACTURER} ${Build.MODEL} SDK ${Build.VERSION.SDK_INT}")
        return if (on) BackgroundMode.transparent else super.getBackgroundMode()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (!backupStore.onPermissionResult(requestCode, grantResults)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    @Deprecated("Activity result API; FlutterActivity still routes through this")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!localImportStore.onActivityResult(requestCode, resultCode, data) &&
            !backupStore.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        localImportStore.close()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nox.nox_iptv/storage_import")
            .setMethodCallHandler(localImportStore::handle)

        // Settings > Backup & restore — see BackupStore.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result -> backupStore.handle(call, result) }

        // Sports Trak recording — see RecorderService / RecorderScheduler.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vespertv/recorder")
            .setMethodCallHandler { call, result -> recorderBridge.handle(call, result) }

        // Settings > Interface > Display: Match frame rate / resolution — see DisplayModes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vespertv/display")
            .setMethodCallHandler { call, result -> displayModes.handle(call, result) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEMORY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMemoryInfo") {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val memoryInfo = ActivityManager.MemoryInfo()
                activityManager.getMemoryInfo(memoryInfo)
                result.success(
                    mapOf(
                        "totalMemBytes" to memoryInfo.totalMem,
                        "isLowRamDevice" to activityManager.isLowRamDevice
                    )
                )
            } else {
                result.notImplemented()
            }
        }

        // Is this actually a television? Asked because the previous
        // "auto" layout heuristic compared MediaQuery width against a
        // fixed logical-pixel threshold, and a 1080p TV running at 2x
        // density reports 960dp — under the threshold — so every Android
        // TV box and Fire Stick silently got the phone layout on first
        // launch. Screen size cannot distinguish a TV from a tablet;
        // Android's own UI mode can.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isTelevision") {
                val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                val isTvUiMode = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                // Leanback is what a TV launcher requires of an app, and is
                // present on Fire TV even where the UI mode is reported
                // inconsistently, so either signal is enough.
                val hasLeanback =
                    packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                        packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
                result.success(isTvUiMode || hasLeanback)
            } else if (call.method == "sdkInt") {
                result.success(Build.VERSION.SDK_INT)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestInstalls" -> {
                    // Only a real gate on Android 8 (API 26)+ — earlier
                    // versions have no per-app "unknown sources" toggle at
                    // all, installing from any source just works.
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }
                "requestInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("NO_PATH", "filePath argument missing", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
