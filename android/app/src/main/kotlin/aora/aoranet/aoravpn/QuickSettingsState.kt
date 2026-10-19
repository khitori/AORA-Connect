// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

/** Keep policy independent of TileService so transitions can be unit tested. */
internal object QuickSettingsState {
    enum class Action { CONNECT, DISCONNECT, OPEN_APP, WAIT }
    fun action(state: String, busy: Boolean, configured: Boolean): Action = when {
        busy || state == "starting" || state == "stopping" -> Action.WAIT
        state == "running" -> Action.DISCONNECT
        configured -> Action.CONNECT
        else -> Action.OPEN_APP
    }
    fun subtitle(state: String, busy: Boolean, name: String?): String = when {
        state == "starting" -> "Connecting…"
        state == "stopping" -> "Disconnecting…"
        state == "running" -> name?.takeIf { it.isNotBlank() } ?: "Connected"
        busy -> "Busy"
        else -> "Disconnected"
    }
}
