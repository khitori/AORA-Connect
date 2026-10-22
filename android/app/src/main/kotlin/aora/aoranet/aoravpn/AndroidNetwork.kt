// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import io.nekohasekai.mobile.Platform
import java.net.InetSocketAddress

internal class AndroidNetwork(private val context: Context) : Platform {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val monitor = PhysicalNetworkMonitor.get(context)
    fun physical(): Network = monitor.awaitReady().network

    override fun protect(fd: Int) {
        val selected = monitor.awaitReady()
        try {
            ParcelFileDescriptor.fromFd(fd).use { duplicate ->
                VpnRuntime.service?.let {
                    check(it.protect(duplicate.fd)) { "Could not protect the outbound socket." }
                }
                selected.network.bindSocket(duplicate.fileDescriptor)
            }
        } catch (error: Exception) {
            VpnRuntime.log("Outbound socket protection/binding failed (${selected.description()}): ${error.javaClass.simpleName}")
            throw error
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
