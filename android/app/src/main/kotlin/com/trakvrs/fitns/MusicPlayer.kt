package com.trakvrs.fitns

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodChannel

/**
 * Plays the songs the user imported, one at a time, with Android's own
 * MediaPlayer — no library, no internet. Dart keeps the playlist and says
 * what to play; this tells it back when a song ends, fails, or is paused
 * by something else (a call, another app's sound).
 *
 * Also opens the user's streaming apps: FITNS doesn't play their music, it
 * just gets them there in one tap.
 */
class MusicPlayer(private val context: Context, private val channel: MethodChannel) {
    private var player: MediaPlayer? = null
    private var volume = 1f

    /** Paused by a short interruption, to carry on when it's over. */
    private var resumeAfterLoss = false

    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        val p = player ?: return@OnAudioFocusChangeListener
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                resumeAfterLoss = false
                if (p.isPlaying) p.pause()
                channel.invokeMethod("paused", null)
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                if (p.isPlaying) {
                    p.pause()
                    resumeAfterLoss = true
                    channel.invokeMethod("paused", null)
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> p.setVolume(volume * 0.3f, volume * 0.3f)
            AudioManager.AUDIOFOCUS_GAIN -> {
                p.setVolume(volume, volume)
                if (resumeAfterLoss) {
                    resumeAfterLoss = false
                    p.start()
                    channel.invokeMethod("resumed", null)
                }
            }
        }
    }

    private var focusRequest: AudioFocusRequest? = null

    private fun requestFocus(): Boolean {
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focusRequest = request
            audio.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
        return granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audio.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audio.abandonAudioFocus(focusListener)
        }
    }

    /** Starts [uri] from the beginning. False if it can't be opened. */
    fun play(uri: String): Boolean {
        release(keepFocus = true)
        return try {
            val p = MediaPlayer()
            p.setAudioAttributes(attributes)
            p.setDataSource(context, Uri.parse(uri))
            p.setVolume(volume, volume)
            p.setOnCompletionListener { channel.invokeMethod("completed", null) }
            p.setOnErrorListener { _, _, _ ->
                channel.invokeMethod("failed", null)
                true
            }
            p.setOnPreparedListener {
                if (requestFocus()) it.start()
            }
            p.prepareAsync()
            player = p
            true
        } catch (e: Exception) {
            false
        }
    }

    fun pause() {
        resumeAfterLoss = false
        player?.takeIf { it.isPlaying }?.pause()
    }

    fun resume() {
        val p = player ?: return
        if (requestFocus()) p.start()
    }

    fun setVolume(v: Double) {
        volume = v.toFloat().coerceIn(0f, 1f)
        player?.setVolume(volume, volume)
    }

    fun release(keepFocus: Boolean = false) {
        player?.release()
        player = null
        if (!keepFocus) abandonFocus()
    }

    /** Which of [packages] are installed and can be opened. */
    fun installed(packages: List<String>): List<String> =
        packages.filter { context.packageManager.getLaunchIntentForPackage(it) != null }

    /** Opens [packageName], or the phone's music app when null. */
    fun open(packageName: String?): Boolean {
        val intent = if (packageName == null) {
            Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_MUSIC)
        } else {
            context.packageManager.getLaunchIntentForPackage(packageName)
        } ?: return false
        return try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
    }
}
