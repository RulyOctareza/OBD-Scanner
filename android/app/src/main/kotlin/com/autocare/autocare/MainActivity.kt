package com.autocare.autocare

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Dart side: lib/core/services/background_service.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "autocare/obd_link_service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(
                        ObdLinkService.start(
                            applicationContext,
                            call.argument<String>("title") ?: "AutoCare",
                            call.argument<String>("text") ?: "",
                        ),
                    )
                    "stop" -> {
                        ObdLinkService.stop(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        // The Dart side (and the OBD link) ends with this activity's engine;
        // a configuration change recreates it, so the service stays then.
        if (!isChangingConfigurations) ObdLinkService.stop(applicationContext)
        super.onDestroy()
    }
}
