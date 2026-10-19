// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import java.io.File
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class AndroidUpdateCacheTest {
    private fun fixture(block: (File) -> Unit) {
        val root = Files.createTempDirectory("aora-update-cache-test-").toFile()
        try { block(root) } finally { root.deleteRecursively() }
    }

    @Test fun removesAllObsoleteVersionsAndInterruptedCopies() = fixture { root ->
        for (build in listOf(0L, 1L, 2L)) {
            val apk = File(root, "aora-update-$build.apk").apply { writeText("copy") }
            File(apk.path + ".installing").writeText(build.toString())
        }
        AndroidUpdateCache.cleanup(root, 2) { error("Marked copies need no inspection") }
        assertTrue(root.listFiles()!!.isEmpty())
    }

    @Test fun preservesEveryNewerHandoffUntilInstalled() = fixture { root ->
        for (build in listOf(3L, 4L)) {
            val apk = File(root, "aora-update-$build.apk").apply { writeText("copy") }
            File(apk.path + ".installing").writeText(build.toString())
        }
        AndroidUpdateCache.cleanup(root, 2) { error("unexpected") }
        assertEquals(4, root.listFiles()!!.size)
        AndroidUpdateCache.cleanup(root, 4) { error("unexpected") }
        assertTrue(root.listFiles()!!.isEmpty())
    }

    @Test fun legacyCopiesMustAuthenticateAndBeObsolete() = fixture { root ->
        val old = File(root, "aora-update-old.apk").apply { writeText("signed old") }
        val newer = File(root, "aora-update-new.apk").apply { writeText("signed new") }
        val unknown = File(root, "aora-update-unknown.apk").apply { writeText("unknown") }
        AndroidUpdateCache.cleanup(root, 2) {
            when (it) { old -> 1; newer -> 3; else -> error("Cannot authenticate") }
        }
        assertFalse(old.exists())
        assertTrue(newer.exists())
        assertTrue(unknown.exists())
    }

    @Test fun unrelatedFilesDirectoriesAndMalformedMarkersArePreserved() = fixture { root ->
        val unrelated = File(root, "manual.apk").apply { writeText("keep") }
        val folder = File(root, "aora-update-folder.apk").apply { mkdir() }
        val unknown = File(root, "aora-update-marker.apk").apply { writeText("keep") }
        File(unknown.path + ".installing").writeText("not a build")
        val orphan = File(root, "aora-update-orphan.apk.installing").apply { writeText("0") }
        AndroidUpdateCache.cleanup(root, 2) { error("unexpected") }
        assertTrue(unrelated.exists())
        assertTrue(folder.exists())
        assertTrue(unknown.exists())
        assertFalse(orphan.exists())
    }
}
