package com.kazuki.zhulihotwater

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import android.graphics.Color
import android.view.View
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.kazuki.zhulihotwater.runtime.ShuiRuntimeController
import com.kazuki.zhulihotwater.ui.ShuiApp
import com.kazuki.zhulihotwater.ui.ShuiTheme

class MainActivity : ComponentActivity() {
    private var runtimeController: ShuiRuntimeController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureSystemBars()
        val runtime = ShuiRuntimeController.create(this)
        runtimeController = runtime
        setContent {
            ShuiTheme {
                ShuiApp(runtime = runtime)
            }
        }
        handleLegacyDebugIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLegacyDebugIntent(intent)
    }

    override fun onDestroy() {
        runtimeController?.close()
        runtimeController = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        configureSystemBars()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            configureSystemBars()
        }
    }

    private fun configureSystemBars() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        window.decorView.systemUiVisibility =
            window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
        WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_DEFAULT
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }
    }

    private fun handleLegacyDebugIntent(intent: Intent?) {
        val openLegacy = intent?.getBooleanExtra(EXTRA_OPEN_LEGACY_HOTWATER, false) == true ||
            intent?.action == ACTION_OPEN_LEGACY_HOTWATER
        if (openLegacy) {
            intent?.removeExtra(EXTRA_OPEN_LEGACY_HOTWATER)
        }
    }

    companion object {
        const val EXTRA_OPEN_LEGACY_HOTWATER = "com.kazuki.zhulihotwater.OPEN_LEGACY_HOTWATER"
        const val ACTION_OPEN_LEGACY_HOTWATER = "com.kazuki.zhulihotwater.action.OPEN_LEGACY_HOTWATER"
    }
}
