// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import java.util.Locale

/** Native services also honor the saved choice when Flutter is not running. */
internal object AppLanguage {
    val languages = setOf("en", "ru", "zh", "de", "fr", "es", "ar", "fa", "he")
    private fun preferences(context: Context) = context.getSharedPreferences("aora-language", Context.MODE_PRIVATE)

    fun select(context: Context, language: String?) {
        require(language == null || language in languages)
        preferences(context).edit().putString("language", language).apply()
        QuickSettings.refresh()
        VpnRuntime.service?.refreshNotification()
    }

    fun text(context: Context, resource: Int): String {
        val selected = preferences(context).getString("language", null)
        val system = context.resources.configuration.locales
        val language = selected ?: (0 until system.size()).map { system[it].language }
            .firstOrNull { it in languages } ?: "en"
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocales(LocaleList(Locale.forLanguageTag(language)))
        return context.createConfigurationContext(configuration).getString(resource)
    }

    fun tileLabels(context: Context) = QuickSettingsState.Labels(
        connecting = text(context, R.string.vpn_connecting),
        disconnecting = text(context, R.string.vpn_disconnecting),
        connected = text(context, R.string.vpn_connected),
        disconnected = text(context, R.string.vpn_disconnected),
        busy = text(context, R.string.vpn_busy),
    )
}
