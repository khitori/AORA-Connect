// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** establish() returns before Android switches the app's default network to VPN. */
internal object VpnNetworkReady {
    fun await(context: Context) {
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        val ready = CountDownLatch(1)
        val callback = object : ConnectivityManager.NetworkCallback() {
            private var current: Network? = null
            private var vpn = false
            private var links = false
            private var unblocked = Build.VERSION.SDK_INT < 29

            private fun checkReady() {
                if (vpn && links && unblocked) ready.countDown()
            }
            override fun onAvailable(network: Network) {
                current = network
                vpn = false
                links = false
                unblocked = Build.VERSION.SDK_INT < 29
            }
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                if (current != network) return
                vpn = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
                checkReady()
            }
            override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) {
                if (current != network) return
                links = properties.interfaceName != null && properties.linkAddresses.isNotEmpty()
                checkReady()
            }
            override fun onBlockedStatusChanged(network: Network, blocked: Boolean) {
                if (current != network) return
                unblocked = !blocked
                checkReady()
            }
            override fun onLost(network: Network) {
                if (current == network) { vpn = false; links = false }
            }
        }
        connectivity.registerDefaultNetworkCallback(callback)
        try {
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(15)
            while (!ready.await(100, TimeUnit.MILLISECONDS)) {
                check(!VpnRuntime.cancelled) { "Connection cancelled." }
                check(System.nanoTime() < deadline) { "Android did not make the VPN network ready for this application." }
            }
            check(!VpnRuntime.cancelled) { "Connection cancelled." }
        } finally {
            connectivity.unregisterNetworkCallback(callback)
        }
    }
}
