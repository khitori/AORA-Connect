// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast
import io.flutter.plugin.common.MethodChannel

class AoraTileService : TileService() {
    override fun onCreate() {
        super.onCreate()
        QuickSettings.initialize(this)
    }
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val status = QuickSettingsState.subtitle(VpnRuntime.state, QuickSettings.busy, QuickSettings.activeName, AppLanguage.tileLabels(this))
        tile.icon = Icon.createWithResource(this, R.drawable.ic_quick_settings)
        val appName = applicationInfo.loadLabel(packageManager).toString()
        tile.label = if (Build.VERSION.SDK_INT >= 29) appName else "$appName · $status"
        if (Build.VERSION.SDK_INT >= 29) tile.subtitle = status
        tile.contentDescription = "$appName, $status"
        tile.state = when {
            QuickSettings.busy || VpnRuntime.state in setOf("starting", "stopping") -> Tile.STATE_UNAVAILABLE
            VpnRuntime.state == "running" -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        tile.updateTile()
    }
    override fun onClick() {
        super.onClick()
        if (isLocked) unlockAndRun { toggle() } else toggle()
    }
    private fun toggle() {
        when (QuickSettingsState.action(VpnRuntime.state, QuickSettings.busy, QuickSettings.configured())) {
            QuickSettingsState.Action.WAIT -> return
            QuickSettingsState.Action.DISCONNECT -> VpnRuntime.stop(this)
            QuickSettingsState.Action.OPEN_APP -> open(MainActivity::class.java)
            QuickSettingsState.Action.CONNECT -> {
                if (VpnService.prepare(this) != null) open(TilePermissionActivity::class.java)
                else QuickSettings.connect(this, object : MethodChannel.Result {
                    override fun success(result: Any?) { QuickSettings.refresh() }
                    override fun error(code: String, message: String?, details: Any?) {
                        VpnRuntime.log("Quick Settings connection failed: ${message ?: code}")
                        Toast.makeText(applicationContext, AppLanguage.text(applicationContext, R.string.vpn_tile_failed), Toast.LENGTH_LONG).show()
                        QuickSettings.refresh()
                    }
                    override fun notImplemented() { QuickSettings.refresh() }
                })
            }
        }
    }
    @Suppress("DEPRECATION")
    private fun open(activity: Class<*>) {
        val intent = Intent(this, activity).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) startActivityAndCollapse(PendingIntent.getActivity(
            this, 40, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        else startActivityAndCollapse(intent)
    }
}
