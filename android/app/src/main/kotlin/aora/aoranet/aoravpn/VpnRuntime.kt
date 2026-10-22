// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import go.Seq
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import io.nekohasekai.mobile.Mobile
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

internal object VpnRuntime {
    val worker = Executors.newSingleThreadExecutor { Thread(it, "aora-vpn") }
    val main = Handler(Looper.getMainLooper())
    @Volatile var state = "stopped"
        private set
    @Volatile var cancelled = false
    @Volatile var generation = 0L
        private set
    @Volatile var service: AoraVpnService? = null
    @Volatile var coreKind = "singBox"
        private set
    private var ready = false
    private var sink: EventChannel.EventSink? = null
    private var pendingStart: MethodChannel.Result? = null
    private val history = ArrayDeque<String>()
    private val ansi = Regex("\u001B\\[[0-9;]*m")
    @Volatile private var lastCoreError: String? = null

    @Synchronized fun initialize(context: Context) {
        if (ready) return
        Seq.setContext(context.applicationContext)
        val directory = File(context.filesDir, "runtime/android-core").apply { mkdirs() }
        Libbox.setup(SetupOptions().apply {
            basePath = directory.absolutePath
            workingPath = directory.absolutePath
            tempPath = context.cacheDir.absolutePath
            commandServerSecret = UUID.randomUUID().toString()
            logMaxLines = 128
            crashReportSource = "aora"
            fixAndroidStack = true
        })
        Mobile.configure(AndroidNetwork(context.applicationContext))
        ready = true
    }

    fun listen(events: EventChannel.EventSink?) {
        sink = events
        events?.success(mapOf("state" to state, "core" to coreKind))
        history.forEach { events?.success(mapOf("log" to it, "core" to coreKind)) }
    }

    fun update(value: String) {
        state = value
        val core = coreKind
        main.post {
            sink?.success(mapOf("state" to value, "core" to core))
            QuickSettings.refresh()
        }
    }

    fun log(message: String) {
        val core = coreKind
        val line = ansi.replace(message, "").take(2048)
        if (line.startsWith("ERROR") || line.startsWith("FATAL")) lastCoreError = line
        main.post {
            if (history.size >= 128) history.removeFirst()
            history.addLast(line)
            sink?.success(mapOf("log" to line, "core" to core))
        }
    }

    fun start(context: Context, config: String, core: String, result: MethodChannel.Result,
              serverHost: String? = null, verify: Boolean = false) {
        if (state != "stopped") {
            result.error("BUSY", "Disconnect before starting another VPN session.", null)
            return
        }
        cancelled = false
        lastCoreError = null
        coreKind = core
        generation++
        pendingStart = result
        update("starting")
        try {
            context.startForegroundService(Intent(context, AoraVpnService::class.java)
                .putExtra("config", config).putExtra("core", core).putExtra("generation", generation)
                .putExtra("serverHost", serverHost).putExtra("verify", verify))
        } catch (error: Exception) {
            update("stopped")
            completeStart(error)
        }
    }

    fun diagnostics(context: Context): Map<String, String?> = mapOf(
        "network" to (PhysicalNetworkMonitor.get(context).current()?.description() ?: "unavailable (waiting for Android)"),
        "coreError" to lastCoreError,
    )

    @Suppress("DEPRECATION")
    fun reportDetails(context: Context): Map<String, String?> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val build = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
        return mapOf("version" to "${info.versionName}+$build",
            "platform" to "Android ${android.os.Build.VERSION.RELEASE} (API ${android.os.Build.VERSION.SDK_INT})",
            "network" to PhysicalNetworkMonitor.cachedDescription(), "coreError" to lastCoreError)
    }

    fun completeStart(error: Throwable? = null, token: Long = generation) {
        main.post {
            if (token != generation) return@post
            val result = pendingStart
            pendingStart = null
            if (error == null) result?.success(null)
            else result?.error("VPN_START", error.message ?: "Could not start VPN.", null)
        }
    }

    fun stop(context: Context, result: MethodChannel.Result? = null) {
        val token = generation
        cancelled = true
        if (state != "stopped") update("stopping")
        worker.execute {
            val running = service
            if (running != null) running.closeTunnel(token)
            else {
                context.stopService(Intent(context, AoraVpnService::class.java))
                update("stopped")
                completeStart(IllegalStateException("Connection cancelled."), token)
            }
            main.post { result?.success(null) }
        }
    }

    fun destroyed(value: AoraVpnService) {
        if (service !== value) return
        service = null
        if (generation == value.sessionGeneration) {
            cancelled = true
            update("stopped")
            completeStart(IllegalStateException("VPN service stopped."), value.sessionGeneration)
        }
    }

    fun validate(context: Context, config: String, core: String, result: MethodChannel.Result) {
        worker.execute {
            try {
                initialize(context)
                if (core == "xray") {
                    require(org.json.JSONObject(config).getJSONArray("inbounds").let { inbounds ->
                        (0 until inbounds.length()).any { inbounds.getJSONObject(it).optString("protocol") == "tun" }
                    }) { "Android requires VPN (TUN) mode." }
                    Mobile.validateXray(config)
                } else {
                    check(Libbox.hasTunInbound(config)) { "Android requires VPN (TUN) mode." }
                    Libbox.checkConfig(config)
                }
                main.post { result.success(null) }
            } catch (error: Exception) {
                main.post { result.error("CONFIG", error.message, null) }
            }
        }
    }
}
