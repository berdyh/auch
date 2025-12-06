package com.auch.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.minitap.device/agent"
    private val executor = Executors.newSingleThreadExecutor()

    override fun onDestroy() {
        super.onDestroy()
        executor.shutdown()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isServiceActive" -> {
                        result.success(MobileAgentService.isRunning)
                    }
                    "checkAccessibilityEnabled" -> {
                        result.success(MobileAgentService.isRunning)
                    }
                    "startForegroundService" -> {
                        AgentForegroundService.start(this)
                        result.success(true)
                    }
                    "updateForegroundStatus" -> {
                        val status = call.argument<String>("status") ?: "Agent running"
                        AgentForegroundService.updateStatus(this, status)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        AgentForegroundService.stop(this)
                        result.success(true)
                    }
                    "captureState" -> {
                        executor.execute {
                            val service = MobileAgentService.instance
                            if (service == null) {
                                runOnUiThread { result.error("NO_SERVICE", "Accessibility service inactive", null) }
                                return@execute
                            }
                            try {
                                val data = service.captureState()
                                runOnUiThread { result.success(data) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("CAPTURE_ERROR", e.message, null) }
                            }
                        }
                    }
                    "performAction" -> {
                        val x = call.argument<Int>("x")
                        val y = call.argument<Int>("y")
                        if (x == null || y == null) {
                            result.error("BAD_ARGS", "Missing coordinates", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            val service = MobileAgentService.instance
                            if (service == null) {
                                runOnUiThread { result.error("NO_SERVICE", "Accessibility service inactive", null) }
                                return@execute
                            }
                            val success = service.performAction(x, y)
                            runOnUiThread { result.success(success) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
