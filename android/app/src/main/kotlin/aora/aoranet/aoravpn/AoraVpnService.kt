// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.mobile.Mobile
import org.json.JSONObject

class AoraVpnService : VpnService(), CommandServerHandler {
    private var core: CommandServer? = null
    private var coreLogs: CoreLogSubscription? = null
    private var platform: AndroidPlatform? = null
    internal var tunnel: ParcelFileDescriptor? = null
    private var latestStartId = 0
    private var closed = false
    private var xray = false
    internal var sessionGeneration = 0L
        private set

    override fun onCreate() {
        super.onCreate()
        VpnRuntime.service = this
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel("vpn", "VPN connection", NotificationManager.IMPORTANCE_LOW))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        latestStartId = startId
        if (intent?.action == "stop") {
            VpnRuntime.stop(this)
            return START_NOT_STICKY
        }
        var config = intent?.getStringExtra("config")
        sessionGeneration = intent?.getLongExtra("generation", 0L) ?: 0L
        if (config == null || VpnRuntime.state != "starting") {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(1, notification("Connecting…"))
        VpnRuntime.worker.execute {
            closed = false
            var stage = "core initialization"
            try {
                check(!VpnRuntime.cancelled) { "Connection cancelled." }
                VpnRuntime.initialize(this)
                check(prepare(this) == null) { "VPN permission was not granted." }
                stage = "physical network selection"
                platform = AndroidPlatform(this).also { it.start() }
                VpnRuntime.log("VPN startup network: ${PhysicalNetworkMonitor.get(this).awaitReady().description()}")
                val host = intent?.getStringExtra("serverHost")
                if (host != null) {
                    stage = "server DNS lookup"
                    val network = PhysicalNetworkMonitor.get(this).awaitReady().network
                    val address = QuickSettingsTasks.within(15000, "Server DNS lookup") {
                        network.getAllByName(host).sortedBy { if (it.address.size == 4) 0 else 1 }.first().hostAddress!!
                    }
                    config = QuickSettingsConfiguration.withAddress(config!!, intent.getStringExtra("core") ?: "singBox", address)
                }
                stage = "core/TUN startup"
                xray = intent?.getStringExtra("core") == "xray"
                if (xray) {
                    val inbounds = JSONObject(config!!).getJSONArray("inbounds")
                    val settings = (0 until inbounds.length()).map { inbounds.getJSONObject(it) }
                        .first { it.optString("protocol") == "tun" }.getJSONObject("settings")
                    val builder = Builder().setSession("AORA Connect").setMtu(settings.optInt("mtu", 1500))
                        .setUnderlyingNetworks(arrayOf(PhysicalNetworkMonitor.get(this).awaitReady().network))
                    if (android.os.Build.VERSION.SDK_INT >= 29) builder.setMetered(false)
                    val addresses = settings.getJSONArray("gateway")
                    for (index in 0 until addresses.length()) {
                        val parts = addresses.getString(index).split('/')
                        builder.addAddress(parts[0], parts[1].toInt())
                    }
                    val dns = settings.getJSONArray("dns")
                    for (index in 0 until dns.length()) builder.addDnsServer(dns.getString(index))
                    builder.addRoute("0.0.0.0", 0).addRoute("::", 0)
                    tunnel = builder.establish() ?: error("VPN permission was revoked.")
                    Mobile.startXray(config, tunnel!!.fd)
                } else {
                    check(Libbox.hasTunInbound(config)) { "Android requires VPN (TUN) mode." }
                    core = CommandServer(this, platform).also { it.start() }
                    core!!.startOrReloadService(config, OverrideOptions())
                    coreLogs = CoreLogSubscription()
                    runCatching { coreLogs!!.start() }
                        .onFailure { VpnRuntime.log("Could not subscribe to core logs: ${it.message}") }
                }
                stage = "Android VPN network readiness"
                VpnNetworkReady.await(this)
                check(!VpnRuntime.cancelled) { "Connection cancelled." }
                VpnRuntime.log(if (xray) "Xray 26.9.30 started." else "sing-box ${Libbox.version()} started.")
                if (intent?.getBooleanExtra("verify", false) == true) {
                    stage = "HTTPS connection verification"
                    QuickSettingsProbe.verify(this)
                }
                VpnRuntime.update("running")
                getSystemService(NotificationManager::class.java).notify(1, notification("Connected"))
                VpnRuntime.completeStart(token = sessionGeneration)
            } catch (error: Exception) {
                val failure = IllegalStateException("VPN startup failed during $stage: ${error.javaClass.simpleName}: ${error.message}", error)
                VpnRuntime.log("ERROR ${failure.message ?: "VPN startup failed."}")
                VpnRuntime.completeStart(failure, sessionGeneration)
                closeTunnel()
            }
        }
        return START_NOT_STICKY
    }

    /** Runs on the serial worker; release both the core and Android's original FD. */
    internal fun closeTunnel(token: Long = sessionGeneration) {
        if (token != sessionGeneration) return
        if (closed) return
        closed = true
        val closingStartId = latestStartId
        try {
            if (xray) Mobile.stopXray()
            // Closing the command server alone does not stop its Box instance.
            // CloseService releases the TUN duplicate, sockets and cache lock first.
            try {
                core?.closeService()
            } finally {
                try { coreLogs?.close() } finally { core?.close() }
            }
        } catch (error: Exception) {
            VpnRuntime.log("Core shutdown: ${error.message}")
        } finally {
            core = null
            coreLogs = null
            runCatching { tunnel?.close() }
            tunnel = null
            runCatching { platform?.close() }
            platform = null
            if (VpnRuntime.service === this && VpnRuntime.generation == sessionGeneration) {
                VpnRuntime.update("stopped")
                VpnRuntime.completeStart(IllegalStateException("Connection cancelled."), sessionGeneration)
            }
            VpnRuntime.main.post {
                if (latestStartId == closingStartId) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf(closingStartId)
                }
            }
        }
    }

    private fun notification(status: String): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, AoraVpnService::class.java).setAction("stop"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, "vpn")
            .setSmallIcon(R.drawable.ic_vpn)
            .setContentTitle("AORA Connect")
            .setContentText(status)
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Disconnect", stop).build())
            .build()
    }

    override fun onRevoke() { if (VpnRuntime.generation == sessionGeneration) VpnRuntime.stop(this) }
    override fun onDestroy() {
        VpnRuntime.destroyed(this)
        VpnRuntime.worker.execute { closeTunnel() }
        super.onDestroy()
    }

    override fun serviceStop() { if (VpnRuntime.generation == sessionGeneration) VpnRuntime.stop(this) }
    override fun serviceReload() { throw UnsupportedOperationException("Disconnect before changing servers.") }
    override fun getSystemProxyStatus() = SystemProxyStatus()
    override fun setSystemProxyEnabled(enabled: Boolean) { throw UnsupportedOperationException("TUN mode only.") }
    override fun triggerNativeCrash() { throw UnsupportedOperationException() }
    override fun writeDebugMessage(message: String?) { if (message != null) VpnRuntime.log(message) }
    override fun connectSSHAgent() = -1
}
