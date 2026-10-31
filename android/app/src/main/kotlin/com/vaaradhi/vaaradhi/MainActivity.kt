package com.vaaradhi.vaaradhi

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Edge-to-edge on every Android version, as Android 15+ already
        // enforces for apps targeting SDK 35+ (Play Console). Flutter's
        // SafeArea / MediaQuery padding keep content clear of the bars.
        //
        // WindowCompat, not androidx.activity's enableEdgeToEdge(): that one
        // calls Window.setStatusBarColor / setNavigationBarColor on older
        // versions, which Play reports as deprecated Android 15 APIs.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    private var deepLinkChannel: MethodChannel? = null
    private var initialLinkConsumed = false
    private var watermarkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerWatermark(flutterEngine)
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEEP_LINK_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    val initialLink = if (initialLinkConsumed) null else intent?.dataString
                    initialLinkConsumed = true
                    result.success(initialLink)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    private fun registerWatermark(flutterEngine: FlutterEngine) {
        val watermarker = VideoWatermarker(applicationContext)
        watermarkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WATERMARK_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "watermark") {
                    val input = call.argument<String>("input")
                    val output = call.argument<String>("output")
                    val label = call.argument<String>("label") ?: "Vaaradhi"
                    if (input == null || output == null) {
                        result.error("bad_args", "input and output are required", null)
                    } else {
                        watermarker.handle(input, output, label, result)
                    }
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        initialLinkConsumed = true
        intent.dataString?.let { deepLink ->
            deepLinkChannel?.invokeMethod("onDeepLink", deepLink)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        deepLinkChannel?.setMethodCallHandler(null)
        deepLinkChannel = null
        watermarkChannel?.setMethodCallHandler(null)
        watermarkChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val DEEP_LINK_CHANNEL = "com.vaaradhi.vaaradhi/deep_links"
        private const val WATERMARK_CHANNEL = "com.vaaradhi.vaaradhi/video_watermark"
    }
}
