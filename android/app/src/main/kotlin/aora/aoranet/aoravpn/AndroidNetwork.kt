// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import io.nekohasekai.mobile.Platform
import java.net.InetSocketAddress

/** Physical-network operations shared by both cores and direct server checks. */
internal class AndroidNetwork(private val context: Context) : Platform {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    fun physical(): Network {
        fun usable(value: Network) = connectivity.getNetworkCapabilities(value)?.let {
            it.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) &&
                it.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } == true
        return connectivity.activeNetwork?.takeIf(::usable)
            ?: connectivity.allNetworks.firstOrNull(::usable)
            ?: error("No physical network route to this server.")
    }

    override fun protect(fd: Int) {
        // Duplicate only to get a Java FileDescriptor; socket marks apply to both
        // descriptors. Closing this duplicate must never close the core's FD.
        ParcelFileDescriptor.fromFd(fd).use { duplicate ->
            VpnRuntime.service?.let {
                check(it.protect(duplicate.fd)) { "Could not protect the outbound socket." }
            }
            physical().bindSocket(duplicate.fileDescriptor)
        }
    }

    override fun resolve(host: String): String = physical().getAllByName(host)
        .sortedBy { if (it.address.size == 4) 0 else 1 }
        .mapNotNull { it.hostAddress }.joinToString("\n")

    override fun findProcess(network: String, source: String, sourcePort: Int,
        destination: String, destinationPort: Int): String {
        check(Build.VERSION.SDK_INT >= 29) { "Application routing requires Android 10 or later." }
        val uid = connectivity.getConnectionOwnerUid(
            if (network == "tcp") OsConstants.IPPROTO_TCP else OsConstants.IPPROTO_UDP,
            InetSocketAddress(source, sourcePort), InetSocketAddress(destination, destinationPort))
        check(uid >= 0) { "Could not identify the application's network connection." }
        return context.packageManager.getPackagesForUid(uid)?.firstOrNull()
            ?: error("No package found for the network connection.")
    }
}
