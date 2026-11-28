package com.trakvrs.fitns

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * The pictures in FITNS's widgets, drawn in code — a widget's layout can't
 * draw gradient rings, contour lines or a filling glass by itself. Each is
 * a bitmap for an ImageView; the numbers stay real text beside them.
 *
 * Bitmaps travel to the launcher in one parcel with a ~1 MB limit, so they
 * are drawn at most 2× and kept small.
 */
object WidgetArt {
    /** A ring's colours: start and end of its sweep. */
    class Hue(val from: Int, val to: Int)

    val STEPS = Hue(0xFFFFB547.toInt(), 0xFFFF5A1F.toInt())
    val BURN = Hue(0xFFFF8A4C.toInt(), 0xFFE11D48.toInt())
    val WEIGHT = Hue(0xFF5EEAD4.toInt(), 0xFF6366F1.toInt())
    val WATER = Hue(0xFF6BE4FF.toInt(), 0xFF2F7BFF.toInt())
    val KCAL = Hue(0xFFFF7AC6.toInt(), 0xFFA855F7.toInt())
    val PROTEIN = Hue(0xFF60A5FA.toInt(), 0xFF3B82F6.toInt())
    val CARBS = Hue(0xFFFCD34D.toInt(), 0xFFF59E0B.toInt())
    val FAT = Hue(0xFFF9A8D4.toInt(), 0xFFEC4899.toInt())

    fun dark(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    private fun scale(context: Context) = min(context.resources.displayMetrics.density, 2f)

    private fun bitmap(context: Context, wDp: Float, hDp: Float): Pair<Bitmap, Float> {
        val s = scale(context)
        val b = Bitmap.createBitmap(
            max(1, (wDp * s).toInt()),
            max(1, (hDp * s).toInt()),
            Bitmap.Config.ARGB_8888,
        )
        return b to s
    }

    /**
     * Concentric activity rings, outermost first: each [fractions] value
     * (0–1, more is clamped) sweeps its [hues] ring from the top, with
     * round ends, over a faint track of its own colour.
     */
    fun rings(context: Context, sizeDp: Float, fractions: List<Float>, hues: List<Hue>): Bitmap {
        val (b, s) = bitmap(context, sizeDp, sizeDp)
        val c = Canvas(b)
        val size = sizeDp * s
        val n = fractions.size
        // Thick rings with a small gap, like a fitness tracker's.
        val stroke = size / (2f * n + 3f) * 0.86f
        val gap = stroke * 0.38f
        for (i in 0 until n) {
            val inset = stroke / 2 + i * (stroke + gap) + 1
            val rect = RectF(inset, inset, size - inset, size - inset)
            ring(c, rect, stroke, fractions[i], hues[i])
        }
        return b
    }

    private fun ring(c: Canvas, rect: RectF, stroke: Float, fraction: Float, hue: Hue) {
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            color = hue.to
            alpha = 52
        }
        c.drawOval(rect, track)
        val f = fraction.coerceIn(0f, 1f)
        if (f <= 0f) return
        val sweep = max(f * 360f, 1f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
            // The gradient runs along the arc, from its start to its end.
            shader = SweepGradient(
                rect.centerX(),
                rect.centerY(),
                intArrayOf(hue.from, hue.to, hue.to),
                floatArrayOf(0f, max(f, 0.01f), 1f),
            ).also {
                it.setLocalMatrix(Matrix().apply { setRotate(-90f, rect.centerX(), rect.centerY()) })
            }
        }
        c.drawArc(rect, -90f, sweep, false, paint)
        if (f >= 1f) {
            // A full ring: the end cap shows where it closed.
            c.drawArc(rect, -90f + 359f, 1f, false, paint.apply { shader = null; color = hue.to })
        }
    }

    /**
     * The last seven days as small rings with their initials under them,
     * oldest first — weekends in a warmer tone, today's initial bold.
     */
    fun week(
        context: Context,
        widthDp: Float,
        heightDp: Float,
        days: List<Triple<Float, Float, Float>>,
        letters: List<String>,
        weekend: List<Boolean>,
    ): Bitmap {
        val (b, s) = bitmap(context, widthDp, heightDp)
        val c = Canvas(b)
        val w = widthDp * s
        val h = heightDp * s
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = 11 * s
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val labelH = text.textSize * 1.5f
        val slot = w / 7f
        val ringSize = min(slot * 0.78f, h - labelH)
        val muted = if (dark(context)) 0xFF98989F.toInt() else 0xFF6E6E73.toInt()
        for (i in 0 until min(7, days.size)) {
            val cx = slot * i + slot / 2
            text.color = if (weekend.getOrElse(i) { false }) 0xFFFF6B6B.toInt() else muted
            text.isFakeBoldText = i == days.size - 1
            c.drawText(letters.getOrElse(i) { "" }, cx, text.textSize, text)
            val d = days[i]
            val stroke = ringSize / 9f * 0.86f
            val gap = stroke * 0.38f
            val top = labelH + (h - labelH - ringSize) / 2
            listOf(d.first to STEPS, d.second to WATER, d.third to KCAL).forEachIndexed { k, (f, hue) ->
                val inset = stroke / 2 + k * (stroke + gap)
                val rect = RectF(
                    cx - ringSize / 2 + inset,
                    top + inset,
                    cx + ringSize / 2 - inset,
                    top + ringSize - inset,
                )
                ring(c, rect, stroke, f, hue)
            }
        }
        return b
    }

