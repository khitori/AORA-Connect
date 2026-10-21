// SPDX-License-Identifier: GPL-3.0-or-later

package aora.aoranet.aoravpn

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build

class MainActivity : FlutterActivity() {
    private lateinit var updates: AndroidUpdates
    private data class PermissionRequest(val config: String, val core: String, val result: MethodChannel.Result)
    private var permissionRequest: PermissionRequest? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        QuickSettings.initialize(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aora/localization")
            .setMethodCallHandler { call, result ->
                if (call.method != "setLanguage") result.notImplemented()
                else {
                    val language = call.arguments as? String
                    if (language != null && language !in AppLanguage.languages) {
                        result.error("LANGUAGE", "Unsupported language", null)
                    } else {
                        AppLanguage.select(applicationContext, language)
                        result.success(null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aora/quick_settings")
            .setMethodCallHandler { call, result -> QuickSettings.handle(this, call, result) }
        updates = AndroidUpdates(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aora/updates")
            .setMethodCallHandler { call, result -> updates.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aora/applications")
            .setMethodCallHandler { call, result ->
                if (call.method == "listInstalled") InstalledApplications.load(applicationContext, result)
                else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aoravpn/app_data")
            .setMethodCallHandler { call, result ->
                if (call.method == "filesDirectory") {
                    result.success(filesDir.absolutePath)
                } else {
                    result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "aora/vpn/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) { VpnRuntime.listen(events) }
                override fun onCancel(arguments: Any?) { VpnRuntime.listen(null) }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aora/vpn")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(if ((call.argument<String>("core") ?: "singBox") == VpnRuntime.coreKind) VpnRuntime.state else "stopped")
                    "validate" -> VpnRuntime.validate(this, call.argument<String>("config")!!, call.argument<String>("core") ?: "singBox", result)
                    "diagnostics" -> result.success(VpnRuntime.diagnostics(applicationContext))
                    "reportDetails" -> result.success(VpnRuntime.reportDetails(applicationContext))
                    "start" -> {
                        if (permissionRequest != null) result.error("BUSY", "A permission request is already open.", null)
                        else {
                            permissionRequest = PermissionRequest(call.argument<String>("config")!!, call.argument<String>("core") ?: "singBox", result)
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                                != PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 701)
                            } else prepareVpn()
                        }
                    }
                    "stop" -> {
                        permissionRequest?.result?.error("CANCELLED", "Connection cancelled.", null)
                        permissionRequest = null
                        if ((call.argument<String>("core") ?: VpnRuntime.coreKind) == VpnRuntime.coreKind) VpnRuntime.stop(this, result)
                        else result.success(null)
                    }
                    "ping", "resolve", "openPingBatch", "checkPingBatch", "closePingBatch" -> AndroidChecks.handle(applicationContext, call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun prepareVpn() {
        val permission = VpnService.prepare(this)
        if (permission == null) startVpn()
        else startActivityForResult(permission, 702)
    }

    private fun startVpn() {
        val request = permissionRequest ?: return
        permissionRequest = null
        VpnRuntime.start(this, request.config, request.core, request.result)
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == 701 && permissionRequest != null) prepareVpn()
    }

    override fun onActivityResult(code: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(code, resultCode, data)
        if (::updates.isInitialized && updates.onActivityResult(code, resultCode)) return
        if (code != 702) return
        if (resultCode == RESULT_OK) startVpn()
        else {
            permissionRequest?.result?.error("PERMISSION", "VPN permission was not granted.", null)
            permissionRequest = null
        }
    }

    override fun onDestroy() {
        if (::updates.isInitialized) updates.close()
        QuickSettings.releaseActivity()
        super.onDestroy()
    }
}
