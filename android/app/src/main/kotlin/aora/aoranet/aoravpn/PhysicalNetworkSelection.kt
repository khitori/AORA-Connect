// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

internal class PhysicalNetworkSelection<T>(private val initiallyBlocked: Boolean) {
    var preferred: T? = null
        private set
    private var usable = false
    private var linked = false
    private var blocked = initiallyBlocked

    val selected: T?
        get() = preferred?.takeIf { usable && linked && !blocked }

    fun available(value: T) {
        preferred = value
        usable = false
        linked = false
        blocked = initiallyBlocked
    }

    fun capabilities(value: T, ready: Boolean) { if (preferred == value) usable = ready }
    fun links(value: T, ready: Boolean) { if (preferred == value) linked = ready }
    fun blocked(value: T, valueBlocked: Boolean) { if (preferred == value) blocked = valueBlocked }
    fun lost(value: T) {
        if (preferred == value) {
            preferred = null
            usable = false
            linked = false
        }
    }
}
