// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.TileService
import android.util.AtomicFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/** Private, durable selected configuration; never depend on a Flutter session file.
 * All entry points and state transitions run on the main thread. Core work stays
 * on VpnRuntime.worker. The saved config is never put in an exported intent.
 */
internal object QuickSettings {
    data class Selection(val config: String, val core: String, val name: String, val host: String)
    private var context: Context? = null
    private var loaded = false
    private var selection: Selection? = null
    var busy = false
        private set
    var activeName: String? = null
        private set

    private fun file(context: Context) = AtomicFile(File(context.filesDir, "settings/quick-settings.json"))

    fun initialize(value: Context) {
        context = value.applicationContext
        if (loaded) return
        loaded = true
        selection = runCatching {
            val store = file(value)
            check(store.baseFile.length() <= 1024 * 1024)
            val saved = JSONObject(String(store.readFully(), Charsets.UTF_8))
            check(saved.getInt("schema") == 1)
            Selection(saved.getString("config"), saved.getString("core"), saved.getString("name"), saved.getString("host"))
                .also { check(it.core in setOf("singBox", "xray")) }
        }.getOrNull()
    }

    fun refresh() {
        val app = context ?: return
        runCatching { TileService.requestListeningState(app, ComponentName(app, AoraTileService::class.java)) }
    }

    fun configured() = selection != null

    fun releaseActivity() {
        busy = false
        refresh()
    }

    fun handle(activity: MainActivity, call: MethodCall, result: MethodChannel.Result) {
        initialize(activity)
        when (call.method) {
            "busy" -> {
                val expected = call.argument<String>("expectedState")
                if (call.argument<Boolean>("busy") == true && expected != null && expected != VpnRuntime.state) {
                    result.error("BUSY", "VPN state changed. Wait for the connection status to update.", null)
                    return
                }
                busy = call.argument<Boolean>("busy") == true
                refresh()
                result.success(null)
            }
            "save" -> {
                try {
                    val config = call.argument<String>("config")
                    val next = if (config == null) null else Selection(config,
                        call.argument<String>("core") ?: error("Missing core"),
                        (call.argument<String>("name") ?: "Selected server").take(100),
                        call.argument<String>("host") ?: error("Missing server"))
                    val store = file(activity)
                    if (next == null) store.delete() else {
                        check(next.core in setOf("singBox", "xray") && next.host.isNotBlank())
                        val data = JSONObject().put("schema", 1).put("config", next.config)
                            .put("core", next.core).put("name", next.name).put("host", next.host).toString().toByteArray()
                        check(data.size <= 1024 * 1024) { "Configuration is too large" }
                        store.baseFile.parentFile!!.mkdirs()
                        val stream = store.startWrite()
                        try { stream.write(data); store.finishWrite(stream) }
                        catch (error: Exception) { store.failWrite(stream); throw error }
                    }
                    selection = next
                    if (VpnRuntime.state == "running" && VpnRuntime.coreKind == next?.core) activeName = next.name
                    refresh()
                    result.success(null)
                } catch (_: Exception) {
                    // Never retain a stale server or stale routing rules after a failed save.
                    selection = null
                    file(activity).delete()
                    refresh()
                    result.error("TILE_SAVE", "Could not save Quick Settings configuration.", null)
                }
            }
            "addTile" -> {
                if (Build.VERSION.SDK_INT < 33) { result.success("manual"); return }
                try {
                    activity.getSystemService(StatusBarManager::class.java).requestAddTileService(
                        ComponentName(activity, AoraTileService::class.java), "AORA Connect",
                        Icon.createWithResource(activity, R.drawable.ic_quick_settings), activity.mainExecutor
                    ) { code -> result.success(when (code) {
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "alreadyAdded"
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "declined"
                        else -> "failed"
                    }) }
                } catch (_: RuntimeException) {
                    result.error("TILE_ADD", "Could not show the Quick Settings tile prompt.", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun connect(context: Context, result: MethodChannel.Result) {
        initialize(context)
        val current = selection
        if (QuickSettingsState.action(VpnRuntime.state, busy, current != null) != QuickSettingsState.Action.CONNECT || current == null) {
            result.error("BUSY", "Open AORA Connect to select a server or wait for the current operation.", null)
            return
        }
        activeName = current.name
        VpnRuntime.start(context, current.config, current.core, result, current.host, verify = true)
    }
}
