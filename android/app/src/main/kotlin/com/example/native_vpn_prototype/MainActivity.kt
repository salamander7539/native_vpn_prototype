package com.example.native_vpn_prototype

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val methodChannelName = "com.osman.vpn/commands"
    private val eventChannelName = "com.osman.vpn/status"

    companion object {
        private var eventSink: EventChannel.EventSink? = null
        fun sendEventToFlutter(type: String, data: String) {
            eventSink?.success(mapOf("type" to type, "data" to data))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivityForResult(intent, 0)
                        result.success(null)
                    } else {
                        val serviceIntent = Intent(this, MyVpnService::class.java).apply {
                            action = MyVpnService.ACTION_START
                            putExtra("serverIp", call.argument<String>("serverIp"))
                            putExtra("dns", call.argument<String>("dns"))
                        }
                        startService(serviceIntent)
                        result.success(null)
                    }
                }
                "stopVpn" -> {
                    val serviceIntent = Intent(this, MyVpnService::class.java).apply {
                        action = MyVpnService.ACTION_STOP
                    }
                    startService(serviceIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    sendEventToFlutter("logMessage", "[Android] Платформенный мост готов к работе.")
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }
}
