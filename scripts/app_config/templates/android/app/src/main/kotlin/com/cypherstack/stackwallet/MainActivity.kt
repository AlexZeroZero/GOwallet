package com.place.holder

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterFragmentActivity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.os.Build
import android.view.MotionEvent
import android.view.WindowManager
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "STACK_WALLET_RESTORE"

    var openPath: String? = null
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getOpenFile" -> {
                    result.success(openPath)
                }
                "resetOpenPath" -> {
                    resetOpenPath()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun resetOpenPath() {
        openPath = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Protect wallet screens from screenshots, screen recording and recents.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        window.decorView.filterTouchesWhenObscured = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.setHideOverlayWindows(true)
        }
        handleOpenFile(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleOpenFile(intent)
    }

    // Backups are imported deliberately with the in-app system file picker.
    // Never open an attacker-controlled provider while handling a launch intent.
    private fun handleOpenFile(intent: Intent?) {
        openPath = null
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        val obscured = event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0
        val partiallyObscured = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0
        if (obscured || partiallyObscured) return false
        return super.dispatchTouchEvent(event)
    }
}
