package com.hanbatco.agent_uncle

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var nativeMediaPicker: NativeMediaPicker? = null
    private var addressSearchPlugin: AddressSearchPlugin? = null
    private var legalDocumentsChannel: MethodChannel? = null
    private var appReleaseChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appReleaseChannel?.setMethodCallHandler(null)
        appReleaseChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "agent_uncle/app_release",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "info" -> {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
                        result.success(mapOf("platform" to "android", "version" to info.versionName, "buildNumber" to code.toString()))
                    }
                    "openStore" -> {
                        val uri = call.argument<String>("url")?.let(Uri::parse)
                        if (uri == null || uri.scheme != "https" || uri.host != "play.google.com" ||
                            uri.userInfo != null || uri.port != -1 || uri.fragment != null ||
                            uri.path != "/store/apps/details" || uri.getQueryParameter("id").isNullOrBlank()) {
                            result.success(false)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                                result.success(true)
                            } catch (_: ActivityNotFoundException) {
                                result.success(false)
                            } catch (_: SecurityException) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        legalDocumentsChannel?.setMethodCallHandler(null)
        legalDocumentsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "agent_uncle/legal_documents",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.argument<String>("url")
                if (url !in setOf("https://www.the-saena.ai/terms", "https://www.the-saena.ai/privacy")) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                } catch (_: SecurityException) {
                    result.success(false)
                }
            }
        }
        nativeMediaPicker?.dispose()
        addressSearchPlugin?.dispose()
        nativeMediaPicker = NativeMediaPicker(this, flutterEngine.dartExecutor.binaryMessenger)
        addressSearchPlugin = AddressSearchPlugin(
            flutterEngine.dartExecutor.binaryMessenger,
            this,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        appReleaseChannel?.setMethodCallHandler(null)
        appReleaseChannel = null
        legalDocumentsChannel?.setMethodCallHandler(null)
        legalDocumentsChannel = null
        nativeMediaPicker?.dispose()
        nativeMediaPicker = null
        addressSearchPlugin?.dispose()
        addressSearchPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
