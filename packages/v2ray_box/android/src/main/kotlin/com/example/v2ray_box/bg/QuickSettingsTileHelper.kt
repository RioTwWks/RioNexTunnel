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
import org.json.JSONArray

/**
 * State + click handling for the Quick Settings VPN tile (Pixel-style QS tiles).
 */
object QuickSettingsTileHelper {
    private const val TAG = "V2Ray/QSTile"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_SELECTED_PROFILE = "flutter.selected_profile_id"
    private const val KEY_PROFILES = "flutter.vpn_profiles"

    @Volatile
    var hasProfile: Boolean = false

    @Volatile
    var profileName: String = ""

    fun refreshProfileStateFromPrefs(context: Context) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val selectedId = prefs.getString(KEY_SELECTED_PROFILE, null)?.trim().orEmpty()
        if (selectedId.isEmpty()) {
            updateProfileState(hasProfile = false, profileName = "")
            return
        }
        val profilesJson = prefs.getString(KEY_PROFILES, null)
        val name = parseProfileName(profilesJson, selectedId)
        updateProfileState(hasProfile = true, profileName = name)
    }

    private fun parseProfileName(profilesJson: String?, selectedId: String): String {
        if (profilesJson.isNullOrBlank()) {
            return ""
        }
        return runCatching {
            val array = JSONArray(profilesJson)
            for (index in 0 until array.length()) {
                val profile = array.getJSONObject(index)
                if (profile.optString("id") == selectedId) {
                    return profile.optString("name", "")
                }
            }
            ""
        }.getOrDefault("")
    }

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
        refreshProfileStateFromPrefs(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            tile.icon = Icon.createWithResource(context, R.drawable.ic_vpn_tile)
        }
        val status = V2rayBoxPlugin.currentServiceStatus()
        when {
            !hasProfile -> {
                // INACTIVE (not UNAVAILABLE) so short-tap still reaches onClick().
                tile.state = Tile.STATE_INACTIVE
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
        refreshProfileStateFromPrefs(context)
        val status = V2rayBoxPlugin.currentServiceStatus()
        val action = when (status) {
            Status.Started, Status.Starting, Status.Stopping -> "disconnect"
            else -> "connect"
        }
        Log.i(TAG, "tile click action=$action hasProfile=$hasProfile status=$status")
        if (action == "connect" && !hasProfile) {
            V2rayBoxPlugin.openAppForQuickAction(context)
            return
        }
        V2rayBoxPlugin.dispatchQuickSettingsTileAction(action)
    }
}
