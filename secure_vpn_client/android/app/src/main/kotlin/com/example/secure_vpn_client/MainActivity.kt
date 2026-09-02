package com.example.secure_vpn_client

import android.content.Intent
import com.example.v2ray_box.V2rayBoxPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handleQuickTileIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleQuickTileIntent(intent)
    }

    private fun handleQuickTileIntent(intent: Intent?) {
        val action = intent?.getStringExtra(V2rayBoxPlugin.EXTRA_QUICK_TILE_ACTION)
        if (!action.isNullOrBlank()) {
            V2rayBoxPlugin.markPendingTileAction(action)
            intent.removeExtra(V2rayBoxPlugin.EXTRA_QUICK_TILE_ACTION)
        }
    }
}
