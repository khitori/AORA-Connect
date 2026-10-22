// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

internal object QuickSettingsState {
    data class Labels(
        val connecting: String = "Connecting…",
        val disconnecting: String = "Disconnecting…",
        val connected: String = "Connected",
        val disconnected: String = "Disconnected",
        val busy: String = "Busy",
    )
    enum class Action { CONNECT, DISCONNECT, OPEN_APP, WAIT }
    fun action(state: String, busy: Boolean, configured: Boolean): Action = when {
        busy || state == "starting" || state == "stopping" -> Action.WAIT
        state == "running" -> Action.DISCONNECT
        configured -> Action.CONNECT
        else -> Action.OPEN_APP
    }
    fun subtitle(state: String, busy: Boolean, name: String?, labels: Labels = Labels()): String = when {
        state == "starting" -> labels.connecting
        state == "stopping" -> labels.disconnecting
        state == "running" -> name?.takeIf { it.isNotBlank() } ?: labels.connected
        busy -> labels.busy
        else -> labels.disconnected
    }
}
