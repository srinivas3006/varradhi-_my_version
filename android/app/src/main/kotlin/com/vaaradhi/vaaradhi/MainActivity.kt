package com.vaaradhi.vaaradhi

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var deepLinkChannel: MethodChannel? = null
    private var initialLinkConsumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val DEEP_LINK_CHANNEL = "com.vaaradhi.vaaradhi/deep_links"
    }
}
