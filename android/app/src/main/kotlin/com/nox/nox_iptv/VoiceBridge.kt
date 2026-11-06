package com.nox.nox_iptv

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Vesper AI's voice (lib/services/vesper_ai/voice_input.dart): Android's own
 * speech recognizer (the remote's microphone on Android TV goes through it),
 * text-to-speech for replies, and the "assistant" launch — VesperTV started
 * with ACTION_ASSIST when a user made it the device's assistant with
 * `adb shell settings put secure assistant com.nox.nox_iptv/.MainActivity`.
 *
 * MethodChannel `vespertv/voice`: available, hasPermission, requestPermission,
 * start {lang}, stop, cancel, speak {text, lang}, stopSpeaking, takeAssist.
 * EventChannel `vespertv/voice/events`: {type: ready|partial|final|level|
 * error|end, text?, value?, code?}. Dart gets `assist` calls on the method
 * channel while running.
 */
class VoiceBridge(private val activity: Activity) {
    companion object {
        const val PERMISSION_REQUEST = 4731
        private const val TAG = "VesperVoice"
    }

    private var channel: MethodChannel? = null
    private var events: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeech: Pair<String, String>? = null
    private var assistPending = false

    fun connect(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "vespertv/voice").also {
            it.setMethodCallHandler(::handle)
        }
        EventChannel(messenger, "vespertv/voice/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            })
    }

    /** The activity was (re)started for the assistant. */
    fun onIntent(intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_ASSIST && action != Intent.ACTION_VOICE_COMMAND &&
            action != "android.intent.action.VOICE_ASSIST") return
        // Consumed: a later recreation must not open the panel again.
        intent.action = Intent.ACTION_MAIN
        // Dart takes it with takeAssist (at start-up, and on this call when
        // it is already running), so it can't be lost or opened twice.
        assistPending = true
        channel?.invokeMethod("assist", null)
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        pendingPermission?.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
        return true
    }

    fun dispose() {
        recognizer?.destroy()
        recognizer = null
        tts?.shutdown()
        tts = null
    }

    private fun hasPermission() = ContextCompat.checkSelfPermission(
        activity, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(
                try {
                    SpeechRecognizer.isRecognitionAvailable(activity)
                } catch (e: Exception) {
                    false
                })
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> {
                if (hasPermission()) {
                    result.success(true)
                } else {
                    pendingPermission?.success(false)
                    pendingPermission = result
                    ActivityCompat.requestPermissions(
                        activity, arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST)
                }
            }
            "start" -> {
                start(call.argument<String>("lang"))
                result.success(null)
            }
            "stop" -> {
                recognizer?.stopListening()
                result.success(null)
            }
            "cancel" -> {
                recognizer?.cancel()
                result.success(null)
            }
            "speak" -> {
                speak(call.argument<String>("text") ?: "", call.argument<String>("lang") ?: "en")
                result.success(null)
            }
            "stopSpeaking" -> {
                tts?.stop()
                result.success(null)
            }
            "takeAssist" -> {
                val pending = assistPending
                assistPending = false
                result.success(pending)
            }
            else -> result.notImplemented()
        }
    }

    private fun send(type: String, extra: Map<String, Any?> = emptyMap()) {
        events?.success(mapOf("type" to type) + extra)
    }

    private fun start(lang: String?) {
        if (!hasPermission()) {
            send("error", mapOf("code" to "permission"))
            send("end")
            return
        }
        val r = recognizer ?: try {
            SpeechRecognizer.createSpeechRecognizer(activity).also { recognizer = it }
        } catch (e: Exception) {
            Log.w(TAG, "No speech recognizer: ${e.javaClass.simpleName}")
            send("error", mapOf("code" to "unavailable"))
            send("end")
            return
        }
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = send("ready")
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) = send("level", mapOf("value" to rmsdB.toDouble()))
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                val code = when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "nomatch"
                    SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "network"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission"
                    SpeechRecognizer.ERROR_AUDIO -> "audio"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "busy"
                    else -> "error$error"
                }
                Log.i(TAG, "recognizer error $code")
                send("error", mapOf("code" to code))
                send("end")
            }

            override fun onResults(results: Bundle?) {
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                send("final", mapOf("text" to text))
                send("end")
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: return
                if (text.isNotBlank()) send("partial", mapOf("text" to text))
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
            if (!lang.isNullOrBlank()) {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            }
        }
        try {
            r.cancel()
            r.startListening(intent)
        } catch (e: Exception) {
            Log.w(TAG, "startListening failed: ${e.javaClass.simpleName}")
            send("error", mapOf("code" to "unavailable"))
            send("end")
        }
    }

    private fun speak(text: String, lang: String) {
        if (text.isBlank()) return
        val engine = tts
        if (engine == null) {
            pendingSpeech = text to lang
            tts = TextToSpeech(activity.applicationContext) { status ->
                ttsReady = status == TextToSpeech.SUCCESS
                val p = pendingSpeech
                pendingSpeech = null
                if (ttsReady && p != null) speak(p.first, p.second)
            }
            return
        }
        if (!ttsReady) {
            pendingSpeech = text to lang
            return
        }
        try {
            engine.language = Locale.forLanguageTag(lang)
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "vesper")
        } catch (e: Exception) {
            Log.w(TAG, "speak failed: ${e.javaClass.simpleName}")
        }
    }
}
