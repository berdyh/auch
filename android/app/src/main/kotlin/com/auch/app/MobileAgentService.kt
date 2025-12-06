package com.auch.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.accessibilityservice.GestureDescription.StrokeDescription
import android.accessibilityservice.AccessibilityService.ScreenshotResult
import android.accessibilityservice.AccessibilityService.TakeScreenshotCallback
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import android.hardware.display.DisplayManager
import android.view.Display
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Accessibility service providing "eyes and hands" for the agent.
 */
class MobileAgentService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: MobileAgentService? = null
            private set

        val isRunning: Boolean
            get() = instance != null
    }

    private var tapHighlighter: TapHighlighter? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        tapHighlighter = TapHighlighter(this)
    }

    override fun onInterrupt() {
        // No-op
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        tapHighlighter?.destroy()
        tapHighlighter = null
    }

    fun captureState(): Map<String, Any> {
        val uiTree = buildUiTreeJson()
        val screenshotPath = captureScreenshot()
        return mapOf(
            "imagePath" to screenshotPath,
            "uiTree" to uiTree
        )
    }

    fun performAction(x: Int, y: Int): Boolean {
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        val stroke = StrokeDescription(path, 0, 50)
        tapHighlighter?.showTap(x, y)
        return dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    private fun buildUiTreeJson(): String {
        val root = rootInActiveWindow ?: return "[]"
        val nodes = JSONArray()
        var idCounter = 1

        fun traverse(node: AccessibilityNodeInfo?) {
            if (node == null) return

            val actionable = node.isClickable || node.isFocusable || node.isEditable
            if (actionable) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)

                val obj = JSONObject()
                obj.put("id", idCounter++)
                obj.put("class", node.className?.toString() ?: "")
                obj.put(
                    "text",
                    node.text?.toString()
                        ?.takeIf { it.isNotBlank() }
                        ?: node.contentDescription?.toString().orEmpty()
                )
                obj.put("bounds", JSONArray(listOf(bounds.left, bounds.top, bounds.width(), bounds.height())))
                nodes.put(obj)
            }

            for (i in 0 until node.childCount) {
                traverse(node.getChild(i))
            }
        }

        traverse(root)
        return nodes.toString()
    }

    private fun captureScreenshot(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            throw IllegalStateException("Screenshot capture requires Android 11+ (API 30+)")
        }

        val dm = getSystemService(DisplayManager::class.java)
        val activeDisplay: Display? = dm.getDisplay(Display.DEFAULT_DISPLAY)
        val displayId = activeDisplay?.displayId ?: display?.displayId
            ?: throw IllegalStateException("No active display available for screenshot")
        val executor = ContextCompat.getMainExecutor(this)
        val latch = CountDownLatch(1)
        var path: String? = null
        var failure: Exception? = null

        takeScreenshot(displayId, executor, object : TakeScreenshotCallback {
            override fun onSuccess(screenshot: ScreenshotResult) {
                try {
                    val bitmap = bitmapFromResult(screenshot)
                        ?: throw IllegalStateException("Failed to render screenshot")
                    val file = File(cacheDir, "last_capture.png")
                    FileOutputStream(file).use { fos ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos)
                    }
                    path = file.absolutePath
                } catch (e: Exception) {
                    failure = e
                } finally {
                    latch.countDown()
                }
            }

            override fun onFailure(errorCode: Int) {
                failure = IllegalStateException("Screenshot failed with code: $errorCode")
                latch.countDown()
            }
        })

        latch.await(3, TimeUnit.SECONDS)
        if (path != null) return path!!
        throw failure ?: IllegalStateException("Screenshot capture timed out")
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun bitmapFromResult(result: ScreenshotResult): Bitmap? {
        val buffer = result.hardwareBuffer
        val colorSpace = result.colorSpace
        val bitmap = Bitmap.wrapHardwareBuffer(buffer, colorSpace)?.copy(Bitmap.Config.ARGB_8888, false)
        buffer.close()
        return bitmap
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Intentionally minimal; the service is polled via MethodChannel.
    }
}
