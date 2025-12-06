package com.auch.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import kotlin.math.roundToInt

/**
 * Lightweight overlay that shows a transient visual marker
 * anywhere on the screen, even when the Flutter UI is backgrounded.
 */
class TapHighlighter(service: AccessibilityService) {
    private val appContext = service.applicationContext
    private val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private var overlayView: View? = null

    fun showTap(x: Int, y: Int) {
        handler.post {
            remove()
            val overlay = LayoutInflater.from(appContext).inflate(R.layout.tap_overlay, null)
            val sizePx = (88 * appContext.resources.displayMetrics.density).roundToInt()

            val params = WindowManager.LayoutParams(
                sizePx,
                sizePx,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                this.x = x - (sizePx / 2)
                this.y = y - (sizePx / 2)
            }

            overlay.alpha = 0f
            overlay.scaleX = 0.85f
            overlay.scaleY = 0.85f

            windowManager.addView(overlay, params)
            overlayView = overlay

            // Brief pulse animation then auto-dismiss
            overlay.animate()
                .alpha(1f)
                .scaleX(1.05f)
                .scaleY(1.05f)
                .setDuration(120)
                .withEndAction {
                    overlay.animate()
                        .alpha(0f)
                        .scaleX(1.3f)
                        .scaleY(1.3f)
                        .setDuration(520)
                        .withEndAction { remove() }
                        .start()
                }
                .start()

            handler.postDelayed({ remove() }, 900)
        }
    }

    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        remove()
    }

    private fun remove() {
        overlayView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {
                // View may already be removed; ignore.
            }
            overlayView = null
        }
    }
}
