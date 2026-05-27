package com.example.plinth

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.widget.RemoteViews

/**
 * Home screen widget — 4×1.
 *
 * Architecture:
 *   • ZERO Flutter imports. This class runs in the app process but may be
 *     instantiated by the system before the Flutter engine is loaded.
 *     Using only android.* APIs prevents NoClassDefFoundError.
 *   • Track state (title, artist, isPlaying, artPath) is read from
 *     SharedPreferences, written by MainActivity's MethodChannel handler.
 *   • Button presses dispatch MediaSession transport controls via
 *     MediaController, which talks to the AudioService media session
 *     managed by just_audio_background. No MethodChannel needed.
 */
class PlinthWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "PlinthWidget"

        const val ACTION_PREV       = "com.example.plinth.widget.PREV"
        const val ACTION_PLAY_PAUSE = "com.example.plinth.widget.PLAY_PAUSE"
        const val ACTION_NEXT       = "com.example.plinth.widget.NEXT"

        private const val PREFS = "PlinthWidgetState"
        private const val KEY_TITLE      = "title"
        private const val KEY_ARTIST     = "artist"
        private const val KEY_IS_PLAYING = "isPlaying"
        private const val KEY_ART_PATH   = "artPath"

        /**
         * Called by MainActivity when Flutter pushes new track state.
         * Writes to SharedPreferences then triggers all widget instances to refresh.
         */
        fun pushState(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean,
            artPath: String?
        ) {
            try {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                    putString(KEY_TITLE, title)
                    putString(KEY_ARTIST, artist)
                    putBoolean(KEY_IS_PLAYING, isPlaying)
                    putString(KEY_ART_PATH, artPath)
                    apply()
                }
                refreshAll(context)
            } catch (e: Exception) {
                Log.e(TAG, "pushState failed", e)
            }
        }

        /** Trigger onUpdate for every placed widget instance. */
        fun refreshAll(context: Context) {
            try {
                val mgr = AppWidgetManager.getInstance(context)
                val cn = ComponentName(context, PlinthWidgetProvider::class.java)
                val ids = mgr.getAppWidgetIds(cn)
                if (ids != null && ids.isNotEmpty()) {
                    val intent = Intent(context, PlinthWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    context.sendBroadcast(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "refreshAll failed", e)
            }
        }
    }

    // ── AppWidgetProvider callbacks ─────────────────────────────────────────

    override fun onUpdate(
        context: Context,
        mgr: AppWidgetManager,
        ids: IntArray
    ) {
        for (id in ids) {
            try {
                val views = buildViews(context)
                mgr.updateAppWidget(id, views)
            } catch (e: Exception) {
                Log.e(TAG, "onUpdate($id) failed", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            super.onReceive(context, intent)
        } catch (e: Exception) {
            Log.e(TAG, "super.onReceive failed", e)
        }

        try {
            when (intent.action) {
                ACTION_PLAY_PAUSE -> dispatchMediaAction(context, "playPause")
                ACTION_PREV       -> dispatchMediaAction(context, "prev")
                ACTION_NEXT       -> dispatchMediaAction(context, "next")
            }
        } catch (e: Exception) {
            Log.e(TAG, "onReceive action failed", e)
        }
    }

    // ── Media control dispatch ─────────────────────────────────────────────

    /**
     * Dispatches play/pause/next/prev via media button key events sent to the
     * AudioService MediaButtonReceiver. This is the standard, permission-free
     * approach used by all Android music widgets. Works even when the app is
     * fully backgrounded — the MediaButtonReceiver is always registered.
     */
    private fun dispatchMediaAction(context: Context, action: String) {
        val keyCode = when (action) {
            "playPause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "prev"      -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            "next"      -> KeyEvent.KEYCODE_MEDIA_NEXT
            else        -> return
        }
        try {
            val now = SystemClock.uptimeMillis()
            val receiverCn = ComponentName(
                context.packageName,
                "com.ryanheise.audioservice.MediaButtonReceiver"
            )
            // ACTION_DOWN
            context.sendBroadcast(
                Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    component = receiverCn
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0))
                }
            )
            // ACTION_UP
            context.sendBroadcast(
                Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    component = receiverCn
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0))
                }
            )
            Log.d(TAG, "dispatchMediaAction: $action (keyCode=$keyCode) sent")
        } catch (e: Exception) {
            Log.e(TAG, "dispatchMediaAction($action) failed", e)
        }
    }

    // ── Build RemoteViews ──────────────────────────────────────────────────

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.plinth_widget_layout)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        // ── Text ───────────────────────────────────────────────────────
        val title = prefs.getString(KEY_TITLE, null) ?: "Not Playing"
        val artist = prefs.getString(KEY_ARTIST, null)
        val trackInfo = if (!artist.isNullOrBlank() && artist != "Unknown Artist") {
            "$title  —  $artist"
        } else {
            title
        }
        views.setTextViewText(R.id.widget_track_info, trackInfo)

        // ── Control icons (procedurally rendered) ──────────────────────
        val isPlaying = prefs.getBoolean(KEY_IS_PLAYING, false)
        views.setImageViewBitmap(R.id.widget_btn_prev, drawPrevIcon(64))
        views.setImageViewBitmap(R.id.widget_btn_play_pause,
            if (isPlaying) drawPauseIcon(64) else drawPlayIcon(64))
        views.setImageViewBitmap(R.id.widget_btn_next, drawNextIcon(64))

        // ── Album art ──────────────────────────────────────────────────
        val artPath = prefs.getString(KEY_ART_PATH, null)
        if (artPath != null) {
            try {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(artPath, bounds)
                val maxDim = maxOf(bounds.outWidth, bounds.outHeight).coerceAtLeast(1)
                val sample = maxOf(1, Integer.highestOneBit(maxDim / 160))
                val opts = BitmapFactory.Options().apply { inSampleSize = sample }
                val raw = BitmapFactory.decodeFile(artPath, opts)
                if (raw != null) {
                    val scaled = Bitmap.createScaledBitmap(raw, 160, 160, true)
                    if (scaled !== raw) raw.recycle()
                    views.setImageViewBitmap(R.id.widget_album_art, scaled)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Art load failed", e)
            }
        }

        // ── PendingIntents ─────────────────────────────────────────────
        views.setOnClickPendingIntent(R.id.widget_btn_prev,
            makeBroadcast(context, ACTION_PREV, 1))
        views.setOnClickPendingIntent(R.id.widget_btn_play_pause,
            makeBroadcast(context, ACTION_PLAY_PAUSE, 2))
        views.setOnClickPendingIntent(R.id.widget_btn_next,
            makeBroadcast(context, ACTION_NEXT, 3))

        // Tap anywhere else → open app
        try {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Launch PI failed", e)
        }

        return views
    }

    private fun makeBroadcast(context: Context, action: String, code: Int): PendingIntent {
        val intent = Intent(context, PlinthWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // ── Procedural icon rendering ──────────────────────────────────────────
    // All icons rendered via Canvas + Paint. No drawable resources needed.
    // This guarantees RemoteViews never has to resolve any drawable, eliminating
    // the entire class of inflation crashes.

    private fun drawPlayIcon(size: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            style = Paint.Style.FILL
        }
        val s = size.toFloat()
        val path = Path().apply {
            moveTo(s * 0.25f, s * 0.15f)
            lineTo(s * 0.80f, s * 0.50f)
            lineTo(s * 0.25f, s * 0.85f)
            close()
        }
        canvas.drawPath(path, paint)
        return bmp
    }

    private fun drawPauseIcon(size: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            style = Paint.Style.FILL
        }
        val s = size.toFloat()
        // Left bar
        canvas.drawRoundRect(
            RectF(s * 0.22f, s * 0.18f, s * 0.42f, s * 0.82f),
            s * 0.04f, s * 0.04f, paint
        )
        // Right bar
        canvas.drawRoundRect(
            RectF(s * 0.58f, s * 0.18f, s * 0.78f, s * 0.82f),
            s * 0.04f, s * 0.04f, paint
        )
        return bmp
    }

    private fun drawPrevIcon(size: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xCCFFFFFF.toInt()
            style = Paint.Style.FILL
        }
        val s = size.toFloat()
        // Left bar (skip marker)
        canvas.drawRect(s * 0.18f, s * 0.22f, s * 0.25f, s * 0.78f, paint)
        // Triangle pointing left
        val path = Path().apply {
            moveTo(s * 0.75f, s * 0.22f)
            lineTo(s * 0.30f, s * 0.50f)
            lineTo(s * 0.75f, s * 0.78f)
            close()
        }
        canvas.drawPath(path, paint)
        return bmp
    }

    private fun drawNextIcon(size: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xCCFFFFFF.toInt()
            style = Paint.Style.FILL
        }
        val s = size.toFloat()
        // Triangle pointing right
        val path = Path().apply {
            moveTo(s * 0.25f, s * 0.22f)
            lineTo(s * 0.70f, s * 0.50f)
            lineTo(s * 0.25f, s * 0.78f)
            close()
        }
        canvas.drawPath(path, paint)
        // Right bar (skip marker)
        canvas.drawRect(s * 0.75f, s * 0.22f, s * 0.82f, s * 0.78f, paint)
        return bmp
    }
}
