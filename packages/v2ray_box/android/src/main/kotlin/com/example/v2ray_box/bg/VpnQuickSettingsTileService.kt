package com.example.v2ray_box.bg

import android.os.Build
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class VpnQuickSettingsTileService : TileService() {

    override fun onStartListening() {
        qsTile?.let { QuickSettingsTileHelper.applyState(it, applicationContext) }
    }

    override fun onClick() {
        unlockAndRun {
            QuickSettingsTileHelper.handleClick(applicationContext)
        }
    }
}
