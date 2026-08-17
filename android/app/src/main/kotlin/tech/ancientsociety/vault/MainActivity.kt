package tech.ancientsociety.vault

import android.content.Context
import android.telephony.TelephonyManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenSecurityChannel = "ancient_secure_docs/screen_security"
    private val deviceContextChannel = "ancient_secure_docs/device_context"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenSecurityChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureScreen" -> {
                    runOnUiThread {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "disableSecureScreen" -> {
                    runOnUiThread {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "enableReaderStayAwake" -> {
                    runOnUiThread {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "disableReaderStayAwake" -> {
                    runOnUiThread {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceContextChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCountryCode" -> {
                    val telephonyManager =
                        getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                    val countryCode = sequenceOf(
                        telephonyManager.networkCountryIso,
                        telephonyManager.simCountryIso
                    ).map { it.trim().uppercase() }
                        .firstOrNull { it.length == 2 }
                    result.success(countryCode)
                }
                else -> result.notImplemented()
            }
        }
    }
}
