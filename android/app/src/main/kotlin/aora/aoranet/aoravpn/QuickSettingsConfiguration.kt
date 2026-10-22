// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import org.json.JSONObject

internal object QuickSettingsConfiguration {
    fun withAddress(configuration: String, core: String, address: String): String {
        val config = JSONObject(configuration)
        val outbounds = config.getJSONArray("outbounds")
        val proxy = (0 until outbounds.length()).map { outbounds.getJSONObject(it) }
            .first { it.optString("tag") == "proxy" }
        if (core == "xray") {
            val settings = proxy.getJSONObject("settings")
            val servers = settings.optJSONArray("vnext") ?: settings.getJSONArray("servers")
            servers.getJSONObject(0).put("address", address)
        } else proxy.put("server", address)
        return config.toString()
    }
}
