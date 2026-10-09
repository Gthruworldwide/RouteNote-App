package com.routenote.routenote

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth, which
// shows the system BiometricPrompt as a fragment.
class MainActivity : FlutterFragmentActivity() {
    private var shortcutsChannel: MethodChannel? = null
    private var pendingPlaceId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHORTCUT_CHANNEL,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPin" -> {
                    val id = call.argument<String>("id")
                    val label = call.argument<String>("label")
                    if (id.isNullOrBlank() || label.isNullOrBlank()) {
                        result.error("invalid_args", "id and label are required", null)
                    } else {
                        result.success(requestPinShortcut(id, label))
                    }
                }
                "getInitialPlaceId" -> {
                    val id = pendingPlaceId
                    pendingPlaceId = null
                    result.success(id)
                }
                else -> result.notImplemented()
            }
        }
        shortcutsChannel = channel

        // The app may have been launched cold from a pinned shortcut.
        capturePlaceId(intent, notifyDart = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capturePlaceId(intent, notifyDart = true)
    }

    private fun capturePlaceId(intent: Intent?, notifyDart: Boolean) {
        val id = intent?.getStringExtra(EXTRA_PLACE_ID) ?: return
        if (notifyDart) {
            shortcutsChannel?.invokeMethod("onShortcutTap", id)
        } else {
            pendingPlaceId = id
        }
    }

    private fun requestPinShortcut(id: String, label: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(ShortcutManager::class.java) ?: return false
        if (!manager.isRequestPinShortcutSupported) return false

        val shortcutIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_OPEN_PLACE
            putExtra(EXTRA_PLACE_ID, id)
        }
        val shortcut = ShortcutInfo.Builder(this, "place_$id")
            .setShortLabel(label.take(40))
            .setLongLabel(label)
            .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(shortcutIntent)
            .build()

        manager.requestPinShortcut(shortcut, null)
        return true
    }

    companion object {
        private const val SHORTCUT_CHANNEL = "com.routenote.routenote/shortcuts"
        private const val EXTRA_PLACE_ID = "com.routenote.routenote.PLACE_ID"
        private const val ACTION_OPEN_PLACE = "com.routenote.routenote.OPEN_PLACE"
    }
}
