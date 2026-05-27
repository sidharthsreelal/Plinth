package com.example.plinth

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

/**
 * Main entry-point activity.
 *
 * Extends AudioServiceActivity so that just_audio_background's media session
 * integration works correctly (foreground service, notification controls, etc.).
 *
 * Also sets up a single MethodChannel for Flutter → Android widget state push.
 * The widget provider itself (PlinthWidgetProvider) has ZERO Flutter imports —
 * it reads state from SharedPreferences and dispatches controls via MediaSession.
 */
class MainActivity : AudioServiceActivity() {

    private val WIDGET_STATE_CHANNEL = "com.example.plinth/widget_state"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_STATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pushState" -> {
                        val title     = call.argument<String>("title") ?: "Not Playing"
                        val artist    = call.argument<String>("artist") ?: ""
                        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                        val artPath   = call.argument<String>("artPath")

                        PlinthWidgetProvider.pushState(
                            applicationContext, title, artist, isPlaying, artPath
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
