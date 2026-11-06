package com.trakvrs.fitns

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import java.io.File

/**
 * Progress photos, kept in FITNS's private storage: only this app can see
 * them, and they go when the app is uninstalled. Each picked or taken image
 * is shrunk to at most [MAX_SIDE] px on its long side (a phone photo can be
 * 12 MP; a year of weekly ones would fill a phone) and turned upright from
 * its EXIF orientation, which decoding would otherwise lose.
 */
object PhotoFiles {
    private const val DIR = "progress_photos"
    private const val MAX_SIDE = 2048

    /** Copies [uri] into private storage as a JPEG; returns its path. */
    fun save(context: Context, uri: Uri): String {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)!!.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_SIDE) sample *= 2
        val decoded = resolver.openInputStream(uri)!!.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: throw IllegalStateException("Not an image")

        val rotation = try {
            resolver.openInputStream(uri)!!.use {
                when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
            }
        } catch (e: Exception) {
            0f
        }
        val scale = minOf(1f, MAX_SIDE.toFloat() / maxOf(decoded.width, decoded.height))
        val matrix = Matrix().apply {
            postScale(scale, scale)
            postRotate(rotation)
        }
        val upright = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)

        val dir = File(context.filesDir, DIR).apply { mkdirs() }
        val file = File(dir, "${System.currentTimeMillis()}.jpg")
        file.outputStream().use { upright.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        if (upright !== decoded) upright.recycle()
        decoded.recycle()
        return file.absolutePath
    }
}
