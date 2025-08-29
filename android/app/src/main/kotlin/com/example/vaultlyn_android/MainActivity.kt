package com.example.vaultlyn_android

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.channel.shared.data"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setDisguiseApp") {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setDisguiseApp(enabled)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setDisguiseApp(enabled: Boolean) {
        val pm = packageManager
        val defaultComponent = ComponentName(this, "com.example.vaultlyn_android.MainActivity")
        val aliasComponent = ComponentName(this, "com.example.vaultlyn_android.AliasActivity")

        pm.setComponentEnabledSetting(
            defaultComponent,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_DISABLED else PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        pm.setComponentEnabledSetting(
            aliasComponent,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }
}
