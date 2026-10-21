// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.app.Activity
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Bundle
import android.os.Build
import android.widget.Toast
import io.flutter.plugin.common.MethodChannel

/** Non-exported permission bridge: another app cannot trigger a VPN connection. */
class TilePermissionActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        if (state != null) return // Android restores the outstanding permission activity.
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 701)
        } else prepareVpn()
    }
    private fun prepareVpn() {
        val permission = VpnService.prepare(this)
        if (permission == null) connect() else startActivityForResult(permission, 702)
    }
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == 701) prepareVpn()
    }
    override fun onActivityResult(code: Int, result: Int, data: Intent?) {
        super.onActivityResult(code, result, data)
        if (code != 702) return
        if (result == RESULT_OK) connect() else finish()
    }
    private fun connect() {
        QuickSettings.connect(this, object : MethodChannel.Result {
            override fun success(result: Any?) { finish() }
            override fun error(code: String, message: String?, details: Any?) {
                VpnRuntime.log("Quick Settings connection failed: ${message ?: code}")
                Toast.makeText(applicationContext, AppLanguage.text(applicationContext, R.string.vpn_tile_failed), Toast.LENGTH_LONG).show()
                finish()
            }
            override fun notImplemented() { finish() }
        })
        // The service owns startup. Do not leave an empty activity covering the screen.
        finish()
    }
}
