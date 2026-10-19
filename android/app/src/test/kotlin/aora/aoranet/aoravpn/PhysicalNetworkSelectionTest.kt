// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import org.junit.Assert.*
import org.junit.Test

class PhysicalNetworkSelectionTest {
    private fun ready(state: PhysicalNetworkSelection<String>, network: String) {
        state.available(network)
        state.capabilities(network, true)
        state.links(network, true)
        state.blocked(network, false)
    }

    @Test fun waitsForCapabilitiesLinksAndUnblockedAccess() {
        val state = PhysicalNetworkSelection<String>(true)
        state.available("wifi")
        assertNull(state.selected)
        state.capabilities("wifi", true)
        state.links("wifi", true)
        assertNull(state.selected)
        state.blocked("wifi", false)
        assertEquals("wifi", state.selected)
    }

    @Test fun callbackOrderDoesNotSelectAnIncompleteNetwork() {
        val state = PhysicalNetworkSelection<String>(true)
        state.available("mobile")
        state.blocked("mobile", false)
        state.links("mobile", true)
        assertNull(state.selected)
        state.capabilities("mobile", true)
        assertEquals("mobile", state.selected)
    }

    @Test fun handoverNeverReusesOldReadiness() {
        val state = PhysicalNetworkSelection<String>(true)
        ready(state, "wifi")
        state.available("mobile")
        assertNull(state.selected)
        state.capabilities("mobile", true)
        state.links("mobile", true)
        assertNull(state.selected)
        state.blocked("mobile", false)
        assertEquals("mobile", state.selected)
    }

    @Test fun staleOldNetworkEventsCannotReplaceTheSelectedNetwork() {
        val state = PhysicalNetworkSelection<String>(true)
        ready(state, "wifi")
        ready(state, "mobile")
        state.lost("wifi")
        state.links("wifi", false)
        state.blocked("wifi", true)
        state.capabilities("wifi", false)
        assertEquals("mobile", state.selected)
    }

    @Test fun blockedNetworkHasNoArbitraryFallback() {
        val state = PhysicalNetworkSelection<String>(true)
        ready(state, "wifi")
        ready(state, "mobile")
        state.blocked("mobile", true)
        assertNull(state.selected)
        state.blocked("mobile", false)
        assertEquals("mobile", state.selected)
    }

    @Test fun disconnectRemovesTheRouteUntilAnotherNetworkIsReady() {
        val state = PhysicalNetworkSelection<String>(true)
        ready(state, "wifi")
        state.lost("wifi")
        state.links("wifi", true)
        state.capabilities("wifi", true)
        state.blocked("wifi", false)
        assertNull(state.selected)
        ready(state, "mobile")
        assertEquals("mobile", state.selected)
    }

    @Test fun legacyAndroidDoesNotWaitForUnsupportedBlockedCallback() {
        val state = PhysicalNetworkSelection<String>(false)
        state.available("wifi")
        state.capabilities("wifi", true)
        state.links("wifi", true)
        assertEquals("wifi", state.selected)
    }

    @Test fun vpnOrNonInternetCapabilitiesAreNeverUsable() {
        val state = PhysicalNetworkSelection<String>(true)
        ready(state, "candidate")
        state.capabilities("candidate", false)
        assertNull(state.selected)
        state.capabilities("candidate", true)
        state.links("candidate", false)
        assertNull(state.selected)
    }
}
