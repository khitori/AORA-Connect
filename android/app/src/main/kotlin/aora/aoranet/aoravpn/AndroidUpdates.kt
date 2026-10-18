// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import com.android.apksig.ApkVerifier
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/** APK authenticity is checked against the installed app, not the download host. */
internal class AndroidUpdates(private val activity: MainActivity) {
    companion object {
        const val PERMISSION_REQUEST = 703
        const val INSTALL_REQUEST = 704
        const val MAX_APK_SIZE = 512L * 1024 * 1024
    }
    private val worker = Executors.newSingleThreadExecutor { Thread(it, "aora-updates") }
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var installerFile: File? = null

    private fun versionCode(info: PackageInfo) = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    private fun ownInfo(): PackageInfo = activity.packageManager.getPackageInfo(activity.packageName,
        if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES)
    private fun digest(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes)
        .joinToString("") { "%02x".format(it) }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> run(result) {
                val info = ownInfo()
                mapOf("version" to "${info.versionName}+${versionCode(info)}")
            }
            "verifyApk" -> run(result) { verify(privateFile(requireNotNull(call.argument<String>("path")))) }
            "installApk" -> {
                if (pending != null) { result.error("BUSY", "An installation is already open.", null); return }
                pending = result
                worker.execute {
                    try {
                        check(VpnRuntime.state == "stopped") { "Disconnect before installing an update." }
                        val source = privateFile(requireNotNull(call.argument<String>("path")))
                        val directory = File(activity.cacheDir, "updates").apply { mkdirs() }
                        val target = File.createTempFile("aora-update-", ".apk", directory)
                        installerFile = target
                        source.copyTo(target, overwrite = true)
                        verify(target)
                        main.post {
                            try {
                                if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                                    activity.startActivityForResult(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:${activity.packageName}")), PERMISSION_REQUEST)
                                } else openInstaller()
                            } catch (error: Exception) { finish(error) }
                        }
                    } catch (error: Exception) { main.post { finish(error) } }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun run(result: MethodChannel.Result, operation: () -> Any) {
        worker.execute {
            try { val value = operation(); main.post { result.success(value) } }
            catch (error: Exception) { main.post { result.error("UPDATE", error.message ?: "APK verification failed.", null) } }
        }
    }

    private fun privateFile(path: String): File {
        val file = File(path).canonicalFile
        val root = File(activity.filesDir, "runtime").canonicalPath + File.separator
        require(file.path.startsWith(root) && file.isFile) { "Update must be staged in private application storage." }
        return file
    }

    private fun verify(file: File): Map<String, Any> {
        require(file.length() in 1..MAX_APK_SIZE) { "Invalid APK size." }
        val verified = ApkVerifier.Builder(file)
            .setMinCheckedPlatformVersion(Build.VERSION.SDK_INT)
            .setMaxCheckedPlatformVersion(Build.VERSION.SDK_INT).build().verify()
        require(verified.isVerified) { "APK signature is invalid or the file has been modified." }
        val installed = ownInfo()
        val installedSigners = if (Build.VERSION.SDK_INT >= 28)
            installed.signingInfo!!.apkContentsSigners else installed.signatures!!
        val trusted = installedSigners.map { digest(it.toByteArray()) }.sorted()
        val actual = verified.signerCertificates.map { digest(it.encoded) }.sorted()
        require(actual.isNotEmpty() && actual == trusted) {
            "APK signing key does not match this installation. Development and release builds use different keys."
        }
        val archive = activity.packageManager.getPackageArchiveInfo(file.path, 0)
            ?: error("Could not read the APK manifest.")
        require(archive.packageName == activity.packageName) { "APK belongs to a different application." }
        require(archive.applicationInfo?.minSdkVersion?.let { it <= Build.VERSION.SDK_INT } == true) {
            "This APK requires a newer Android version."
        }
        val nextCode = versionCode(archive)
        require(nextCode > versionCode(installed)) { "Choose an APK with a newer Android build number." }
        val name = archive.versionName ?: error("APK has no version name.")
        require(Regex("[0-9]+\\.[0-9]+\\.[0-9]+").matches(name)) { "APK version name is invalid." }
        val hash = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) { val count = input.read(buffer); if (count < 0) break; hash.update(buffer, 0, count) }
        }
        return mapOf("version" to "$name+$nextCode", "size" to file.length(),
            "sha256" to hash.digest().joinToString("") { "%02x".format(it) },
            "urls" to emptyList<String>(), "notes" to "")
    }

    private fun openInstaller() {
        worker.execute {
            try {
                check(VpnRuntime.state == "stopped") { "Disconnect before installing an update." }
                val file = installerFile ?: error("No verified APK is ready.")
                verify(file)
                main.post {
                    try {
                        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).setData(uri)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            .putExtra(Intent.EXTRA_RETURN_RESULT, true)
                        intent.clipData = ClipData.newRawUri("AORA update", uri)
                        activity.startActivityForResult(intent, INSTALL_REQUEST)
                    } catch (error: Exception) { finish(error) }
                }
            } catch (error: Exception) { main.post { finish(error) } }
        }
    }

    fun onActivityResult(code: Int, resultCode: Int): Boolean {
        if (code != PERMISSION_REQUEST && code != INSTALL_REQUEST) return false
        if (pending == null) return true
        if (code == PERMISSION_REQUEST) {
            if (Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls()) openInstaller()
            else finish(IllegalStateException("Allow AORA Connect to install updates, then try again."))
        } else if (resultCode == Activity.RESULT_OK) finish()
        else finish(IllegalStateException("Installation cancelled or rejected by Android."))
        return true
    }

    private fun finish(error: Exception? = null) {
        val result = pending
        pending = null
        installerFile?.delete()
        installerFile = null
        if (error == null) result?.success(null)
        else result?.error("INSTALL", error.message, null)
    }

    fun close() {
        if (pending != null) finish(IllegalStateException("Installation interrupted."))
        worker.shutdown()
    }
}
