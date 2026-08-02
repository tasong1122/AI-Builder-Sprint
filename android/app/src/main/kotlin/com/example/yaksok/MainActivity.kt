package com.example.yaksok

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val contractLinkChannel = "lov/contract_link"
    private var initialContractLink: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        initialContractLink = intent?.dataString
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        initialContractLink = intent.dataString
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, contractLinkChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(initialContractLink)
                    initialContractLink = null
                } else {
                    result.notImplemented()
                }
            }
    }
}
