// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import org.junit.Assert.*
import org.junit.Test

class QuickSettingsStateTest {
    @Test fun translatedLabelsPreserveUserServerNames() {
        val labels = QuickSettingsState.Labels("Подключение…", "Отключение…", "Подключено", "Отключено", "Занято")
        assertEquals("Подключение…", QuickSettingsState.subtitle("starting", false, null, labels))
        assertEquals("Отключено", QuickSettingsState.subtitle("stopped", false, null, labels))
        assertEquals("Подключено", QuickSettingsState.subtitle("running", false, null, labels))
        assertEquals("My server", QuickSettingsState.subtitle("running", false, "My server", labels))
    }
    @Test fun connectsOnlyWithSelection() {
        assertEquals(QuickSettingsState.Action.OPEN_APP, QuickSettingsState.action("stopped", false, false))
        assertEquals(QuickSettingsState.Action.CONNECT, QuickSettingsState.action("stopped", false, true))
    }
    @Test fun disconnectsWithoutRequiringSavedConfiguration() {
        assertEquals(QuickSettingsState.Action.DISCONNECT, QuickSettingsState.action("running", false, false))
    }
    @Test fun neverDoubleStartsOrInterruptsAnInAppOperation() {
        for (state in listOf("stopped", "starting", "running", "stopping")) {
            assertEquals(QuickSettingsState.Action.WAIT, QuickSettingsState.action(state, true, true))
        }
        assertEquals(QuickSettingsState.Action.WAIT, QuickSettingsState.action("starting", false, true))
        assertEquals(QuickSettingsState.Action.WAIT, QuickSettingsState.action("stopping", false, true))
    }
    @Test fun showsSelectedServerOnlyWhenConnected() {
        assertEquals("Disconnected", QuickSettingsState.subtitle("stopped", false, "My server"))
        assertEquals("Connecting…", QuickSettingsState.subtitle("starting", false, "My server"))
        assertEquals("My server", QuickSettingsState.subtitle("running", false, "My server"))
        assertEquals("Disconnecting…", QuickSettingsState.subtitle("stopping", false, "My server"))
    }
    @Test fun hasSafeLabelsBeforeSelectionRestored() {
        assertEquals("Connected", QuickSettingsState.subtitle("running", false, null))
        assertEquals("Busy", QuickSettingsState.subtitle("stopped", true, null))
    }
}
