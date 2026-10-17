package com.vaaradhi.vaaradhi

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.StaticOverlaySettings
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max
import kotlin.math.min

/**
 * Stamps the Vaaradhi logo badge (logo + "వారధి" on a dark tab, as on the
 * in-app photos) in the top-right corner of a video, on the phone, with
 * Media3 Transformer. Used by the Spotlight video download.
 */
@OptIn(UnstableApi::class)
class VideoWatermarker(private val context: Context) {

    fun handle(input: String, output: String, label: String, result: MethodChannel.Result) {
        try {
            val (w, h) = videoSize(input)
            val badge = buildBadge(min(w, h), label)
            val settings = StaticOverlaySettings.Builder()
                // Overlay's top-right corner on a point just inside the
                // frame's top-right corner (coordinates: -1..1, y up).
                .setOverlayFrameAnchor(1f, 1f)
                .setBackgroundFrameAnchor(0.97f, 0.96f)
                .build()
            val overlay = BitmapOverlay.createStaticBitmapOverlay(badge, settings)
            val effects = Effects(
                ImmutableList.of(),
                ImmutableList.of<Effect>(
                    OverlayEffect(ImmutableList.of<TextureOverlay>(overlay)),
                ),
            )
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
                .setEffects(effects)
                .build()
            File(output).delete()
            val transformer = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        result.success(output)
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        result.error("export_failed", exportException.message, null)
                    }
                })
                .build()
            transformer.start(item, output)
        } catch (e: Throwable) {
            result.error("watermark_failed", e.message, null)
        }
    }

    /** Displayed width and height (rotation applied). */
    private fun videoSize(path: String): Pair<Int, Int> {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 720
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 1280
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            return if (rot == 90 || rot == 270) Pair(h, w) else Pair(w, h)
        } finally {
            r.release()
        }
    }

    /** The badge, sized to the video: about 7% of its short side tall. */
    private fun buildBadge(shortSide: Int, label: String): Bitmap {
        val h = max(36, (shortSide * 0.075f).toInt())
        val pad = h * 0.16f
        val logoSide = h - pad * 2
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = h * 0.46f
            typeface = Typeface.DEFAULT_BOLD
        }
        val textW = textPaint.measureText(label)
        val w = (pad + logoSide + pad * 1.2f + textW + pad * 1.6f).toInt()

        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(185, 0, 0, 0) }
        c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), h * 0.22f, h * 0.22f, bg)

        val white = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        val logoRect = RectF(pad, pad, pad + logoSide, pad + logoSide)
        c.drawRoundRect(logoRect, logoSide * 0.18f, logoSide * 0.18f, white)
        loadLogo()?.let { logo ->
            val inset = logoSide * 0.07f
            val dst = RectF(
                logoRect.left + inset, logoRect.top + inset,
                logoRect.right - inset, logoRect.bottom - inset,
            )
            c.drawBitmap(logo, null, dst, Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        }
        val baseline = h / 2f - (textPaint.descent() + textPaint.ascent()) / 2f
        c.drawText(label, pad + logoSide + pad * 1.2f, baseline, textPaint)
        return bmp
    }

    private fun loadLogo(): Bitmap? = try {
        val key = FlutterInjector.instance().flutterLoader()
            .getLookupKeyForAsset("assets/images/logo.png")
        context.assets.open(key).use { BitmapFactory.decodeStream(it) }
    } catch (e: Throwable) {
        null
    }
}
