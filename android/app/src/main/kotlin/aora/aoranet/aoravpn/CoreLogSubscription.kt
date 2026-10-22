// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import io.nekohasekai.libbox.*

internal class CoreLogSubscription : CommandClientHandler {
    @Volatile private var closed = false
    @Volatile private var defaultLevel = 4
    private val client = CommandClient(this, CommandClientOptions().apply {
        addCommand(Libbox.CommandLog)
    })

    fun start() { client.connect() }
    fun close() { closed = true; client.disconnect() }

    override fun writeLogs(messages: LogIterator?) {
        if (messages == null || closed) return
        while (messages.hasNext()) {
            val entry = messages.next()
            if (entry.level <= defaultLevel) VpnRuntime.log(entry.message)
        }
    }
    override fun disconnected(message: String?) {
        if (!closed && !message.isNullOrBlank()) VpnRuntime.log("Core log stream: $message")
    }
    override fun clearLogs() {}
    override fun connected() {}
    override fun setDefaultLogLevel(level: Int) { defaultLevel = level }
    override fun writeStatus(message: StatusMessage?) {}
    override fun writeGroups(groups: OutboundGroupIterator?) {}
    override fun writeOutbounds(outbounds: OutboundGroupItemIterator?) {}
    override fun initializeClashMode(modes: StringIterator?, currentMode: String?) {}
    override fun updateClashMode(mode: String?) {}
    override fun writeConnectionEvents(events: ConnectionEvents?) {}
}
