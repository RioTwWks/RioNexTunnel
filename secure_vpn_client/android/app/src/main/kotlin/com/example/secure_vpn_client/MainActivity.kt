package com.example.secure_vpn_client

import android.content.Intent
import com.example.v2ray_box.V2rayBoxPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handleQuickConnectIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleQuickConnectIntent(intent)
    }

    private fun handleQuickConnectIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(V2rayBoxPlugin.EXTRA_QUICK_CONNECT, false) == true) {
            V2rayBoxPlugin.markPendingQuickConnect()
            intent.removeExtra(V2rayBoxPlugin.EXTRA_QUICK_CONNECT)
        }
    }
}
