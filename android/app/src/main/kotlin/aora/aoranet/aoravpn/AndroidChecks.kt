// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.*
import io.nekohasekai.mobile.Batch
import io.nekohasekai.mobile.Mobile
import org.json.JSONArray
import org.json.JSONObject
import java.net.InetAddress
import java.net.ServerSocket
import java.net.InetSocketAddress
import java.security.SecureRandom
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import java.io.File

internal object AndroidChecks {
    private val probes = Executors.newFixedThreadPool(32)
    private val batches = ConcurrentHashMap<Long, CheckBatch>()
    private val nextId = AtomicLong()

    private class CheckBatch {
        var core: CommandServer? = null
        var platform: AndroidPlatform? = null
        var xray: Batch? = null
        var cache: File? = null
        val nodes = mutableMapOf<Int, Map<String, Any>>()
        fun close() {
            try { xray?.close() } finally {
                try { core?.closeService() } finally {
                    try { core?.close() } finally { try { platform?.close() } finally { cache?.delete() } }
                }
            }
        }
    }

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val task = Runnable {
            try {
                val value: Any? = when (call.method) {
                    "resolve" -> AndroidNetwork(context).resolve(call.argument<String>("host")!!).lineSequence().first()
                    "ping" -> direct(context, call.argument<String>("address")!!,
                        call.argument<String>("type")!!, call.argument<Int>("port") ?: 0)
                    "openPingBatch" -> open(context, call.argument<List<Map<String, Any>>>("nodes")!!)
                    "checkPingBatch" -> {
                        val batch = batches[call.argument<Number>("id")!!.toLong()] ?: error("Cancelled")
                        batch.xray?.check(call.argument<Int>("index")!!,
                            call.argument<String>("method")!!, call.argument<String>("url")!!)
                            ?: error("Xray check session is unavailable.")
                    }
                    "closePingBatch" -> { batches.remove(call.argument<Number>("id")!!.toLong())?.close(); null }
                    else -> error("Unknown check request")
                }
                VpnRuntime.main.post { result.success(value) }
            } catch (error: Exception) {
                val message = error.message ?: "Server check failed."
                VpnRuntime.main.post { result.error("PING", message, null) }
            }
        }
        if (call.method == "openPingBatch" || call.method == "closePingBatch") VpnRuntime.worker.execute(task)
        else probes.execute(task)
    }

    private fun direct(context: Context, address: String, type: String, port: Int): Long {
        require(address.matches(Regex("[0-9a-fA-F:.%]+"))) { "Invalid server address." }
        val destination = InetAddress.getByName(address)
        val network = AndroidNetwork(context)
        if (type == "tcp") {
            require(port in 1..65535)
            network.physical().socketFactory.createSocket().use { socket ->
                val watch = SystemClock.elapsedRealtimeNanos()
                socket.connect(InetSocketAddress(destination, port), 3000)
                return (SystemClock.elapsedRealtimeNanos() - watch) / 1000
            }
        }
        require(type == "icmp")
        val ipv6 = destination.address.size == 16
        val fd = Os.socket(if (ipv6) OsConstants.AF_INET6 else OsConstants.AF_INET,
            OsConstants.SOCK_DGRAM, if (ipv6) OsConstants.IPPROTO_ICMPV6 else OsConstants.IPPROTO_ICMP)
        try {
            ParcelFileDescriptor.dup(fd).use { network.protect(it.fd) }
            Os.connect(fd, destination, 0)
            val packet = ByteArray(24)
            packet[0] = (if (ipv6) 128 else 8).toByte()
            val nonce = ByteArray(16).also { SecureRandom().nextBytes(it) }
            nonce.copyInto(packet, 8)
            packet[7] = 1
            if (!ipv6) {
                var sum = 0
                for (index in packet.indices step 2) sum += ((packet[index].toInt() and 255) shl 8) or (packet[index + 1].toInt() and 255)
                while (sum ushr 16 != 0) sum = (sum and 65535) + (sum ushr 16)
                val checksum = sum.inv() and 65535
                packet[2] = (checksum ushr 8).toByte(); packet[3] = checksum.toByte()
            }
            val watch = SystemClock.elapsedRealtimeNanos()
            Os.write(fd, packet, 0, packet.size)
            val deadline = SystemClock.elapsedRealtime() + 3000
            val poll = StructPollfd().apply { this.fd = fd; events = OsConstants.POLLIN.toShort() }
            val response = ByteArray(2048)
            while (SystemClock.elapsedRealtime() < deadline) {
                val remaining = (deadline - SystemClock.elapsedRealtime()).coerceAtLeast(1).toInt()
                if (Os.poll(arrayOf(poll), remaining) == 0) break
                val length = Os.read(fd, response, 0, response.size)
                if (length >= packet.size && (response[0].toInt() and 255) == (if (ipv6) 129 else 0)
                    && response.copyOfRange(8, 24).contentEquals(nonce)) {
                    return (SystemClock.elapsedRealtimeNanos() - watch) / 1000
                }
            }
            error("No reply. The server may block this check.")
        } finally { Os.close(fd) }
    }

    private fun open(context: Context, nodes: List<Map<String, Any>>): Map<String, Any> {
        VpnRuntime.initialize(context)
        require(nodes.isNotEmpty())
        val batch = CheckBatch()
        val id = nextId.incrementAndGet()
        try {
            val singNodes = nodes.filter { it["core"] == "singBox" }
            if (singNodes.isNotEmpty()) {
                batch.cache = File(context.cacheDir, "ping-$id.db")
                val inbounds = JSONArray(); val outbounds = JSONArray(); val rules = JSONArray()
                for (node in singNodes) {
                    val index = (node["index"] as Number).toInt()
                    val port = ServerSocket(0, 0, InetAddress.getByName("127.0.0.1")).use { it.localPort }
                    val tag = "check-$index"
                    val outbound = JSONObject(node["outbound"] as Map<*, *>).put("tag", tag)
                    val inbound = JSONObject().put("type", "mixed").put("tag", tag)
                        .put("listen", "127.0.0.1").put("listen_port", port)
                    inbounds.put(inbound); outbounds.put(outbound)
                    rules.put(JSONObject().put("inbound", JSONArray(listOf(tag))).put("action", "route").put("outbound", tag))
                    batch.nodes[index] = mapOf("port" to port)
                }
                val config = JSONObject().put("log", JSONObject().put("level", "error"))
                    .put("experimental", JSONObject().put("cache_file", JSONObject().put("enabled", false).put("path", batch.cache!!.absolutePath)))
                    .put("dns", JSONObject().put("servers", JSONArray().put(JSONObject().put("type", "local").put("tag", "local-dns"))))
                    .put("inbounds", inbounds).put("outbounds", outbounds)
                    .put("route", JSONObject().put("auto_detect_interface", true).put("default_domain_resolver", "local-dns").put("rules", rules))
                try {
                    try { Libbox.checkConfig(config.toString()) }
                    catch (_: Exception) {
                        val acceptedIn = JSONArray(); val acceptedOut = JSONArray(); val acceptedRules = JSONArray()
                        for (position in singNodes.indices) {
                            val single = JSONObject(config.toString()).put("inbounds", JSONArray().put(inbounds.get(position)))
                                .put("outbounds", JSONArray().put(outbounds.get(position)))
                            single.getJSONObject("route").put("rules", JSONArray().put(rules.get(position)))
                            try {
                                Libbox.checkConfig(single.toString())
                                acceptedIn.put(inbounds.get(position)); acceptedOut.put(outbounds.get(position)); acceptedRules.put(rules.get(position))
                            } catch (error: Exception) {
                                batch.nodes[(singNodes[position]["index"] as Number).toInt()] = mapOf("error" to (error.message ?: "Core rejected this profile."))
                            }
                        }
                        require(acceptedIn.length() > 0) { "Core rejected these profiles." }
                        config.put("inbounds", acceptedIn).put("outbounds", acceptedOut)
                        config.getJSONObject("route").put("rules", acceptedRules)
                    }
                    batch.platform = AndroidPlatform(context).also { it.start() }
                    batch.core = CommandServer(CheckHandler, batch.platform)
                    batch.core!!.startOrReloadService(config.toString(), OverrideOptions())
                } catch (error: Exception) {
                    for (node in singNodes) batch.nodes[(node["index"] as Number).toInt()] = mapOf("error" to (error.message ?: "sing-box checks failed."))
                    runCatching { batch.core?.closeService() }; runCatching { batch.core?.close() }; batch.core = null
                    runCatching { batch.platform?.close() }; batch.platform = null
                }
            }
            val xrayNodes = nodes.filter { it["core"] == "xray" }
            if (xrayNodes.isNotEmpty()) {
                try {
                    batch.xray = Mobile.openXrayBatch(JSONArray(xrayNodes.map { it["outbound"] }).toString())
                    xrayNodes.forEachIndexed { position, node ->
                        val error = batch.xray!!.nodeError(position)
                        batch.nodes[(node["index"] as Number).toInt()] = if (error.isEmpty())
                            mapOf("xrayIndex" to position) else mapOf("error" to error)
                    }
                } catch (error: Exception) {
                    for (node in xrayNodes) batch.nodes[(node["index"] as Number).toInt()] = mapOf("error" to (error.message ?: "Xray checks failed."))
                }
            }
            batches[id] = batch
            return mapOf("id" to id, "nodes" to batch.nodes.mapKeys { it.key.toString() })
        } catch (error: Exception) { batch.close(); throw error }
    }

    private object CheckHandler : CommandServerHandler {
        override fun serviceStop() {}
        override fun serviceReload() { throw UnsupportedOperationException() }
        override fun getSystemProxyStatus() = SystemProxyStatus()
        override fun setSystemProxyEnabled(enabled: Boolean) { throw UnsupportedOperationException() }
        override fun triggerNativeCrash() { throw UnsupportedOperationException() }
        override fun writeDebugMessage(message: String?) {}
        override fun connectSSHAgent() = -1
    }
}
