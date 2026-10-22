// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

internal object InstalledApplications {
    private val worker = Executors.newSingleThreadExecutor { Thread(it, "aora-app-picker") }
    private val main = Handler(Looper.getMainLooper())

    fun load(context: Context, result: MethodChannel.Result) {
        worker.execute {
            try {
                val manager = context.packageManager
                val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                val apps = manager.queryIntentActivities(intent, 0)
                    .distinctBy { it.activityInfo.packageName }
                    .filter { it.activityInfo.packageName != context.packageName }
                    .map { info ->
                        val packageName = info.activityInfo.packageName
                        val label = runCatching { info.loadLabel(manager).toString() }
                            .getOrDefault(packageName)
                        val icon = runCatching {
                            val bitmap = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888)
                            try {
                                info.loadIcon(manager).apply { setBounds(0, 0, 64, 64) }.draw(Canvas(bitmap))
                                ByteArrayOutputStream().use {
                                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                                    it.toByteArray()
                                }
                            } finally { bitmap.recycle() }
                        }.getOrNull()
                        mapOf("packageName" to packageName, "label" to label, "icon" to icon)
                    }.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it["label"] as String })
                main.post { result.success(apps) }
            } catch (error: Exception) {
                main.post { result.error("APPLICATIONS", "Could not load installed applications.", null) }
            }
        }
    }
}
