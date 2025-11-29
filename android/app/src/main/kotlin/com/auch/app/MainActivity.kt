package com.auch.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.minitap.device/agent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isServiceActive" -> {
                    result.success(MobileAgentService.instance != null)
                }
                "captureState" -> {
                    val service = MobileAgentService.instance
                    if (service != null) {
                        service.captureState { imagePath, uiTree ->
                            if (imagePath.isNotEmpty()) {
                                val response = HashMap<String, String>()
                                response["imagePath"] = imagePath
                                response["uiTree"] = uiTree
                                runOnUiThread {
                                    result.success(response)
                                }
                            } else {
                                runOnUiThread {
                                    result.error("CAPTURE_FAILED", "Failed to take screenshot", null)
                                }
                            }
                        }
                    } else {
                        result.error("SERVICE_OFF", "Accessibility Service is not enabled", null)
                    }
                }
                "performAction" -> {
                    val x = call.argument<Int>("x")
                    val y = call.argument<Int>("y")
                    val service = MobileAgentService.instance

                    if (service != null && x != null && y != null) {
                        service.performAction(x, y) { success ->
                            runOnUiThread {
                                result.success(success)
                            }
                        }
                    } else {
                         result.error("INVALID_ARGS", "Service off or missing coords", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
