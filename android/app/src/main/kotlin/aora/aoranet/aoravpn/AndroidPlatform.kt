// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.system.OsConstants
import io.nekohasekai.libbox.*
import java.net.InetSocketAddress
import java.net.NetworkInterface as JavaNetworkInterface
import io.nekohasekai.libbox.NetworkInterface as BoxNetworkInterface

/** Android owns routing and the TUN FD; libbox owns the packet-processing stack. */
internal class AndroidPlatform(private val context: Context, private val service: AoraVpnService? = context as? AoraVpnService) : PlatformInterface {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val physicalNetwork = AndroidNetwork(context)
    @Volatile private var network: Network? = null
    @Volatile private var listener: InterfaceUpdateListener? = null
    private var registered = false
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(value: Network) { network = value; changed() }
        override fun onLinkPropertiesChanged(value: Network, properties: LinkProperties) {
            if (network == value) changed()
        }
        override fun onCapabilitiesChanged(value: Network, caps: NetworkCapabilities) {
            if (network == value) changed()
        }
        override fun onLost(value: Network) {
            if (network == value) { network = null; changed() }
        }
    }

    fun start() {
        network = connectivity.activeNetwork?.takeIf { physical(it) }
            ?: connectivity.allNetworks.firstOrNull { physical(it) }
        connectivity.requestNetwork(NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN).build(), callback)
        registered = true
    }

    fun close() {
        listener = null
        if (registered) connectivity.unregisterNetworkCallback(callback)
        registered = false
    }

    private fun physical(value: Network) = connectivity.getNetworkCapabilities(value)
        ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) == true

    private fun changed() {
        val value = network
        service?.setUnderlyingNetworks(value?.let { arrayOf(it) })
        val name = value?.let { connectivity.getLinkProperties(it)?.interfaceName }
        val iface = name?.let { JavaNetworkInterface.getByName(it) }
        val caps = value?.let { connectivity.getNetworkCapabilities(it) }
        runCatching {
            listener?.updateDefaultInterface(name ?: "", iface?.index ?: -1,
                caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false, false)
        }.onFailure { VpnRuntime.log("Network update: ${it.message}") }
    }

    override fun usePlatformAutoDetectInterfaceControl() = true
    override fun autoDetectInterfaceControl(fd: Int) {
        physicalNetwork.protect(fd)
    }

    override fun openTun(options: TunOptions): Int {
        val service = service ?: error("Server checks cannot establish a VPN.")
        val builder = service.Builder().setSession("AORA Connect").setMtu(options.mtu)
        if (Build.VERSION.SDK_INT >= 29) builder.setMetered(false)
        val ipv4 = options.inet4Address
        while (ipv4.hasNext()) ipv4.next().let { builder.addAddress(it.address(), it.prefix()) }
        val ipv6 = options.inet6Address
        while (ipv6.hasNext()) ipv6.next().let { builder.addAddress(it.address(), it.prefix()) }
        val dns = options.dnsServerAddress
        while (dns.hasNext()) builder.addDnsServer(dns.next())
        val routes4 = options.inet4RouteRange
        while (routes4.hasNext()) routes4.next().let { builder.addRoute(it.address(), it.prefix()) }
        val routes6 = options.inet6RouteRange
        while (routes6.hasNext()) routes6.next().let { builder.addRoute(it.address(), it.prefix()) }
        val include = options.includePackage
        while (include.hasNext()) builder.addAllowedApplication(include.next())
        val exclude = options.excludePackage
        while (exclude.hasNext()) builder.addDisallowedApplication(exclude.next())
        // Do not exclude AORA itself: its connection probe must also traverse the tunnel.
        // Only the core's protected sockets bypass it.
        return (builder.establish() ?: error("VPN permission was revoked."))
            .also { service.tunnel = it }.fd
    }

    override fun startDefaultInterfaceMonitor(value: InterfaceUpdateListener) { listener = value; changed() }
    override fun closeDefaultInterfaceMonitor(value: InterfaceUpdateListener?) { listener = null }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val interfaces = connectivity.allNetworks.filter { physical(it) }.mapNotNull { value ->
            val links = connectivity.getLinkProperties(value) ?: return@mapNotNull null
            val caps = connectivity.getNetworkCapabilities(value) ?: return@mapNotNull null
            val iface = links.interfaceName?.let { JavaNetworkInterface.getByName(it) }
                ?: return@mapNotNull null
            BoxNetworkInterface().apply {
                name = iface.name
                index = iface.index
                mtu = iface.mtu
                flags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING or OsConstants.IFF_MULTICAST
                addresses = Strings(links.linkAddresses.map { it.toString() })
                dnsServer = Strings(links.dnsServers.mapNotNull { it.hostAddress })
                gateway = Strings(links.routes.filter { it.isDefaultRoute }.mapNotNull { it.gateway?.hostAddress })
                metered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
                type = when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
            }
        }.iterator()
        return object : NetworkInterfaceIterator {
            override fun hasNext() = interfaces.hasNext()
            override fun next() = interfaces.next()
        }
    }

    override fun useProcFS() = Build.VERSION.SDK_INT < 29
    override fun findConnectionOwner(protocol: Int, source: String, sourcePort: Int,
        destination: String, destinationPort: Int): ConnectionOwner {
        check(Build.VERSION.SDK_INT >= 29) { "Application routing requires Android 10 or later." }
        val uid = connectivity.getConnectionOwnerUid(protocol,
            InetSocketAddress(source, sourcePort), InetSocketAddress(destination, destinationPort))
        check(uid >= 0) { "Could not identify the application's network connection." }
        return ConnectionOwner().apply {
            userId = uid
            setAndroidPackageNames(Strings(context.packageManager.getPackagesForUid(uid)?.toList().orEmpty()))
        }
    }

    override fun localDNSTransport(): LocalDNSTransport? = null
    override fun underNetworkExtension() = false
    override fun includeAllNetworks() = false
    override fun readWIFIState(): WIFIState? = null
    override fun clearDNSCache() {}
    override fun sendNotification(notification: io.nekohasekai.libbox.Notification?) {}
    override fun cancelNotification(identifier: String?, typeID: Int) {}
    override fun startNeighborMonitor(value: NeighborUpdateListener?) {}
    override fun closeNeighborMonitor(value: NeighborUpdateListener?) {}
    override fun registerMyInterface(name: String?) {}
    override fun usePlatformShell() = false
    override fun checkPlatformShell() { throw UnsupportedOperationException() }
    override fun openShellSession(user: PlatformUser?, command: String?, environ: StringIterator?,
        term: String?, rows: Int, cols: Int): ShellSession = throw UnsupportedOperationException()
    override fun lookupUser(username: String?): PlatformUser = throw UnsupportedOperationException()
    override fun lookupSFTPServer(): String = throw UnsupportedOperationException()
    override fun readSystemSSHHostKey(): String = throw UnsupportedOperationException()
    override fun tailscaleHostname() = "aora-android"
    override fun usePlatformBridge() = false
    override fun createBridge(options: BridgeOptions?): BridgeSession = throw UnsupportedOperationException()
}

internal class Strings(private val values: List<String>) : StringIterator {
    private val iterator = values.iterator()
    override fun hasNext() = iterator.hasNext()
    override fun next() = iterator.next()
    override fun len() = values.size
}
