// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.SystemClock
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors

/** One process-owned request shared by the service, both cores and server checks.
 * Android selects the best INTERNET/NOT_VPN network. Never infer preference from
 * allNetworks ordering, and never query synchronous network state in callbacks.
 */
internal class PhysicalNetworkMonitor private constructor(context: Context) {
    data class Snapshot(val network: Network, val capabilities: NetworkCapabilities, val links: LinkProperties) {
        fun description(): String {
            val transport = when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile data"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
                else -> "other"
            }
            val families = links.linkAddresses.map { if (it.address.address.size == 4) "IPv4" else "IPv6" }.distinct()
            return "$transport, network=$network, interface=${links.interfaceName}, ${families.joinToString("/")}, " +
                "validated=${capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)}"
        }
    }

    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    @Suppress("PLATFORM_CLASS_MAPPED_TO_KOTLIN") // wait/notify wake bounded worker waits.
    private val lock = Object()
    private val selection = PhysicalNetworkSelection<Network>(Build.VERSION.SDK_INT >= 29)
    private var capabilities: NetworkCapabilities? = null
    private var links: LinkProperties? = null
    private val observers = CopyOnWriteArrayList<() -> Unit>()
    // Core interface updates can block or open sockets. Never run them on the
    // connectivity thread needed to deliver the next network's ready events.
    private val notifications = Executors.newSingleThreadExecutor { Thread(it, "aora-network") }
    private var lastSnapshot: Snapshot? = null
    private var lastDescription: String? = null

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            change {
                selection.available(network)
                capabilities = null
                links = null
            }
            // API 24/25 do not guarantee initial capability/link callbacks. Read
            // missing snapshots off the connectivity thread for that exact
            // requested network only, never by enumerating available networks.
            if (Build.VERSION.SDK_INT < 26) notifications.execute {
                val initialCaps = connectivity.getNetworkCapabilities(network)
                val initialLinks = connectivity.getLinkProperties(network)
                change {
                    if (selection.preferred == network) {
                        if (capabilities == null && initialCaps != null) {
                            capabilities = initialCaps
                            selection.capabilities(network, usable(initialCaps))
                        }
                        if (links == null && initialLinks != null) {
                            links = initialLinks
                            selection.links(network, linked(initialLinks))
                        }
                    }
                }
            }
        }

        override fun onCapabilitiesChanged(network: Network, value: NetworkCapabilities) = change {
            if (selection.preferred == network) {
                capabilities = NetworkCapabilities(value)
                selection.capabilities(network, usable(value))
            }
        }

        override fun onLinkPropertiesChanged(network: Network, value: LinkProperties) = change {
            if (selection.preferred == network) {
                // Callback values are framework snapshots; never mutate them.
                links = value
                selection.links(network, linked(value))
            }
        }

        override fun onBlockedStatusChanged(network: Network, blocked: Boolean) = change {
            selection.blocked(network, blocked)
        }

        override fun onLost(network: Network) = change {
            if (selection.preferred == network) {
                selection.lost(network)
                capabilities = null
                links = null
            }
        }
    }

    init {
        connectivity.requestNetwork(NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN).build(), callback)
    }

    private fun usable(value: NetworkCapabilities) =
        value.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
        value.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) &&
        !value.hasTransport(NetworkCapabilities.TRANSPORT_VPN)

    private fun linked(value: LinkProperties) = value.interfaceName != null && value.linkAddresses.isNotEmpty()

    private fun snapshotLocked(): Snapshot? {
        val network = selection.selected ?: return null
        return Snapshot(network, capabilities ?: return null, links ?: return null)
    }

    fun current(): Snapshot? = synchronized(lock) { snapshotLocked() }

    /** Called on workers, never on the UI or connectivity callback thread. */
    fun awaitReady(): Snapshot = synchronized(lock) {
        val deadline = SystemClock.elapsedRealtime() + 10_000
        var snapshot = snapshotLocked()
        while (snapshot == null) {
            val remaining = deadline - SystemClock.elapsedRealtime()
            check(remaining > 0) { "Physical network selection timed out: Android has not supplied an unblocked non-VPN internet network." }
            lock.wait(remaining)
            snapshot = snapshotLocked()
        }
        snapshot
    }

    fun observe(observer: () -> Unit): AutoCloseable {
        observers.add(observer)
        try { observer() } catch (error: Exception) {
            observers.remove(observer)
            throw error
        }
        return AutoCloseable { observers.remove(observer) }
    }

    private fun change(action: () -> Unit) {
        val changed = synchronized(lock) {
            action()
            lock.notifyAll()
            val description = snapshotLocked()?.description() ?: "unavailable (waiting for Android)"
            if (description != lastDescription) {
                lastDescription = description
                VpnRuntime.log("Physical network: $description")
            }
            val snapshot = snapshotLocked()
            (snapshot != lastSnapshot).also { lastSnapshot = snapshot }
        }
        if (changed) notifications.execute {
            observers.forEach { observer ->
                runCatching(observer).onFailure { VpnRuntime.log("Network observer failed: ${it.javaClass.simpleName}") }
            }
        }
    }

    companion object {
        @Volatile private var instance: PhysicalNetworkMonitor? = null
        fun get(context: Context): PhysicalNetworkMonitor = instance ?: synchronized(this) {
            instance ?: PhysicalNetworkMonitor(context.applicationContext).also { instance = it }
        }
    }
}
