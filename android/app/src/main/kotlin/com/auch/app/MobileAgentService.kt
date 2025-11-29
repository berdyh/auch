package com.auch.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executor
import java.util.concurrent.Executors

class MobileAgentService : AccessibilityService() {

    companion object {
        var instance: MobileAgentService? = null
    }

    private val executor: Executor = Executors.newSingleThreadExecutor()

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op
    }

    override fun onInterrupt() {
        // No-op
    }

    fun captureState(callback: (String, String) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                executor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        val bitmap = Bitmap.wrapHardwareBuffer(
                            screenshot.hardwareBuffer,
                            screenshot.colorSpace
                        )
                        val file = File(cacheDir, "screenshot_${System.currentTimeMillis()}.png")
                        FileOutputStream(file).use { out ->
                            bitmap?.compress(Bitmap.CompressFormat.PNG, 100, out)
                        }
                        bitmap?.recycle()
                        screenshot.hardwareBuffer.close()

                        val uiTree = getSimplifiedUiTree()
                        callback(file.absolutePath, uiTree)
                    }

                    override fun onFailure(errorCode: Int) {
                        callback("", "[]") // Failed
                    }
                }
            )
        } else {
            // Fallback or error for older APIs (MVP targets API 30+)
            callback("", "[]")
        }
    }

    private fun getSimplifiedUiTree(): String {
        val root = rootInActiveWindow ?: return "[]"
        val nodes = JSONArray()
        try {
            traverseNode(root, nodes)
        } finally {
            root.recycle()
        }
        return nodes.toString()
    }

    private fun traverseNode(node: AccessibilityNodeInfo, nodes: JSONArray) {
        if (node.isClickable || node.isEditable || node.isCheckable) {
            val rect = Rect()
            node.getBoundsInScreen(rect)

            // Filter out off-screen or tiny elements
            if (rect.width() > 0 && rect.height() > 0) {
                val nodeJson = JSONObject()
                // Use hashCode as a simple stable ID for this session/frame
                nodeJson.put("id", node.hashCode())
                nodeJson.put("class", node.className)
                nodeJson.put("text", node.text ?: node.contentDescription ?: "")

                val bounds = JSONArray()
                bounds.put(rect.left)
                bounds.put(rect.top)
                bounds.put(rect.width())
                bounds.put(rect.height())
                nodeJson.put("bounds", bounds)

                nodes.put(nodeJson)
            }
        }

        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                traverseNode(child, nodes)
                child.recycle()
            }
        }
    }

    fun performAction(x: Int, y: Int, callback: (Boolean) -> Unit) {
        val path = Path()
        path.moveTo(x.toFloat(), y.toFloat())
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()

        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                callback(true)
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                callback(false)
            }
        }, null)
    }
}
