// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

internal object QuickSettingsTasks {
    private val io = ThreadPoolExecutor(0, 2, 30L, TimeUnit.SECONDS, SynchronousQueue<Runnable>()) {
        Thread(it, "aora-tile-check")
    }
    fun <T> within(milliseconds: Long, stage: String, action: () -> T): T {
        val token = VpnRuntime.generation
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(milliseconds)
        val task = io.submit(Callable { action() })
        try {
            while (true) {
                check(!VpnRuntime.cancelled && VpnRuntime.generation == token) { "Connection cancelled" }
                val remaining = deadline - System.nanoTime()
                check(remaining > 0) { "$stage timed out after $milliseconds ms" }
                try { return task.get(minOf(remaining, TimeUnit.MILLISECONDS.toNanos(100)), TimeUnit.NANOSECONDS) }
                catch (_: TimeoutException) {                                          }
                catch (error: ExecutionException) { throw error.cause ?: error }
            }
        } finally { task.cancel(true) }
    }
}
