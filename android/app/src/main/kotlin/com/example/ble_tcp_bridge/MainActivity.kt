package com.example.ble_tcp_bridge

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "tcp_foreground"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title") ?: "TCP server running"
                    val text = call.argument<String>("text") ?: ""
                    val bigText = call.argument<String>("bigText") ?: text
                    val intent = Intent(this, TcpForegroundService::class.java).apply {
                        action = TcpForegroundService.ACTION_START
                        putExtra(TcpForegroundService.EXTRA_TITLE, title)
                        putExtra(TcpForegroundService.EXTRA_TEXT, text)
                        putExtra(TcpForegroundService.EXTRA_BIG_TEXT, bigText)
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    val intent = Intent(this, TcpForegroundService::class.java).apply {
                        action = TcpForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                "update" -> {
                    val title = call.argument<String>("title") ?: "TCP server running"
                    val text = call.argument<String>("text") ?: ""
                    val bigText = call.argument<String>("bigText") ?: text
                    val intent = Intent(this, TcpForegroundService::class.java).apply {
                        action = TcpForegroundService.ACTION_START
                        putExtra(TcpForegroundService.EXTRA_TITLE, title)
                        putExtra(TcpForegroundService.EXTRA_TEXT, text)
                        putExtra(TcpForegroundService.EXTRA_BIG_TEXT, bigText)
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}