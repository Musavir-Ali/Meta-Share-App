package com.share1.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Direct handoff into Instagram and Facebook.
 *
 * Stories use the documented implicit intents. Feed uses ACTION_SEND with the
 * image stream pointed at the target app, which is the Android feed flow from
 * Meta's sharing docs.
 */
class MetaShareHandler(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "share") {
            result.notImplemented()
            return
        }

        val destination = call.argument<String>("destination")
        val filePath = call.argument<String>("filePath")
        val appId = call.argument<String>("facebookAppId")?.trim().orEmpty()

        if (destination.isNullOrBlank() || filePath.isNullOrBlank()) {
            result.error("invalid_args", "A photo and a share destination are required.", null)
            return
        }

        val needsAppId = destination == "instagram_story" || destination == "facebook_story"
        if (needsAppId && appId.isEmpty()) {
            result.error(
                "missing_app_id",
                "Add your Facebook App ID before sharing to Stories.",
                null,
            )
            return
        }

        try {
            val shared = copyToShareCache(filePath)
            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                shared,
            )
            val mime = mimeFor(shared)
            when (destination) {
                "instagram_story" -> shareInstagramStory(uri, mime, appId)
                "instagram_feed" -> shareFeed(uri, mime, "com.instagram.android", "Instagram")
                "facebook_story" -> shareFacebookStory(uri, mime, appId)
                "facebook_feed" -> shareFacebookFeed(uri, mime)
                else -> {
                    result.error("invalid_args", "Unknown share destination.", null)
                    return
                }
            }
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("not_installed", error.message, null)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_file", error.message, null)
        } catch (error: Exception) {
            result.error("failed", error.message ?: "Could not share the photo.", null)
        }
    }

    private fun shareInstagramStory(uri: Uri, mime: String, appId: String) {
        val packageName = "com.instagram.android"
        ensureInstalled(packageName, "Instagram")
        val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            setPackage(packageName)
            setDataAndType(uri, mime)
            putExtra("source_application", appId)
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            clipData = ClipData.newUri(activity.contentResolver, "image", uri)
        }
        grantAndLaunch(intent, packageName, uri, "Instagram")
    }

    private fun shareFacebookStory(uri: Uri, mime: String, appId: String) {
        val packageName = "com.facebook.katana"
        ensureInstalled(packageName, "Facebook")
        val intent = Intent("com.facebook.stories.ADD_TO_STORY").apply {
            setPackage(packageName)
            setDataAndType(uri, mime)
            putExtra("com.facebook.platform.extra.APPLICATION_ID", appId)
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            clipData = ClipData.newUri(activity.contentResolver, "image", uri)
        }
        grantAndLaunch(intent, packageName, uri, "Facebook")
    }

    private fun shareFacebookFeed(uri: Uri, mime: String) {
        val packageName = listOf("com.facebook.katana", "com.facebook.lite")
            .firstOrNull { isInstalled(it) }
            ?: throw ActivityNotFoundException("Facebook is not installed.")
        shareFeed(uri, mime, packageName, "Facebook")
    }

    private fun shareFeed(uri: Uri, mime: String, packageName: String, appName: String) {
        ensureInstalled(packageName, appName)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            setPackage(packageName)
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData = ClipData.newUri(activity.contentResolver, "image", uri)
        }
        grantAndLaunch(intent, packageName, uri, appName)
    }

    private fun grantAndLaunch(intent: Intent, packageName: String, uri: Uri, appName: String) {
        activity.grantUriPermission(packageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (intent.resolveActivity(activity.packageManager) == null) {
            throw ActivityNotFoundException("$appName cannot open this photo.")
        }
        activity.startActivity(intent)
    }

    private fun ensureInstalled(packageName: String, appName: String) {
        if (!isInstalled(packageName)) {
            throw ActivityNotFoundException("$appName is not installed.")
        }
    }

    private fun isInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                activity.packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun copyToShareCache(path: String): File {
        val source = File(path)
        if (!source.isFile) {
            throw IllegalArgumentException("The selected photo is no longer available.")
        }
        val shareDir = File(activity.cacheDir, "share").apply { mkdirs() }
        val extension = source.extension.lowercase().ifBlank { "jpg" }
        val dest = File(shareDir, "share-${System.currentTimeMillis()}.$extension")
        source.inputStream().use { input ->
            dest.outputStream().use { output -> input.copyTo(output) }
        }
        return dest
    }

    private fun mimeFor(file: File): String {
        return when (file.extension.lowercase()) {
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            else -> "image/jpeg"
        }
    }
}