    /** A round badge in [hue] with a white icon on it. */
    fun chip(context: Context, iconRes: Int, hue: Hue, sizeDp: Float): Bitmap {
        val (b, s) = bitmap(context, sizeDp, sizeDp)
        val c = Canvas(b)
        val size = sizeDp * s
        c.drawCircle(
            size / 2,
            size / 2,
            size / 2,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, size, size, hue.from, hue.to, Shader.TileMode.CLAMP)
            },
        )
        val icon = context.getDrawable(iconRes)?.mutate() ?: return b
        icon.setTint(Color.WHITE)
        val pad = (size * 0.22f).toInt()
        icon.setBounds(pad, pad, size.toInt() - pad, size.toInt() - pad)
        icon.draw(c)
        return b
    }

    /**
     * A glass of water [fraction] full: a tapered glass with a blue,
     * gently waved fill and a few bubbles.
     */
    fun glass(context: Context, wDp: Float, hDp: Float, fraction: Float): Bitmap {
        val (b, s) = bitmap(context, wDp, hDp)
        val c = Canvas(b)
        val w = wDp * s
        val h = hDp * s
        val pad = 3 * s
        val taper = w * 0.12f
        val outline = Path().apply {
            moveTo(pad, pad)
            lineTo(w - pad, pad)
            lineTo(w - pad - taper, h - pad - 6 * s)
            quadTo(w - pad - taper, h - pad, w - pad - taper - 6 * s, h - pad)
            lineTo(pad + taper + 6 * s, h - pad)
            quadTo(pad + taper, h - pad, pad + taper, h - pad - 6 * s)
            close()
        }
        val glassFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (dark(context)) 0x22FFFFFF else 0x142F7BFF
        }
        c.drawPath(outline, glassFill)
        c.save()
        c.clipPath(outline)
        val f = fraction.coerceIn(0f, 1f)
        if (f > 0f) {
            val level = h - pad - (h - 2 * pad) * f
            val wave = Path().apply {
                moveTo(0f, level)
                var x = 0f
                while (x <= w) {
                    lineTo(x, level + sin(x / w * 2 * PI).toFloat() * 3 * s)
                    x += 2 * s
                }
                lineTo(w, h)
                lineTo(0f, h)
                close()
            }
            c.drawPath(
                wave,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(0f, level, 0f, h, WATER.from, WATER.to, Shader.TileMode.CLAMP)
                },
            )
            val bubble = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x66FFFFFF }
            for ((bx, by, r) in listOf(Triple(0.35f, 0.82f, 2.2f), Triple(0.6f, 0.7f, 1.6f), Triple(0.48f, 0.9f, 1.3f))) {
                val y = h * by
                if (y > level + 6 * s) c.drawCircle(w * bx, y, r * s, bubble)
            }
        }
        c.restore()
        // The glass's rim and a highlight down one side.
        c.drawPath(
            outline,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1.6f * s
                color = if (dark(context)) 0x88FFFFFF.toInt() else 0x552F7BFF
            },
        )
        c.drawLine(
            pad + 5 * s,
            pad + 6 * s,
            pad + taper * 0.7f + 5 * s,
            h - pad - 12 * s,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                strokeWidth = 2 * s
                strokeCap = Paint.Cap.ROUND
                color = 0x55FFFFFF
            },
        )
        return b
    }

    /**
     * A card's background with topographic contour lines across it, as on
     * an athletic training card: a soft gradient, rounded corners, and
     * flowing lines heavier toward one corner.
     */
    fun contours(context: Context, wDp: Float, hDp: Float, radiusDp: Float): Bitmap {
        // 1×: it's texture, and the biggest bitmap here.
        val d = min(context.resources.displayMetrics.density, 1.25f)
        val w = wDp * d
        val h = hDp * d
        val b = Bitmap.createBitmap(max(1, w.toInt()), max(1, h.toInt()), Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val dark = dark(context)
        val shape = Path().apply {
            addRoundRect(RectF(0f, 0f, w, h), radiusDp * d, radiusDp * d, Path.Direction.CW)
        }
        c.clipPath(shape)
        c.drawRect(
            0f,
            0f,
            w,
            h,
            Paint().apply {
                shader = LinearGradient(
                    0f,
                    0f,
                    w,
                    h,
                    if (dark) 0xFF26262B.toInt() else 0xFFEEF1F5.toInt(),
                    if (dark) 0xFF151518.toInt() else 0xFFD9DFE7.toInt(),
                    Shader.TileMode.CLAMP,
                )
            },
        )
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 0.9f * d
            color = if (dark) 0x26FFFFFF else 0x2E3A4A5A
        }
        val count = 26
        for (i in 0 until count) {
            val path = Path()
            val base = h * (i / (count - 1f)) * 1.4f - h * 0.2f
            var x = 0f
            path.moveTo(0f, base)
            while (x <= w) {
                val t = x / w
                val y = base +
                    sin(t * PI * 1.6 + i * 0.22).toFloat() * h * 0.10f +
                    sin(t * PI * 3.4 + i * 0.11).toFloat() * h * 0.035f -
                    t * t * h * 0.35f
                path.lineTo(x, y)
                x += 3 * d
            }
            c.drawPath(path, line)
        }
        return b
    }

    /**
     * This week as dashes, Monday to Sunday — filled for days trained,
     * like a plan's progress bar.
     */
    fun dashes(context: Context, widthDp: Float, trained: List<Boolean>, accent: Int): Bitmap {
        val (b, s) = bitmap(context, widthDp, 6f)
        val c = Canvas(b)
        val n = 7
        val gap = 4 * s
        val w = (widthDp * s - gap * (n - 1)) / n
        val on = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
        val off = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (dark(context)) 0x33FFFFFF else 0x22000000
        }
        for (i in 0 until n) {
            val x = i * (w + gap)
            c.drawRoundRect(RectF(x, 0f, x + w, 6 * s), 3 * s, 3 * s, if (trained.getOrElse(i) { false }) on else off)
        }
        return b
    }
}
