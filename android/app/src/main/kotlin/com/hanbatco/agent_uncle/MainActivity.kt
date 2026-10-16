package com.hanbatco.agent_uncle

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var nativeMediaPicker: NativeMediaPicker? = null
    private var addressSearchPlugin: AddressSearchPlugin? = null
    private var legalDocumentsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        legalDocumentsChannel?.setMethodCallHandler(null)
        legalDocumentsChannel = null
        nativeMediaPicker?.dispose()
        nativeMediaPicker = null
        addressSearchPlugin?.dispose()
        addressSearchPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
