package com.example.v2ray_box.bg

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi
import com.example.v2ray_box.R
import com.example.v2ray_box.V2rayBoxPlugin
import com.example.v2ray_box.constant.Status

/**
 * State + click handling for the Quick Settings VPN tile (Pixel-style QS tiles).
 */
object QuickSettingsTileHelper {
    private const val TAG = "V2Ray/QSTile"

    @Volatile
    var hasProfile: Boolean = false

    @Volatile
    var profileName: String = ""

    fun updateProfileState(hasProfile: Boolean, profileName: String) {
        this.hasProfile = hasProfile
        this.profileName = profileName.trim()
        requestTileRefresh()
    }

    fun requestTileRefresh() {
        val context = V2rayBoxPlugin.applicationContext ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return
        }
        runCatching {
            val component = ComponentName(context, VpnQuickSettingsTileService::class.java)
            TileService.requestListeningState(context, component)
        }.onFailure { error ->
            Log.w(TAG, "requestListeningState failed: ${error.message}")
        }
    }

    @RequiresApi(Build.VERSION_CODES.N)
    fun applyState(tile: Tile, context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            tile.icon = Icon.createWithResource(context, R.drawable.ic_vpn_tile)
        }
        val status = V2rayBoxPlugin.currentServiceStatus()
        when {
            !hasProfile -> {
                tile.state = Tile.STATE_UNAVAILABLE
                tile.label = context.getString(R.string.quick_settings_tile_label)
                tile.subtitle = context.getString(R.string.quick_settings_tile_no_profile)
            }

            status == Status.Started -> {
                tile.state = Tile.STATE_ACTIVE
                tile.label = profileName.ifBlank { context.getString(R.string.quick_settings_tile_label) }
                tile.subtitle = context.getString(R.string.quick_settings_tile_connected)
            }

            status == Status.Starting || status == Status.Stopping -> {
                tile.state = Tile.STATE_ACTIVE
                tile.label = profileName.ifBlank { context.getString(R.string.quick_settings_tile_label) }
                tile.subtitle = context.getString(R.string.quick_settings_tile_connecting)
            }

            else -> {
                tile.state = Tile.STATE_INACTIVE
                tile.label = profileName.ifBlank { context.getString(R.string.quick_settings_tile_label) }
                tile.subtitle = context.getString(R.string.quick_settings_tile_connect)
            }
        }
        tile.updateTile()
    }

    fun handleClick(context: Context) {
        val status = V2rayBoxPlugin.currentServiceStatus()
        val action = when (status) {
            Status.Started, Status.Starting, Status.Stopping -> "disconnect"
            else -> "connect"
        }
        if (action == "connect" && !hasProfile) {
            Log.i(TAG, "Quick Settings tile ignored: no profile selected")
            V2rayBoxPlugin.openAppForQuickAction(context)
            return
        }
        V2rayBoxPlugin.dispatchQuickSettingsTileAction(action)
    }
}
