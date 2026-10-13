package com.hanbatco.agent_uncle

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var nativeMediaPicker: NativeMediaPicker? = null
    private var addressSearchPlugin: AddressSearchPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeMediaPicker?.dispose()
        addressSearchPlugin?.dispose()
        nativeMediaPicker = NativeMediaPicker(this, flutterEngine.dartExecutor.binaryMessenger)
        addressSearchPlugin = AddressSearchPlugin(
            flutterEngine.dartExecutor.binaryMessenger,
            this,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nativeMediaPicker?.dispose()
        nativeMediaPicker = null
        addressSearchPlugin?.dispose()
        addressSearchPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
