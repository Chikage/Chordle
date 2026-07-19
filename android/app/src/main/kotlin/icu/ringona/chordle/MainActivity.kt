package icu.ringona.chordle

import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log
import icu.ringona.chordle.audio.NativeAudioEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val platformExecutor = ScheduledThreadPoolExecutor(1) { runnable ->
        Thread(runnable, "chordle-platform").apply { isDaemon = true }
    }.apply {
        removeOnCancelPolicy = true
        executeExistingDelayedTasksAfterShutdownPolicy = false
        continueExistingPeriodicTasksAfterShutdownPolicy = false
    }

    private lateinit var platformChannel: MethodChannel
    private var audioPrepared = false
    private var playbackGeneration = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        platformChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        platformChannel.setMethodCallHandler(::handlePlatformCall)
    }

    override fun onPause() {
        stopAudioFromLifecycle()
        super.onPause()
    }

    override fun onDestroy() {
        if (::platformChannel.isInitialized) {
            platformChannel.setMethodCallHandler(null)
        }
        try {
            platformExecutor.execute {
                playbackGeneration += 1
                runCatching { NativeAudioEngine.allSoundOff() }
                runCatching { NativeAudioEngine.teardown() }
                audioPrepared = false
            }
            platformExecutor.shutdown()
        } catch (_: RejectedExecutionException) {
            runCatching { NativeAudioEngine.allSoundOff() }
            runCatching { NativeAudioEngine.teardown() }
        }
        super.onDestroy()
    }

    private fun handlePlatformCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareAudio" -> runPlatformTask(result, "audio_prepare_failed") {
                if (!prepareAudioInternal()) {
                    error("音频引擎或内置 SoundFont 初始化失败")
                }
                true
            }

            "playTones" -> {
                val request = runCatching { parsePlayRequest(call.arguments) }
                    .getOrElse { throwable ->
                        result.error("invalid_audio_arguments", throwable.message, null)
                        return
                    }
                runPlatformTask(result, "audio_playback_failed") {
                    playTonesInternal(request)
                    null
                }
            }

            "allSoundOff" -> runPlatformTask(result, "audio_stop_failed") {
                playbackGeneration += 1
                if (audioPrepared) {
                    NativeAudioEngine.allSoundOff()
                }
                null
            }

            "loadSettings" -> runPlatformTask(result, "settings_load_failed") {
                loadSettingsInternal()
            }

            "saveSettings" -> {
                val settings = settingsMapFromArguments(call.arguments)
                if (settings == null) {
                    result.error("invalid_settings", "saveSettings expects a settings map", null)
                    return
                }
                runPlatformTask(result, "settings_save_failed") {
                    if (!saveSettingsInternal(settings)) {
                        error("设置写入失败")
                    }
                    null
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun prepareAudioInternal(): Boolean {
        if (!NativeAudioEngine.setup()) {
            return false
        }

        val loaded = if (NativeAudioEngine.hasSoundFont()) {
            true
        } else {
            DefaultSoundFontLoader(cacheDir, assets).load().getOrElse { throwable ->
                Log.e(TAG, "Unable to load the packaged SoundFont", throwable)
                false
            }
        }
        if (!loaded) {
            return false
        }

        NativeAudioEngine.setGain(DEFAULT_GAIN)
        NativeAudioEngine.setReverb(DEFAULT_REVERB)
        val started = NativeAudioEngine.isStarted() ||
            NativeAudioEngine.start() ||
            NativeAudioEngine.restart()
        audioPrepared = started
        return started
    }

    private fun playTonesInternal(request: PlayRequest) {
        if (!prepareAudioInternal()) {
            error("音频引擎尚未准备好")
        }

        playbackGeneration += 1
        val generation = playbackGeneration
        NativeAudioEngine.allSoundOff()
        if (request.tones.isEmpty()) {
            return
        }

        val noteIds = request.tones.mapNotNull { tone ->
            NativeAudioEngine.noteOn(
                key = tone.key,
                velocity = tone.velocity,
                cents = tone.cents,
                channel = tone.channel,
                program = tone.program,
                bankMsb = tone.bankMsb,
                bankLsb = tone.bankLsb,
                delaySeconds = tone.delaySeconds,
            )
        }
        if (noteIds.size != request.tones.size) {
            NativeAudioEngine.allSoundOff()
            error("一个或多个音符无法启动")
        }

        platformExecutor.schedule(
            {
                if (generation == playbackGeneration) {
                    noteIds.forEach(NativeAudioEngine::noteOff)
                }
            },
            request.durationMillis,
            TimeUnit.MILLISECONDS,
        )
    }

    private fun stopAudioFromLifecycle() {
        try {
            platformExecutor.execute {
                playbackGeneration += 1
                if (audioPrepared) {
                    runCatching { NativeAudioEngine.allSoundOff() }
                }
            }
        } catch (_: RejectedExecutionException) {
            // The Activity is already being destroyed.
        }
    }

    private fun parsePlayRequest(arguments: Any?): PlayRequest {
        val argumentMap = arguments as? Map<*, *>
        val rawTones = when (arguments) {
            is List<*> -> arguments
            is Map<*, *> -> firstValue(arguments, "tones", "notes", "values") as? List<*>
            else -> null
        } ?: error("playTones expects a tones list")

        val defaultVelocity = numberValue(argumentMap, "velocity")?.toInt()?.coerceIn(1, 127)
            ?: DEFAULT_VELOCITY
        val defaultProgram = numberValue(argumentMap, "program", "instrumentProgram")
            ?.toInt()?.coerceIn(0, 127) ?: DEFAULT_PROGRAM
        val defaultChannel = numberValue(argumentMap, "channel")?.toInt()?.coerceIn(0, 15) ?: 0
        val defaultBankMsb = numberValue(argumentMap, "bankMsb")?.toInt()?.coerceIn(0, 127) ?: 0
        val defaultBankLsb = numberValue(argumentMap, "bankLsb")?.toInt()?.coerceIn(0, 127) ?: 0
        val defaultDelaySeconds = numberValue(argumentMap, "delaySeconds")?.toDouble()?.coerceAtLeast(0.0)
            ?: 0.0

        val tones = rawTones.mapIndexed { index, value ->
            when (value) {
                is Number -> PlatformTone(
                    key = value.toInt().coerceIn(0, 127),
                    velocity = defaultVelocity,
                    program = defaultProgram,
                    channel = defaultChannel,
                    bankMsb = defaultBankMsb,
                    bankLsb = defaultBankLsb,
                    delaySeconds = defaultDelaySeconds,
                )

                is Map<*, *> -> {
                    val key = numberValue(value, "key", "note", "midiNote")?.toInt()
                        ?: error("tones[$index] is missing key")
                    PlatformTone(
                        key = key.coerceIn(0, 127),
                        cents = numberValue(value, "cents", "detuneCents")?.toFloat() ?: 0f,
                        velocity = numberValue(value, "velocity")?.toInt()?.coerceIn(1, 127)
                            ?: defaultVelocity,
                        program = numberValue(value, "program", "instrumentProgram")
                            ?.toInt()?.coerceIn(0, 127) ?: defaultProgram,
                        channel = numberValue(value, "channel")?.toInt()?.coerceIn(0, 15)
                            ?: defaultChannel,
                        bankMsb = numberValue(value, "bankMsb")?.toInt()?.coerceIn(0, 127)
                            ?: defaultBankMsb,
                        bankLsb = numberValue(value, "bankLsb")?.toInt()?.coerceIn(0, 127)
                            ?: defaultBankLsb,
                        delaySeconds = numberValue(value, "delaySeconds")?.toDouble()?.coerceAtLeast(0.0)
                            ?: defaultDelaySeconds,
                    )
                }

                else -> error("tones[$index] must be a number or map")
            }
        }

        val durationMillis = numberValue(argumentMap, "durationMillis", "durationMs")?.toLong()
            ?: numberValue(argumentMap, "durationSeconds")?.toDouble()?.times(1000.0)?.toLong()
            ?: numberValue(argumentMap, "duration")?.toDouble()?.let { duration ->
                if (duration <= 30.0) (duration * 1000.0).toLong() else duration.toLong()
            }
            ?: DEFAULT_DURATION_MILLIS

        return PlayRequest(
            tones = tones,
            durationMillis = durationMillis.coerceIn(MIN_DURATION_MILLIS, MAX_DURATION_MILLIS),
        )
    }

    private fun loadSettingsInternal(): Map<String, Any?> {
        val preferences = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
        val result = linkedMapOf<String, Any?>()
        preferences.all.forEach { (key, value) -> result[key] = channelValue(value) }

        SETTING_SPECS.forEach { spec ->
            val storedValue = sequenceOf(spec.canonicalKey)
                .plus(spec.readAliases.asSequence())
                .firstOrNull(preferences::contains)
                ?.let { key -> channelValue(preferences.all[key]) }
                ?: spec.defaultValue
            result[spec.canonicalKey] = storedValue
            spec.readAliases.forEach { alias -> result[alias] = storedValue }
        }
        return result
    }

    private fun saveSettingsInternal(settings: Map<*, *>): Boolean {
        val preferences = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
        val editor = preferences.edit()
        settings.forEach { (rawKey, value) ->
            val key = rawKey as? String ?: return@forEach
            val spec = SETTING_SPECS.firstOrNull { candidate ->
                key == candidate.canonicalKey || key in candidate.readAliases
            }
            if (spec == null) {
                putPreferenceValue(editor, key, value)
            } else {
                putPreferenceValue(editor, spec.canonicalKey, value)
                spec.writeAliases.forEach { alias -> putPreferenceValue(editor, alias, value) }
            }
        }
        return editor.commit()
    }

    private fun settingsMapFromArguments(arguments: Any?): Map<*, *>? {
        val argumentsMap = arguments as? Map<*, *> ?: return null
        return argumentsMap["settings"] as? Map<*, *> ?: argumentsMap
    }

    private fun putPreferenceValue(editor: SharedPreferences.Editor, key: String, value: Any?) {
        if (key in STABLE_LIST_SETTING_KEYS) {
            when (value) {
                null -> editor.remove(key)
                else -> editor.putString(key, stableListPreferenceValue(value))
            }
            return
        }
        when (value) {
            null -> editor.remove(key)
            is Boolean -> editor.putBoolean(key, value)
            is Byte -> editor.putInt(key, value.toInt())
            is Short -> editor.putInt(key, value.toInt())
            is Int -> editor.putInt(key, value)
            is Long -> editor.putLong(key, value)
            is Float -> editor.putFloat(key, value)
            is Double -> editor.putFloat(key, value.toFloat())
            is String -> editor.putString(key, value)
            is List<*> -> editor.putStringSet(key, value.mapNotNull(Any?::toString).toSet())
            is Set<*> -> editor.putStringSet(key, value.mapNotNull(Any?::toString).toSet())
            else -> editor.putString(key, value.toString())
        }
    }

    private fun stableListPreferenceValue(value: Any): String = when (value) {
        is String -> value
        is Iterable<*> -> JSONArray(value.toList()).toString()
        is Array<*> -> JSONArray(value.toList()).toString()
        else -> JSONArray(listOf(value)).toString()
    }

    private fun channelValue(value: Any?): Any? = when (value) {
        is Float -> value.toDouble()
        is Set<*> -> value.mapNotNull { it?.toString() }
        else -> value
    }

    private fun firstValue(map: Map<*, *>?, vararg keys: String): Any? {
        if (map == null) {
            return null
        }
        keys.forEach { key ->
            if (map.containsKey(key)) {
                return map[key]
            }
        }
        return null
    }

    private fun numberValue(map: Map<*, *>?, vararg keys: String): Number? =
        firstValue(map, *keys) as? Number

    private fun <T> runPlatformTask(
        result: MethodChannel.Result,
        errorCode: String,
        block: () -> T,
    ) {
        try {
            platformExecutor.execute {
                try {
                    val value = block()
                    mainHandler.post { result.success(value) }
                } catch (throwable: Throwable) {
                    Log.e(TAG, errorCode, throwable)
                    mainHandler.post {
                        result.error(errorCode, throwable.localizedMessage ?: errorCode, null)
                    }
                }
            }
        } catch (throwable: RejectedExecutionException) {
            result.error("activity_destroyed", "Android Activity is shutting down", null)
        }
    }

    private data class PlatformTone(
        val key: Int,
        val cents: Float = 0f,
        val velocity: Int,
        val program: Int,
        val channel: Int,
        val bankMsb: Int,
        val bankLsb: Int,
        val delaySeconds: Double,
    )

    private data class PlayRequest(
        val tones: List<PlatformTone>,
        val durationMillis: Long,
    )

    private data class SettingSpec(
        val canonicalKey: String,
        val readAliases: List<String>,
        val writeAliases: List<String> = readAliases,
        val defaultValue: Any,
    )

    private companion object {
        const val TAG = "ChordlePlatform"
        const val CHANNEL_NAME = "icu.ringona.chordle/platform"
        const val PREFERENCES_NAME = "chordle_settings"
        const val DEFAULT_VELOCITY = 104
        const val DEFAULT_PROGRAM = 0
        const val DEFAULT_DURATION_MILLIS = 1200L
        const val MIN_DURATION_MILLIS = 50L
        const val MAX_DURATION_MILLIS = 60_000L
        const val DEFAULT_GAIN = 2.25f
        const val DEFAULT_REVERB = 54

        val STABLE_LIST_SETTING_KEYS = setOf("ratioMcqEdos", "ratioMcqRatios")

        val SETTING_SPECS = listOf(
            SettingSpec(
                "normalLow",
                listOf("playableRangeLow", "normalPlayableRangeLow", "normalRangeLow", "playable_range_low"),
                defaultValue = 48,
            ),
            SettingSpec(
                "normalHigh",
                listOf("playableRangeHigh", "normalPlayableRangeHigh", "normalRangeHigh", "playable_range_high"),
                defaultValue = 72,
            ),
            SettingSpec(
                "normalToneCount",
                listOf("chordToneCount", "normalChordToneCount", "chord_tone_count"),
                defaultValue = 3,
            ),
            SettingSpec(
                "extraLow",
                listOf("extraPlayableRangeLow", "extraRangeLow", "extra_playable_range_low"),
                defaultValue = 48,
            ),
            SettingSpec(
                "extraHigh",
                listOf("extraPlayableRangeHigh", "extraRangeHigh", "extra_playable_range_high"),
                defaultValue = 72,
            ),
            SettingSpec(
                "extraToneCount",
                listOf("extraChordToneCount", "extra_chord_tone_count", "chord_tone_count"),
                defaultValue = 3,
            ),
            SettingSpec("extraEdo", listOf("extra_edo"), defaultValue = 24),
            SettingSpec(
                "freeJiEnabled",
                listOf("free_ji_enabled"),
                defaultValue = false,
            ),
            SettingSpec("ratioMcqEdos", emptyList(), defaultValue = "[12]"),
            SettingSpec("ratioMcqJiEnabled", emptyList(), defaultValue = false),
            SettingSpec(
                "ratioMcqRatios",
                emptyList(),
                defaultValue = "[\"3/2\",\"4/3\"]",
            ),
            SettingSpec("ratioMcqOptionCount", emptyList(), defaultValue = 2),
            SettingSpec("ratioMcqConfigured", emptyList(), defaultValue = false),
            SettingSpec(
                "overtoneLow",
                listOf("overtoneRangeLow", "overtone_range_low"),
                defaultValue = 8,
            ),
            SettingSpec(
                "overtoneHigh",
                listOf("overtoneRangeHigh", "overtone_range_high"),
                defaultValue = 16,
            ),
            SettingSpec(
                "overtoneToneCount",
                listOf("overtone_tone_count"),
                defaultValue = 4,
            ),
            SettingSpec(
                "instrumentProgram",
                listOf("instrument_program"),
                defaultValue = 0,
            ),
            SettingSpec(
                "keyPitchPreviewEnabled",
                listOf("key_pitch_preview_enabled"),
                defaultValue = false,
            ),
        )
    }
}
