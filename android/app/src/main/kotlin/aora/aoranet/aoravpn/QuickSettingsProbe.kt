// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import java.net.URL
import javax.net.ssl.HttpsURLConnection

internal object QuickSettingsProbe {
    /** Match the in-app HTTPS check, explicitly bound to VPN, with no direct fallback. */
    fun verify(context: Context) {
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        val network = connectivity.activeNetwork ?: error("VPN network is unavailable")
        check(connectivity.getNetworkCapabilities(network)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
            "VPN network is unavailable for connection verification"
        }
        VpnRuntime.log("Connection check: HTTPS through VPN (Quick Settings).")
        QuickSettingsTasks.within(50000, "HTTPS connection verification") { request(network) }
        VpnRuntime.log("Connection verified (Quick Settings).")
    }

    private fun request(network: android.net.Network) {
        val connection = network.openConnection(URL("https://example.com/")) as HttpsURLConnection
        try {
            connection.connectTimeout = 15000
            connection.readTimeout = 20000
            connection.instanceFollowRedirects = false
            check(connection.responseCode == 200) { "Connection check failed (HTTP ${connection.responseCode})" }
            connection.inputStream.use { stream ->
                val buffer = ByteArray(4096)
                val deadline = System.nanoTime() + 15_000_000_000L
                while (stream.read(buffer) != -1) {
                    check(!VpnRuntime.cancelled) { "Connection cancelled" }
                    check(System.nanoTime() < deadline) { "Connection check response body timed out" }
                }
            }
            check(!VpnRuntime.cancelled) { "Connection cancelled" }
        } finally { connection.disconnect() }
    }
}
