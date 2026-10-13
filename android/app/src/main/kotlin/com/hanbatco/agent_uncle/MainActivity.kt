package com.hanbatco.agent_uncle

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var addressSearchPlugin: AddressSearchPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        addressSearchPlugin?.dispose()
        addressSearchPlugin = AddressSearchPlugin(
            flutterEngine.dartExecutor.binaryMessenger,
            this,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        addressSearchPlugin?.dispose()
        addressSearchPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
