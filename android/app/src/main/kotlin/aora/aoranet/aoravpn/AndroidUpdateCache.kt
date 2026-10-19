// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import java.io.File

/** Bounded to our private installer copies; no recursive deletion or link following. */
internal object AndroidUpdateCache {
    private val apkName = Regex("aora-update-[a-zA-Z0-9_-]+\\.apk")

    fun cleanup(directory: File, installedBuild: Long, inspectBuild: (File) -> Long) {
        val parent = directory.parentFile ?: return
        val canonicalDirectory = File(parent.canonicalFile, directory.name)
        if (!directory.isDirectory || directory.canonicalFile != canonicalDirectory) return
        for (file in directory.listFiles().orEmpty()) {
            try {
                if (!apkName.matches(file.name) || !file.isFile ||
                    file.canonicalFile != File(canonicalDirectory, file.name)) continue
                val marker = File(file.path + ".installing")
                if (marker.canonicalFile != File(canonicalDirectory, marker.name)) continue
                val build = if (marker.exists()) {
                    if (marker.length() > 32) continue
                    marker.readText().toLongOrNull() ?: continue
                } else {
                    // Legacy copies may have been handed to Android before
                    // handoff records existed. Only delete authenticated old APKs.
                    inspectBuild(file)
                }
                if (build < 0 || build > installedBuild) continue
                if (file.delete()) marker.delete()
            } catch (_: Exception) { /* Unknown or inaccessible: preserve and retry. */ }
        }
        for (marker in directory.listFiles().orEmpty()) {
            if (!marker.name.endsWith(".installing")) continue
            val apk = File(directory, marker.name.removeSuffix(".installing"))
            if (apkName.matches(apk.name) && !apk.exists() && marker.isFile &&
                marker.canonicalFile == File(canonicalDirectory, marker.name)) marker.delete()
        }
    }
}
