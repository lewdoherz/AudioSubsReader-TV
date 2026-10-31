package com.audiosubs.audiosubs_reader.tv

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel

/** One API-23 focus owner; gaining focus never starts or resumes playback. */
class TvAudioFocus(private val activity: Activity, private val channel: MethodChannel) {
    private val manager = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var resumed = false
    private var focused = false
    private var ownsFocus = false
    private val listener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) {
            interrupt("audio_focus_loss")
        }
    }
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) interrupt("audio_becoming_noisy")
        }
    }

    init {
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) activity.registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
        else activity.registerReceiver(noisy, filter)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestFocus" -> {
                    if (!resumed || !focused) result.success(false)
                    else {
                        ownsFocus = manager.requestAudioFocus(listener, AudioManager.STREAM_MUSIC,
                            AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
                        result.success(ownsFocus)
                    }
                }
                "abandonFocus" -> { abandon(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    fun onResume() { resumed = true }
    fun onPause() { resumed = false; interrupt("activity_pause") }
    fun onWindowFocusChanged(value: Boolean) {
        focused = value
        if (!value) interrupt("window_focus_loss")
    }
    private fun abandon() {
        if (ownsFocus) manager.abandonAudioFocus(listener)
        ownsFocus = false
    }
    private fun interrupt(reason: String) {
        abandon()
        activity.runOnUiThread { channel.invokeMethod("interruption", reason) }
    }
    fun detach() {
        abandon()
        activity.unregisterReceiver(noisy)
        channel.setMethodCallHandler(null)
    }
}
