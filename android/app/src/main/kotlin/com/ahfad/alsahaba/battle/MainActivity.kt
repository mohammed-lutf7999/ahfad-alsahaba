package com.ahfad.alsahaba.battle

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            enableEdgeToEdge(
                statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
                navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            )
        } else {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        super.onCreate(savedInstanceState)
        // Re-apply after FlutterFragmentActivity.onCreate because Flutter embedding
        // sets legacy status bar flags/scrim inside private configureStatusBarForFullscreenFlutterExperience.
        configureEdgeToEdge()
    }

    private fun configureEdgeToEdge() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            // Avoid calling activity-ktx 1.10.1 EdgeToEdgeApi29 deprecated bar color setters on API 35+.
            WindowCompat.setDecorFitsSystemWindows(window, false)
            window.isNavigationBarContrastEnforced = false
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            }
            WindowInsetsControllerCompat(window, window.decorView).apply {
                isAppearanceLightStatusBars = false
                isAppearanceLightNavigationBars = false
            }
        } else {
            enableEdgeToEdge(
                statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
                navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            )
        }
    }
}

