package icu.ringona.chordle

import android.graphics.Paint as AndroidPaint
import android.graphics.Typeface
import android.os.Bundle
import androidx.activity.compose.BackHandler
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RangeSlider
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import icu.ringona.chordle.audio.NativeAudioEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.round
import kotlin.math.roundToInt

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = android.graphics.Color.rgb(18, 18, 19)
        window.navigationBarColor = android.graphics.Color.rgb(18, 18, 19)
        setContent {
            ChordleTheme {
                ChordleApp()
            }
        }
    }

    override fun onDestroy() {
        runCatching {
            NativeAudioEngine.allSoundOff()
            NativeAudioEngine.teardown()
        }
        super.onDestroy()
    }
}

private sealed interface AudioStatus {
    data object Loading : AudioStatus
    data object Ready : AudioStatus
    data class Error(val message: String) : AudioStatus
}

private enum class ChordleMode {
    Normal,
    Extra,
    Overtones
}

private data class BoardCellKey(
    val row: Int,
    val column: Int
)

private data class DraggedPreviousTile(
    val sourceColumn: Int,
    val note: Int,
    val state: TileState,
    val touchPosition: Offset,
    val dragOffset: Offset = Offset.Zero
)

@Composable
private fun ChordleTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            background = ChordleBackground,
            surface = ChordleSurface,
            primary = ChordleGreen,
            secondary = ChordleYellow,
            onPrimary = Color.White,
            onSurface = ChordleText,
            onBackground = ChordleText
        ),
        content = content
    )
}

@Composable
private fun ChordleApp() {
    var selectedMode by remember { mutableStateOf<ChordleMode?>(null) }

    when (selectedMode) {
        null -> ModeSelectionScreen(onModeSelected = { selectedMode = it })
        ChordleMode.Normal,
        ChordleMode.Extra,
        ChordleMode.Overtones -> ChordleGameScreen(
            mode = selectedMode!!,
            onBackToModeSelection = {
                selectedMode = null
            }
        )
    }
}

@Composable
private fun ModeSelectionScreen(
    onModeSelected: (ChordleMode) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ChordleBackground)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 28.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Text(
                text = "Chordle",
                color = ChordleText,
                fontSize = 42.sp,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.Serif,
                maxLines = 1,
                overflow = TextOverflow.Clip
            )
            Text(
                text = "选择模式",
                color = ChordleMuted,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
            Spacer(Modifier.height(10.dp))
            Button(
                onClick = { onModeSelected(ChordleMode.Normal) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = ChordleGreen)
            ) {
                Text("Normal", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
            OutlinedButton(
                onClick = { onModeSelected(ChordleMode.Extra) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
            ) {
                Text("Extra", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
            OutlinedButton(
                onClick = { onModeSelected(ChordleMode.Overtones) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
            ) {
                Text("Overtones", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun ChordleGameScreen(
    mode: ChordleMode,
    onBackToModeSelection: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val settings = remember { ChordleSettings(context) }
    var playableRange by remember { mutableStateOf(settings.loadPlayableRange()) }
    var chordToneCount by remember { mutableStateOf(settings.loadChordToneCount()) }
    var extraEdo by remember { mutableStateOf(settings.loadExtraEdo()) }
    var overtoneRange by remember { mutableStateOf(settings.loadOvertoneRange()) }
    var overtoneToneCount by remember { mutableStateOf(settings.loadOvertoneToneCount()) }
    var instrumentProgram by remember { mutableStateOf(settings.loadInstrumentProgram()) }
    var keyPitchPreviewEnabled by remember { mutableStateOf(settings.loadKeyPitchPreviewEnabled()) }
    val game = remember(mode) {
        ChordleGame(
            when (mode) {
                ChordleMode.Overtones -> ChordPuzzle.randomOvertones(overtoneToneCount, overtoneRange)
                ChordleMode.Extra -> ChordPuzzle.randomExtra(chordToneCount, playableRange, extraEdo)
                ChordleMode.Normal -> ChordPuzzle.random(chordToneCount, playableRange)
            }
        )
    }
    var showHelp by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var audioStatus by remember { mutableStateOf<AudioStatus>(AudioStatus.Loading) }
    val statusDetail = when (mode) {
        ChordleMode.Overtones -> "${game.columns} 音 · ${overtoneRangeLabel(overtoneRange)}"
        ChordleMode.Extra -> "${game.columns} 音 · ${extraEdo}EDO · ${extraRangeLabel(extraEdo, playableRange)}"
        ChordleMode.Normal -> "${game.columns} 音 · ${rangeLabel(playableRange)}"
    }
    val valueStates = game.guessedValueStates()

    BackHandler(enabled = !showHelp && !showSettings) {
        NativeAudioEngine.allSoundOff()
        onBackToModeSelection()
    }

    LaunchedEffect(Unit) {
        audioStatus = withContext(Dispatchers.IO) {
            runCatching {
                NativeAudioEngine.setup()
                NativeAudioEngine.start()
                NativeAudioEngine.setGain(2.25f)
                NativeAudioEngine.setReverb(54)
                val loaded = if (NativeAudioEngine.hasSoundFont()) {
                    true
                } else {
                    DefaultSoundFontLoader(context.cacheDir, context.assets).load().getOrDefault(false)
                }
                if (loaded) {
                    AudioStatus.Ready
                } else {
                    AudioStatus.Error("音色加载失败")
                }
            }.getOrElse {
                AudioStatus.Error(it.localizedMessage ?: "音频引擎启动失败")
            }
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            runCatching { NativeAudioEngine.allSoundOff() }
        }
    }

    LaunchedEffect(game.message) {
        if (game.message != null) {
            delay(1800)
            game.clearMessage()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ChordleBackground)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            ChordleHeader(
                onHelp = { showHelp = true },
                onSettings = { showSettings = true }
            )

            GameStatusLine(
                audioStatus = audioStatus,
                detailText = statusDetail,
                attempt = game.currentRow + 1,
                maxAttempts = game.maxAttempts,
                onNewPuzzle = {
                    NativeAudioEngine.allSoundOff()
                    when (mode) {
                        ChordleMode.Overtones -> {
                            game.newPuzzle(ChordPuzzle.randomOvertones(overtoneToneCount, overtoneRange))
                        }
                        ChordleMode.Extra -> {
                            game.newPuzzle(ChordPuzzle.randomExtra(chordToneCount, playableRange, extraEdo))
                        }
                        ChordleMode.Normal -> {
                            game.newPuzzle(chordToneCount, playableRange)
                        }
                    }
                    if (audioStatus == AudioStatus.Ready) {
                        scope.launch {
                            playTones(
                                playbackTonesForMode(mode, game.puzzle, game.puzzle.notes, extraEdo),
                                program = instrumentProgram,
                                durationMillis = 1400
                            )
                        }
                    }
                }
            )

            BoardArea(
                game = game,
                audioReady = audioStatus == AudioStatus.Ready,
                requireJudgedPlayback = !keyPitchPreviewEnabled,
                onSortRow = { row -> game.sortRowBy(row) },
                onPlayRow = { row ->
                    scope.launch {
                        playTones(
                            playbackTonesForMode(mode, game.puzzle, game.rowNotes(row), extraEdo),
                            program = instrumentProgram,
                            durationMillis = 1200
                        )
                    }
                },
                onPlayValue = { value ->
                    scope.launch {
                        playTones(
                            playbackTonesForMode(mode, game.puzzle, listOf(value), extraEdo),
                            velocity = 92,
                            program = instrumentProgram,
                            durationMillis = 520
                        )
                    }
                },
                valueLabel = valueLabelForMode(mode, extraEdo),
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            )

            if (mode == ChordleMode.Overtones) {
                OvertoneInputPanel(
                    game = game,
                    overtoneRange = overtoneRange,
                    valueStates = valueStates,
                    audioReady = audioStatus == AudioStatus.Ready,
                    onPlayChord = {
                        if (audioStatus == AudioStatus.Ready) {
                            scope.launch {
                                playTones(
                                    playbackTonesForMode(mode, game.puzzle, game.puzzle.notes, extraEdo),
                                    program = instrumentProgram,
                                    durationMillis = 1600
                                )
                            }
                        } else {
                            game.clearMessage()
                        }
                    },
                    onPreviewMultiplier = { multiplier ->
                        game.selectNote(multiplier)
                        if (keyPitchPreviewEnabled && audioStatus == AudioStatus.Ready) {
                            scope.launch {
                                playTones(
                                    playbackTonesForMode(mode, game.puzzle, listOf(multiplier)),
                                    velocity = 92,
                                    program = instrumentProgram,
                                    durationMillis = 520
                                )
                            }
                        }
                    }
                )
            } else {
                val isExtraMode = mode == ChordleMode.Extra
                InputPanel(
                    game = game,
                    audioReady = audioStatus == AudioStatus.Ready,
                    onPlayChord = {
                        if (audioStatus == AudioStatus.Ready) {
                            scope.launch {
                                playTones(
                                    playbackTonesForMode(mode, game.puzzle, game.puzzle.notes, extraEdo),
                                    program = instrumentProgram,
                                    durationMillis = 1600
                                )
                            }
                        } else {
                            game.clearMessage()
                        }
                    },
                    onPreviewValue = { value ->
                        game.selectNote(value)
                        if (keyPitchPreviewEnabled && audioStatus == AudioStatus.Ready) {
                            scope.launch {
                                playTones(
                                    playbackTonesForMode(mode, game.puzzle, listOf(value), extraEdo),
                                    velocity = 92,
                                    program = instrumentProgram,
                                    durationMillis = 520
                                )
                            }
                        }
                    },
                    selectionLabel = if (isExtraMode) {
                        { value -> extraStepLabel(value, extraEdo) }
                    } else {
                        ::noteLabel
                    },
                    emptySelectionText = if (isExtraMode) "未选 EDO 音" else "未选音",
                    missingSelectionMessage = if (isExtraMode) "先在 EDO 标尺上选择一个音" else "先在钢琴上选择一个音",
                    onSubmit = {
                        if (isExtraMode) {
                            game.submitExtraGuess(extraEdo)
                        } else {
                            game.submitGuess()
                        }
                    },
                    keyboardContent = { selectedValue, onValuePressed ->
                        if (isExtraMode) {
                            MicrotonalKeyboard(
                                edo = extraEdo,
                                noteRange = playableRange,
                                selectedStep = selectedValue,
                                valueStates = valueStates,
                                onStepPressed = onValuePressed,
                                modifier = Modifier.fillMaxWidth()
                            )
                        } else {
                            PianoKeyboard(
                                noteRange = playableRange,
                                selectedNote = selectedValue,
                                valueStates = valueStates,
                                onNotePressed = onValuePressed,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                )
            }
        }

        val message = game.message
        if (message != null) {
            Surface(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 68.dp),
                color = Color(0xFF2E2E31),
                shape = RoundedCornerShape(8.dp),
                tonalElevation = 8.dp
            ) {
                Text(
                    text = message,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }

    if (showHelp) {
        HelpDialog(mode = mode, onDismiss = { showHelp = false })
    }
    if (showSettings) {
        if (mode == ChordleMode.Overtones) {
            OvertoneSettingsDialog(
                multiplierRange = overtoneRange,
                toneCount = overtoneToneCount,
                instrumentProgram = instrumentProgram,
                keyPitchPreviewEnabled = keyPitchPreviewEnabled,
                onDismiss = { showSettings = false },
                onSave = { range, toneCount, program, previewEnabled ->
                    val nextRange = sanitizeOvertoneRange(range)
                    val nextToneCount = sanitizeOvertoneToneCount(toneCount, nextRange)
                    val nextProgram = sanitizeMidiProgramNumber(program)
                    val shouldCreateNewPuzzle = nextRange != overtoneRange || nextToneCount != overtoneToneCount
                    overtoneRange = nextRange
                    overtoneToneCount = nextToneCount
                    instrumentProgram = nextProgram
                    keyPitchPreviewEnabled = previewEnabled
                    settings.saveOvertoneRange(overtoneRange)
                    settings.saveOvertoneToneCount(overtoneToneCount, overtoneRange)
                    settings.saveInstrumentProgram(instrumentProgram)
                    settings.saveKeyPitchPreviewEnabled(keyPitchPreviewEnabled)
                    if (shouldCreateNewPuzzle) {
                        game.newPuzzle(ChordPuzzle.randomOvertones(overtoneToneCount, overtoneRange))
                    }
                    showSettings = false
                    if (audioStatus == AudioStatus.Ready) {
                        scope.launch {
                            playTones(
                                playbackTonesForMode(mode, game.puzzle, game.puzzle.notes),
                                program = instrumentProgram,
                                durationMillis = 1400
                            )
                        }
                    }
                }
            )
        } else if (mode == ChordleMode.Extra) {
            ExtraSettingsDialog(
                range = playableRange,
                chordToneCount = chordToneCount,
                extraEdo = extraEdo,
                instrumentProgram = instrumentProgram,
                keyPitchPreviewEnabled = keyPitchPreviewEnabled,
                onDismiss = { showSettings = false },
                onSave = { range, toneCount, edo, program, previewEnabled ->
                    val nextRange = sanitizeExtraPlayableRange(range)
                    val nextToneCount = sanitizeChordToneCount(toneCount)
                    val nextEdo = sanitizeExtraEdo(edo)
                    val nextProgram = sanitizeMidiProgramNumber(program)
                    val shouldCreateNewPuzzle =
                        nextRange != playableRange || nextToneCount != chordToneCount || nextEdo != extraEdo
                    playableRange = nextRange
                    chordToneCount = nextToneCount
                    extraEdo = nextEdo
                    instrumentProgram = nextProgram
                    keyPitchPreviewEnabled = previewEnabled
                    settings.savePlayableRange(playableRange)
                    settings.saveChordToneCount(chordToneCount)
                    settings.saveExtraEdo(extraEdo)
                    settings.saveInstrumentProgram(instrumentProgram)
                    settings.saveKeyPitchPreviewEnabled(keyPitchPreviewEnabled)
                    if (shouldCreateNewPuzzle) {
                        game.newPuzzle(ChordPuzzle.randomExtra(chordToneCount, playableRange, extraEdo))
                    }
                    showSettings = false
                    if (audioStatus == AudioStatus.Ready) {
                        scope.launch {
                            playTones(
                                playbackTonesForMode(mode, game.puzzle, game.puzzle.notes, extraEdo),
                                program = instrumentProgram,
                                durationMillis = 1400
                            )
                        }
                    }
                }
            )
        } else {
            RangeSettingsDialog(
                range = playableRange,
                chordToneCount = chordToneCount,
                instrumentProgram = instrumentProgram,
                keyPitchPreviewEnabled = keyPitchPreviewEnabled,
                onDismiss = { showSettings = false },
                onSave = { range, toneCount, program, previewEnabled ->
                    val nextRange = sanitizePlayableRange(range)
                    val nextToneCount = sanitizeChordToneCount(toneCount)
                    val nextProgram = sanitizeMidiProgramNumber(program)
                    val shouldCreateNewPuzzle = nextRange != playableRange || nextToneCount != chordToneCount
                    playableRange = nextRange
                    chordToneCount = nextToneCount
                    instrumentProgram = nextProgram
                    keyPitchPreviewEnabled = previewEnabled
                    settings.savePlayableRange(playableRange)
                    settings.saveChordToneCount(chordToneCount)
                    settings.saveInstrumentProgram(instrumentProgram)
                    settings.saveKeyPitchPreviewEnabled(keyPitchPreviewEnabled)
                    if (shouldCreateNewPuzzle) {
                        game.newPuzzle(chordToneCount, playableRange)
                    }
                    showSettings = false
                    if (audioStatus == AudioStatus.Ready) {
                        scope.launch {
                            playNotes(game.puzzle.notes, program = instrumentProgram, durationMillis = 1400)
                        }
                    }
                }
            )
        }
    }
}

@Composable
private fun ChordleHeader(
    onHelp: () -> Unit,
    onSettings: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .border(width = 0.5.dp, color = WordleBorder.copy(alpha = 0.65f))
            .padding(horizontal = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        TextButton(
            onClick = onHelp,
            modifier = Modifier.align(Alignment.CenterStart),
            contentPadding = PaddingValues(horizontal = 12.dp)
        ) {
            Text("?", fontSize = 24.sp, color = ChordleMuted, fontWeight = FontWeight.Bold)
        }

        Text(
            text = "Chordle",
            color = ChordleText,
            fontSize = 34.sp,
            fontWeight = FontWeight.Black,
            fontFamily = FontFamily.Serif,
            maxLines = 1,
            overflow = TextOverflow.Clip
        )

        TextButton(
            onClick = onSettings,
            modifier = Modifier.align(Alignment.CenterEnd),
            contentPadding = PaddingValues(horizontal = 6.dp)
        ) {
            Text("⚙", fontSize = 21.sp, color = ChordleMuted, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun GameStatusLine(
    audioStatus: AudioStatus,
    detailText: String,
    attempt: Int,
    maxAttempts: Int,
    onNewPuzzle: () -> Unit
) {
    val statusText = when (audioStatus) {
        AudioStatus.Loading -> "音色加载中"
        AudioStatus.Ready -> null
        is AudioStatus.Error -> audioStatus.message
    }
    val statusColor = when (audioStatus) {
        AudioStatus.Loading -> ChordleYellow
        is AudioStatus.Error -> Color(0xFFE57373)
        AudioStatus.Ready -> ChordleGreen
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(ChordleSurface)
            .padding(horizontal = 8.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = detailText,
            color = ChordleMuted,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        if (statusText != null) {
            Text(
                text = statusText,
                color = statusColor,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 12.dp),
                textAlign = TextAlign.End,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Row(
            modifier = Modifier
                .height(34.dp),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "$attempt/$maxAttempts",
                color = ChordleMuted,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                lineHeight = 18.sp,
                modifier = Modifier.align(Alignment.CenterVertically)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .align(Alignment.CenterVertically)
                    .clickable(onClick = onNewPuzzle),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_restart_24),
                    contentDescription = "重新开始",
                    tint = ChordleMuted,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

@Composable
private fun BoardArea(
    game: ChordleGame,
    audioReady: Boolean,
    requireJudgedPlayback: Boolean,
    onSortRow: (Int) -> Unit,
    onPlayRow: (Int) -> Unit,
    onPlayValue: (Int) -> Unit,
    valueLabel: (Int) -> String,
    modifier: Modifier = Modifier
) {
    val cellBounds = remember { mutableStateMapOf<BoardCellKey, Rect>() }
    var boardBounds by remember { mutableStateOf<Rect?>(null) }
    var draggedTile by remember { mutableStateOf<DraggedPreviousTile?>(null) }

    BoxWithConstraints(
        modifier = modifier
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .onGloballyPositioned { coordinates ->
                boardBounds = coordinates.boundsInRoot()
            },
        contentAlignment = Alignment.Center
    ) {
        val density = LocalDensity.current
        val gap = 6.dp
        val playButtonLane = 40.dp
        val tileSize = remember(maxWidth, maxHeight, game.columns) {
            val horizontal = (maxWidth - playButtonLane * 2 - gap * (game.columns - 1)) / game.columns
            val vertical = (maxHeight - gap * (game.maxAttempts - 1)) / game.maxAttempts
            minOf(64.dp, horizontal, vertical)
        }
        val rowWidth = tileSize * game.columns + gap * (game.columns - 1) + playButtonLane * 2

        Column(
            verticalArrangement = Arrangement.spacedBy(gap),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            repeat(game.maxAttempts) { row ->
                Box(
                    modifier = Modifier
                        .width(rowWidth)
                        .height(tileSize),
                    contentAlignment = Alignment.Center
                ) {
                    val rowNotes = game.rowNotes(row)
                    val canPlayRow = audioReady &&
                        rowNotes.isNotEmpty() &&
                        (!requireJudgedPlayback || game.rowIsJudged(row))
                    val canSortRow = game.canSortRow(row)
                    TextButton(
                        onClick = { onSortRow(row) },
                        enabled = canSortRow,
                        modifier = Modifier
                            .align(Alignment.CenterStart)
                            .size(34.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(
                            painter = painterResource(id = R.drawable.ic_sort_24),
                            contentDescription = "排序此行",
                            tint = if (canSortRow) ChordleMuted else WordleBorder,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Row(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalArrangement = Arrangement.spacedBy(gap),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        repeat(game.columns) { column ->
                            val cell = game.cell(row, column)
                            val cellKey = BoardCellKey(row, column)
                            val sourceNote = cell.note
                            val canDragTile = sourceNote != null &&
                                (game.canCarryCorrectCellFromPreviousRow(row, column) ||
                                    game.canDragPresentCellFromPreviousRow(row, column))
                            val dragModifier = if (
                                sourceNote != null &&
                                canDragTile
                            ) {
                                Modifier.pointerInput(row, column, sourceNote, cell.state, game.currentRow, game.status) {
                                    detectDragGesturesAfterLongPress(
                                        onDragStart = { touchOffset ->
                                            val sourceBounds = cellBounds[cellKey]
                                            if (sourceBounds != null) {
                                                draggedTile = DraggedPreviousTile(
                                                    sourceColumn = column,
                                                    note = sourceNote,
                                                    state = cell.state,
                                                    touchPosition = sourceBounds.topLeft + touchOffset
                                                )
                                            }
                                        },
                                        onDragCancel = {
                                            draggedTile = null
                                        },
                                        onDragEnd = {
                                            val drag = draggedTile
                                            if (drag != null) {
                                                val dropPosition = drag.touchPosition + drag.dragOffset
                                                when (drag.state) {
                                                    TileState.Correct -> {
                                                        val targetBounds = cellBounds[
                                                            BoardCellKey(game.currentRow, drag.sourceColumn)
                                                        ]
                                                        if (targetBounds?.contains(dropPosition) == true) {
                                                            game.carryCorrectCellFromPreviousRow(drag.sourceColumn)
                                                        }
                                                    }
                                                    TileState.Present -> {
                                                        val targetColumn = (0 until game.columns).firstOrNull { targetColumn ->
                                                            cellBounds[BoardCellKey(game.currentRow, targetColumn)]
                                                                ?.contains(dropPosition) == true
                                                        }
                                                        if (targetColumn != null) {
                                                            game.placePresentCellFromPreviousRow(
                                                                sourceColumn = drag.sourceColumn,
                                                                targetColumn = targetColumn
                                                            )
                                                        }
                                                    }
                                                    else -> Unit
                                                }
                                            }
                                            draggedTile = null
                                        },
                                        onDrag = { change, dragAmount ->
                                            change.consume()
                                            draggedTile = draggedTile?.let { drag ->
                                                if (drag.sourceColumn == column) {
                                                    drag.copy(dragOffset = drag.dragOffset + dragAmount)
                                                } else {
                                                    drag
                                                }
                                            }
                                        }
                                    )
                                }
                            } else {
                                Modifier
                            }
                            val canPlayCell = audioReady &&
                                (!requireJudgedPlayback || game.cellIsJudged(row, column))
                            ChordTile(
                                cell = cell,
                                active = game.status == GameStatus.Playing &&
                                    row == game.currentRow &&
                                    column == game.currentColumn,
                                size = tileSize,
                                valueLabel = valueLabel,
                                onClick = cell.note
                                    ?.takeIf { canPlayCell }
                                    ?.let { value -> { onPlayValue(value) } },
                                modifier = Modifier
                                    .onGloballyPositioned { coordinates ->
                                        cellBounds[cellKey] = coordinates.boundsInRoot()
                                    }
                                    .then(dragModifier)
                            )
                        }
                    }
                    TextButton(
                        onClick = { onPlayRow(row) },
                        enabled = canPlayRow,
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .size(34.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Text(
                            text = "▶",
                            color = if (canPlayRow) ChordleMuted else WordleBorder,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }

        val drag = draggedTile
        val bounds = boardBounds
        if (drag != null && bounds != null) {
            val tileSizePx = with(density) { tileSize.toPx() }
            val tileTopLeft = drag.touchPosition +
                drag.dragOffset -
                bounds.topLeft -
                Offset(tileSizePx / 2f, tileSizePx / 2f)
            ChordTile(
                cell = GuessCell(
                    note = drag.note,
                    state = if (drag.state == TileState.Correct) TileState.Carried else drag.state
                ),
                active = false,
                size = tileSize,
                valueLabel = valueLabel,
                onClick = null,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .offset {
                        IntOffset(tileTopLeft.x.roundToInt(), tileTopLeft.y.roundToInt())
                    }
                    .zIndex(1f)
            )
        }
    }
}

@Composable
private fun ChordTile(
    cell: GuessCell,
    active: Boolean,
    size: Dp,
    valueLabel: (Int) -> String,
    onClick: (() -> Unit)?,
    modifier: Modifier = Modifier
) {
    val background = when (cell.state) {
        TileState.Carried,
        TileState.Correct -> ChordleGreen
        TileState.ExtraCorrect -> ExtraCorrectBlue
        TileState.Present -> ChordleYellow
        TileState.ExtraNear -> ExtraNearPink
        TileState.Absent -> ChordleGray
        else -> ChordleBackground
    }
    val border = when {
        active -> Color.White
        cell.state == TileState.Input -> ChordleMuted
        cell.state == TileState.Empty -> WordleBorder
        else -> background
    }

    Box(
        modifier = modifier
            .size(size)
            .background(background)
            .border(width = 2.dp, color = border)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        contentAlignment = Alignment.Center
    ) {
        val label = cell.note?.let(valueLabel).orEmpty()
        val multiline = label.contains('\n')
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 3.dp, vertical = 2.dp),
            contentAlignment = Alignment.Center
        ) {
            val longestLineLength = label
                .lines()
                .maxOfOrNull { it.length }
                ?.coerceAtLeast(1) ?: 1
            val lineCount = if (multiline) 2 else 1
            val baseFontSize = if (multiline) 13f else 18f
            val widthLimitedFontSize = maxWidth.value / (longestLineLength * 0.58f)
            val heightLimitedFontSize = maxHeight.value / (lineCount * 1.18f)
            val fittedFontSize = min(
                baseFontSize,
                min(widthLimitedFontSize, heightLimitedFontSize)
            ).coerceAtLeast(8f)
            Text(
                text = label,
                modifier = Modifier.fillMaxWidth(),
                color = Color.White,
                fontSize = fittedFontSize.sp,
                fontWeight = FontWeight.Black,
                textAlign = TextAlign.Center,
                lineHeight = (fittedFontSize * if (multiline) 1.16f else 1.1f).sp,
                maxLines = if (multiline) 2 else 1,
                overflow = TextOverflow.Clip
            )
        }
    }
}

private fun ChordleGame.guessedValueStates(): Map<Int, TileState> {
    val states = mutableMapOf<Int, TileState>()
    for (row in 0 until maxAttempts) {
        for (column in 0 until columns) {
            val cell = cell(row, column)
            val value = cell.note ?: continue
            val priority = cell.state.valueStatePriority()
            if (priority <= 0) {
                continue
            }
            val previous = states[value]
            if (previous == null || priority > previous.valueStatePriority()) {
                states[value] = cell.state
            }
        }
    }
    return states
}

private fun TileState.valueStatePriority(): Int {
    return when (this) {
        TileState.Correct,
        TileState.Carried -> 4
        TileState.Present -> 3
        TileState.ExtraCorrect -> 2
        TileState.ExtraNear -> 1
        else -> 0
    }
}

private fun valueStateControlColor(state: TileState?): Color? {
    return when (state) {
        TileState.Correct,
        TileState.Carried -> ChordleGreen
        TileState.Present -> ChordleYellow
        TileState.ExtraCorrect -> ExtraCorrectBlue
        TileState.ExtraNear -> ExtraNearPink
        else -> null
    }
}

@Composable
private fun InputPanel(
    game: ChordleGame,
    audioReady: Boolean,
    onPlayChord: () -> Unit,
    onPreviewValue: (Int) -> Unit,
    selectionLabel: (Int) -> String = ::noteLabel,
    emptySelectionText: String = "未选音",
    confirmButtonText: String = "确认此音",
    missingSelectionMessage: String = "先在钢琴上选择一个音",
    submitItemName: String = "音",
    onSubmit: () -> Unit = { game.submitGuess(submitItemName) },
    keyboardContent: @Composable (Int?, (Int) -> Unit) -> Unit = { selectedValue, onValuePressed ->
        PianoKeyboard(
            noteRange = FullPianoRange,
            selectedNote = selectedValue,
            onNotePressed = onValuePressed,
            modifier = Modifier.fillMaxWidth()
        )
    }
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(ChordleBackground)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Button(
                onClick = onPlayChord,
                enabled = audioReady,
                modifier = Modifier.weight(1.1f),
                colors = ButtonDefaults.buttonColors(containerColor = ChordleGreen)
            ) {
                Text("▶ 播放和弦", maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Surface(
                modifier = Modifier.weight(1f),
                color = ChordleSurface,
                shape = RoundedCornerShape(6.dp)
            ) {
                Text(
                    text = game.selectedNote?.let { "选中 ${selectionLabel(it)}" } ?: emptySelectionText,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 10.dp),
                    color = ChordleText,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = {
                    game.confirmSelectedValue(
                        missingSelectionMessage = missingSelectionMessage
                    )
                },
                enabled = game.status == GameStatus.Playing,
                modifier = Modifier.weight(1f)
            ) {
                Text(confirmButtonText, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            OutlinedButton(
                onClick = { game.deleteLast() },
                enabled = game.canDeleteLast(),
                modifier = Modifier.weight(0.72f)
            ) {
                Text("删除", maxLines = 1)
            }
            Button(
                onClick = onSubmit,
                enabled = game.status == GameStatus.Playing && game.rowIsFull(game.currentRow),
                modifier = Modifier.weight(0.85f),
                colors = ButtonDefaults.buttonColors(containerColor = ChordleGray)
            ) {
                Text("提交", maxLines = 1)
            }
        }

        if (game.status != GameStatus.Playing) {
            Text(
                text = if (game.status == GameStatus.Won) "已完成：${game.answerText}" else "答案：${game.answerText}",
                color = ChordleMuted,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
                fontSize = 13.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        keyboardContent(game.selectedNote, onPreviewValue)
    }
}

@Composable
private fun OvertoneInputPanel(
    game: ChordleGame,
    overtoneRange: IntRange,
    valueStates: Map<Int, TileState>,
    audioReady: Boolean,
    onPlayChord: () -> Unit,
    onPreviewMultiplier: (Int) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(ChordleBackground)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Button(
                onClick = onPlayChord,
                enabled = audioReady,
                modifier = Modifier.weight(1.1f),
                colors = ButtonDefaults.buttonColors(containerColor = ChordleGreen)
            ) {
                Text("▶ 播放和弦", maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Surface(
                modifier = Modifier.weight(1f),
                color = ChordleSurface,
                shape = RoundedCornerShape(6.dp)
            ) {
                Text(
                    text = game.selectedNote?.let { "选中 ${it}x" } ?: "未选数字",
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 10.dp),
                    color = ChordleText,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = {
                    game.confirmSelectedValue(
                        missingSelectionMessage = "先在数字键盘上选择一个数字"
                    )
                },
                enabled = game.status == GameStatus.Playing,
                modifier = Modifier.weight(1f)
            ) {
                Text("确认数字", maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            OutlinedButton(
                onClick = { game.deleteLast() },
                enabled = game.canDeleteLast(),
                modifier = Modifier.weight(0.72f)
            ) {
                Text("删除", maxLines = 1)
            }
            Button(
                onClick = { game.submitGuess("数字") },
                enabled = game.status == GameStatus.Playing && game.rowIsFull(game.currentRow),
                modifier = Modifier.weight(0.85f),
                colors = ButtonDefaults.buttonColors(containerColor = ChordleGray)
            ) {
                Text("提交", maxLines = 1)
            }
        }

        if (game.status != GameStatus.Playing) {
            Text(
                text = if (game.status == GameStatus.Won) "已完成：${game.answerText}" else "答案：${game.answerText}",
                color = ChordleMuted,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
                fontSize = 13.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        OvertoneNumberPad(
            multiplierRange = overtoneRange,
            selectedMultiplier = game.selectedNote,
            valueStates = valueStates,
            onMultiplierPressed = onPreviewMultiplier,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun OvertoneNumberPad(
    multiplierRange: IntRange,
    selectedMultiplier: Int?,
    valueStates: Map<Int, TileState> = emptyMap(),
    onMultiplierPressed: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val multipliers = remember(multiplierRange) { sanitizeOvertoneRange(multiplierRange).toList() }
    val columns = if (multipliers.size <= 10) 5 else 8
    val rows = remember(multipliers, columns) { multipliers.chunked(columns) }

    Column(
        modifier = modifier
            .background(ChordleBackground)
            .padding(top = 2.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        rows.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                row.forEach { multiplier ->
                    val selected = multiplier == selectedMultiplier
                    val stateColor = valueStateControlColor(valueStates[multiplier])
                    Button(
                        onClick = { onMultiplierPressed(multiplier) },
                        modifier = Modifier
                            .weight(1f)
                            .height(42.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = when {
                                selected -> SelectedValuePurple.copy(alpha = SelectedValueAlpha)
                                stateColor != null -> stateColor.copy(alpha = ControlValueStateAlpha)
                                else -> ChordleSurface
                            },
                            contentColor = Color.White
                        ),
                        contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp)
                    ) {
                        Text(
                            text = multiplier.toString(),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            overflow = TextOverflow.Clip
                        )
                    }
                }
                repeat(columns - row.size) {
                    Spacer(
                        modifier = Modifier
                            .weight(1f)
                            .height(42.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun PianoKeyboard(
    noteRange: IntRange,
    selectedNote: Int?,
    valueStates: Map<Int, TileState> = emptyMap(),
    onNotePressed: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val sanitizedRange = remember(noteRange) { sanitizePlayableRange(noteRange) }
    val whiteNotes = remember(sanitizedRange) { sanitizedRange.filterNot(::isBlackKey) }
    val blackNotes = remember(sanitizedRange) { sanitizedRange.filter(::isBlackKey) }
    val labelPaint = remember {
        AndroidPaint(AndroidPaint.ANTI_ALIAS_FLAG).apply {
            textAlign = AndroidPaint.Align.CENTER
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        }
    }
    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }

    BoxWithConstraints(
        modifier = modifier
            .height(172.dp)
            .background(ChordleBackground)
    ) {
        val viewportWidthPx = with(density) { maxWidth.toPx() }
        val baseWhiteWidthPx = with(density) { 42.dp.toPx() }
        val whiteWidthPx = baseWhiteWidthPx * scale
        val contentWidthPx = whiteNotes.size * whiteWidthPx
        val minOffset = min(0f, viewportWidthPx - contentWidthPx)

        LaunchedEffect(minOffset, contentWidthPx) {
            offsetX = offsetX.coerceIn(minOffset, 0f)
        }

        val transformState = rememberTransformableState { zoomChange, panChange, _ ->
            val nextScale = (scale * zoomChange).coerceIn(0.72f, 2.35f)
            val nextWhiteWidth = baseWhiteWidthPx * nextScale
            val nextContentWidth = whiteNotes.size * nextWhiteWidth
            val nextMinOffset = min(0f, viewportWidthPx - nextContentWidth)
            scale = nextScale
            offsetX = (offsetX + panChange.x).coerceIn(nextMinOffset, 0f)
        }

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight()
                .clipToBounds()
                .background(Color(0xFF0F0F10))
                .pointerInput(scale, offsetX, viewportWidthPx) {
                    detectTapGestures { position ->
                        findPianoNote(
                            x = position.x,
                            y = position.y,
                            offsetX = offsetX,
                            whiteWidth = whiteWidthPx,
                            height = size.height.toFloat(),
                            whiteNotes = whiteNotes,
                            blackNotes = blackNotes
                        )?.let(onNotePressed)
                    }
                }
                .transformable(transformState)
        ) {
            val keyGap = 1.4.dp.toPx()
            val corner = CornerRadius(5.dp.toPx(), 5.dp.toPx())
            val blackWidth = whiteWidthPx * 0.62f
            val blackHeight = size.height * 0.62f

            withTransform({ translate(left = offsetX) }) {
                whiteNotes.forEachIndexed { index, note ->
                    val x = index * whiteWidthPx
                    val topLeft = Offset(x + keyGap / 2f, 0f)
                    val keySize = Size(whiteWidthPx - keyGap, size.height)
                    drawRoundRect(
                        color = Color(0xFFE9EAEC),
                        topLeft = topLeft,
                        size = keySize,
                        cornerRadius = corner
                    )
                    valueStateControlColor(valueStates[note])?.let { color ->
                        drawRoundRect(
                            color = color.copy(alpha = ControlValueStateAlpha),
                            topLeft = topLeft,
                            size = keySize,
                            cornerRadius = corner
                        )
                    }
                    if (note == selectedNote) {
                        drawRoundRect(
                            color = SelectedValuePurple.copy(alpha = SelectedValueAlpha),
                            topLeft = topLeft,
                            size = keySize,
                            cornerRadius = corner
                        )
                    }
                    drawIntoCanvas { canvas ->
                        labelPaint.color = android.graphics.Color.rgb(39, 39, 42)
                        labelPaint.textSize = 11.sp.toPx()
                        canvas.nativeCanvas.drawText(
                            noteLabel(note),
                            x + whiteWidthPx / 2f,
                            size.height - 13.dp.toPx(),
                            labelPaint
                        )
                    }
                }

                blackNotes.forEach { note ->
                    val before = whiteNotes.count { it < note }
                    val x = before * whiteWidthPx - blackWidth / 2f
                    val topLeft = Offset(x, 0f)
                    val keySize = Size(blackWidth, blackHeight)
                    drawRoundRect(
                        color = Color(0xFF151518),
                        topLeft = topLeft,
                        size = keySize,
                        cornerRadius = corner
                    )
                    valueStateControlColor(valueStates[note])?.let { color ->
                        drawRoundRect(
                            color = color.copy(alpha = ControlValueStateAlpha),
                            topLeft = topLeft,
                            size = keySize,
                            cornerRadius = corner
                        )
                    }
                    if (note == selectedNote) {
                        drawRoundRect(
                            color = SelectedValuePurple.copy(alpha = SelectedValueAlpha),
                            topLeft = topLeft,
                            size = keySize,
                            cornerRadius = corner
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MicrotonalKeyboard(
    edo: Int,
    noteRange: IntRange,
    selectedStep: Int?,
    valueStates: Map<Int, TileState> = emptyMap(),
    onStepPressed: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val normalizedEdo = sanitizeExtraEdo(edo)
    val touchStepRange = remember(normalizedEdo, noteRange) {
        extraStepRangeForMidiRange(normalizedEdo, noteRange)
    }
    val rulerStepRange = remember(normalizedEdo, touchStepRange) {
        expandedMicrotonalRulerStepRange(touchStepRange, normalizedEdo)
    }
    val labelPaint = remember {
        AndroidPaint(AndroidPaint.ANTI_ALIAS_FLAG).apply {
            textAlign = AndroidPaint.Align.CENTER
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        }
    }
    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }

    BoxWithConstraints(
        modifier = modifier
            .height(172.dp)
            .background(ChordleBackground)
    ) {
        val viewportWidthPx = with(density) { maxWidth.toPx() }
        val baseStepWidthPx = with(density) { 18.dp.toPx() }
        val stepWidthPx = baseStepWidthPx * scale
        val stepCount = rulerStepRange.last - rulerStepRange.first + 1
        val contentWidthPx = stepCount * stepWidthPx
        val minOffset = min(0f, viewportWidthPx - contentWidthPx)

        LaunchedEffect(minOffset, contentWidthPx, selectedStep) {
            offsetX = offsetX.coerceIn(minOffset, 0f)
        }

        val transformState = rememberTransformableState { zoomChange, panChange, _ ->
            val nextScale = (scale * zoomChange).coerceIn(0.64f, 3.6f)
            val nextStepWidth = baseStepWidthPx * nextScale
            val nextContentWidth = stepCount * nextStepWidth
            val nextMinOffset = min(0f, viewportWidthPx - nextContentWidth)
            scale = nextScale
            offsetX = (offsetX + panChange.x).coerceIn(nextMinOffset, 0f)
        }

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight()
                .clipToBounds()
                .background(Color(0xFF090B0F))
                .pointerInput(normalizedEdo, rulerStepRange, touchStepRange, scale, offsetX, viewportWidthPx) {
                    detectTapGestures { position ->
                        findMicrotonalStep(
                            x = position.x,
                            offsetX = offsetX,
                            stepWidth = stepWidthPx,
                            rulerStepRange = rulerStepRange,
                            touchStepRange = touchStepRange
                        )?.let(onStepPressed)
                    }
                }
                .transformable(transformState)
        ) {
            val corner = CornerRadius(7.dp.toPx(), 7.dp.toPx())
            val panelInset = 2.dp.toPx()
            val panelTopLeft = Offset(panelInset, panelInset)
            val panelSize = Size(size.width - panelInset * 2f, size.height - panelInset * 2f)
            val pitchStep = 12.0 / normalizedEdo
            val minPitchSpacing = MicrotonalKeyboardMinTickSpacingPx * pitchStep / stepWidthPx

            drawRoundRect(
                brush = Brush.verticalGradient(
                    listOf(
                        Color(0x6028323F),
                        Color(0xD0080A0F),
                        Color(0xF006070A)
                    )
                ),
                topLeft = panelTopLeft,
                size = panelSize,
                cornerRadius = corner
            )
            drawRoundRect(
                brush = Brush.verticalGradient(
                    listOf(
                        Color(0x22FFFFFF),
                        Color.Transparent,
                        Color(0x30000000)
                    )
                ),
                topLeft = panelTopLeft,
                size = panelSize,
                cornerRadius = corner
            )

            withTransform({ translate(left = offsetX) }) {
                selectedStep?.takeIf { it in touchStepRange }?.let { step ->
                    val x = (step - rulerStepRange.first) * stepWidthPx
                    drawRoundRect(
                        color = SelectedValuePurple.copy(alpha = SelectedValueAlpha),
                        topLeft = Offset(x + 1.dp.toPx(), panelInset),
                        size = Size(max(2f, stepWidthPx - 2.dp.toPx()), size.height - panelInset * 2f),
                        cornerRadius = CornerRadius(5.dp.toPx(), 5.dp.toPx())
                    )
                }

                for (step in rulerStepRange) {
                    val x = (step - rulerStepRange.first) * stepWidthPx + stepWidthPx / 2f
                    if (x + offsetX < -2f || x + offsetX > size.width + 2f) {
                        continue
                    }
                    val octaveStep = positiveModulo(step, normalizedEdo)
                    val marker = edoMarkerForStep(normalizedEdo, octaveStep)
                    val baseRatio = ExtraEdoMarkRatios[marker] ?: 0f
                    if (baseRatio <= 0f) {
                        continue
                    }
                    val isC = octaveStep == 0
                    val visibilityRatio = denseLineVisibilityRatio(
                        stepIndex = step,
                        step = pitchStep,
                        minPitchSpacing = minPitchSpacing,
                        isAnchor = isC
                    )
                    val ratio = (baseRatio * visibilityRatio).coerceIn(0f, 1f)
                    if (ratio <= 0f) {
                        continue
                    }
                    val tickLength = size.height * MicrotonalCTickHeightRatio * ratio
                    val alpha = (MicrotonalCTickAlpha * ratio).roundToInt().coerceIn(0, MicrotonalCTickAlpha)
                    val stateColor = valueStateControlColor(valueStates[step])
                    val strokeWidth = if (isC) 1.4.dp.toPx() else 1.dp.toPx()
                    if (stateColor != null) {
                        val bandWidth = max(4.dp.toPx(), min(stepWidthPx * 0.72f, 9.dp.toPx()))
                        val bandHeight = max(tickLength, size.height * MicrotonalValueStateMinBandHeightRatio)
                        drawRoundRect(
                            color = stateColor.copy(alpha = MicrotonalValueStateBandAlpha),
                            topLeft = Offset(x - bandWidth / 2f, panelInset),
                            size = Size(bandWidth, bandHeight),
                            cornerRadius = CornerRadius(3.dp.toPx(), 3.dp.toPx())
                        )
                        drawLine(
                            color = stateColor.copy(alpha = MicrotonalValueStateHaloAlpha),
                            start = Offset(x, panelInset),
                            end = Offset(x, panelInset + tickLength),
                            strokeWidth = max(strokeWidth + 3.dp.toPx(), 4.dp.toPx())
                        )
                    }
                    drawLine(
                        color = stateColor?.copy(
                            alpha = max(alpha / 255f, MicrotonalValueStateLineMinAlpha)
                        ) ?: xenRulerHighlight(alpha),
                        start = Offset(x, panelInset),
                        end = Offset(x, panelInset + tickLength),
                        strokeWidth = if (stateColor != null) {
                            max(strokeWidth, MicrotonalValueStateLineMinWidthDp.dp.toPx())
                        } else {
                            strokeWidth
                        }
                    )
                    if (isC) {
                        val octaveLabel = "C${step / normalizedEdo - 1}"
                        drawIntoCanvas { canvas ->
                            labelPaint.color = android.graphics.Color.argb(184, 255, 222, 111)
                            labelPaint.textSize = 10.sp.toPx()
                            canvas.nativeCanvas.drawText(
                                octaveLabel,
                                x,
                                size.height - 8.dp.toPx(),
                                labelPaint
                            )
                        }
                    } else if (shouldDrawMicrotonalStepLabel(normalizedEdo, marker)) {
                        drawIntoCanvas { canvas ->
                            labelPaint.color = android.graphics.Color.argb(144, 255, 222, 111)
                            labelPaint.textSize = 8.sp.toPx()
                            canvas.nativeCanvas.drawText(
                                octaveStep.toString(),
                                x,
                                (panelInset + tickLength + 10.dp.toPx()).coerceAtMost(size.height - 24.dp.toPx()),
                                labelPaint
                            )
                        }
                    }
                }
            }

            drawLine(
                color = Color.White.copy(alpha = 0.18f),
                start = Offset(panelInset, panelInset),
                end = Offset(size.width - panelInset, panelInset),
                strokeWidth = 1f
            )
            drawLine(
                color = xenRulerHighlight(168),
                start = Offset(panelInset, size.height - panelInset),
                end = Offset(size.width - panelInset, size.height - panelInset),
                strokeWidth = 1f
            )
        }
    }
}

@Composable
private fun HelpDialog(
    mode: ChordleMode,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("知道了")
            }
        },
        title = { Text("Chordle") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (mode == ChordleMode.Overtones) {
                    Text("每局会随机选择一个基音，并从设置的整数区间生成倍频数组。")
                    Text("可按任意顺序输入倍频数，提交后按从小到大的答案位置验证。")
                } else {
                    Text("会按设置随机播放 1-10 个音，1 为单音测试。")
                    Text("可按任意顺序输入音符，提交后按从低到高的答案位置验证。")
                }
                if (mode == ChordleMode.Extra) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ChordleGreen)
                        Spacer(Modifier.width(8.dp))
                        Text("绿色：该位置音高完全正确，全绿才胜利")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ExtraCorrectBlue)
                        Spacer(Modifier.width(8.dp))
                        Text("淡蓝：该位置音高误差在 50 音分内")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ChordleYellow)
                        Spacer(Modifier.width(8.dp))
                        Text("黄色：音高完全正确，但位置不对")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ExtraNearPink)
                        Spacer(Modifier.width(8.dp))
                        Text("淡粉：和弦内有 50 音分内的近似音，但位置不对")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ChordleGray)
                        Spacer(Modifier.width(8.dp))
                        Text("灰色：和弦里没有 50 音分内的音")
                    }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ChordleGreen)
                        Spacer(Modifier.width(8.dp))
                        Text("绿色：音高和位置都正确")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ChordleYellow)
                        Spacer(Modifier.width(8.dp))
                        Text("黄色：有这个音，但位置不对")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RuleChip(color = ChordleGray)
                        Spacer(Modifier.width(8.dp))
                        Text("灰色：和弦里没有这个音")
                    }
                }
            }
        },
        containerColor = Color(0xFFF8F0F8),
        titleContentColor = Color(0xFF4E4156),
        textContentColor = Color(0xFF6E5D75)
    )
}

@Composable
private fun RuleChip(color: Color) {
    Box(
        modifier = Modifier
            .size(22.dp)
            .aspectRatio(1f)
            .background(color)
    )
}

private fun findPianoNote(
    x: Float,
    y: Float,
    offsetX: Float,
    whiteWidth: Float,
    height: Float,
    whiteNotes: List<Int>,
    blackNotes: List<Int>
): Int? {
    val localX = x - offsetX
    if (localX < 0f) {
        return null
    }

    val blackWidth = whiteWidth * 0.62f
    val blackHeight = height * 0.62f
    if (y <= blackHeight) {
        for (note in blackNotes.asReversed()) {
            val before = whiteNotes.count { it < note }
            val keyX = before * whiteWidth - blackWidth / 2f
            if (localX >= keyX && localX <= keyX + blackWidth) {
                return note
            }
        }
    }

    val whiteIndex = floor(localX / whiteWidth).toInt()
    return whiteNotes.getOrNull(whiteIndex)
}

private data class PlaybackTone(
    val key: Int,
    val cents: Float = 0f
)

private fun valueLabelForMode(mode: ChordleMode, extraEdo: Int = DefaultExtraEdo): (Int) -> String {
    return when (mode) {
        ChordleMode.Overtones -> { value -> value.toString() }
        ChordleMode.Extra -> { value -> extraStepTileLabel(value, extraEdo) }
        ChordleMode.Normal -> ::noteLabel
    }
}

private fun playbackTonesForMode(
    mode: ChordleMode,
    puzzle: ChordPuzzle,
    values: List<Int>,
    extraEdo: Int = DefaultExtraEdo
): List<PlaybackTone> {
    return when (mode) {
        ChordleMode.Overtones -> overtonePlaybackTones(puzzle, values)
        ChordleMode.Extra -> extraPlaybackTones(values, extraEdo)
        ChordleMode.Normal -> values.map { PlaybackTone(key = it) }
    }
}

private fun extraPlaybackTones(steps: List<Int>, edo: Int): List<PlaybackTone> {
    return steps.map { step -> extraPlaybackTone(step, edo) }
}

private fun extraPlaybackTone(step: Int, edo: Int): PlaybackTone {
    val midiValue = midiValueForExtraStep(step, edo)
    val key = round(midiValue).toInt().coerceIn(0, HighestPlayableMidiNote)
    val cents = ((midiValue - key) * 100.0).toFloat()
    return PlaybackTone(key = key, cents = cents)
}

private fun overtonePlaybackTones(puzzle: ChordPuzzle, multipliers: List<Int>): List<PlaybackTone> {
    val baseMidiNote = puzzle.baseMidiNote ?: return emptyList()
    return multipliers.map { multiplier -> overtonePlaybackTone(baseMidiNote, multiplier) }
}

private fun overtonePlaybackTone(baseMidiNote: Int, multiplier: Int): PlaybackTone {
    val frequency = midiNoteFrequency(baseMidiNote) * multiplier
    val midiValue = 69.0 + 12.0 * (ln(frequency / 440.0) / ln(2.0))
    val key = midiValue.roundToInt().coerceIn(0, HighestPlayableMidiNote)
    val cents = ((midiValue - key) * 100.0).toFloat()
    return PlaybackTone(key = key, cents = cents)
}

private fun overtoneRangeLabel(range: IntRange): String {
    val sanitized = sanitizeOvertoneRange(range)
    return "${sanitized.first}-${sanitized.last}x"
}

private suspend fun playNotes(
    notes: List<Int>,
    velocity: Int = 104,
    program: Int = DefaultMidiProgramNumber,
    durationMillis: Long = 1200
) {
    playTones(
        tones = notes.map { PlaybackTone(key = it) },
        velocity = velocity,
        program = program,
        durationMillis = durationMillis
    )
}

private suspend fun playTones(
    tones: List<PlaybackTone>,
    velocity: Int = 104,
    program: Int = DefaultMidiProgramNumber,
    durationMillis: Long = 1200
) {
    withContext(Dispatchers.Default) {
        val selectedProgram = sanitizeMidiProgramNumber(program)
        NativeAudioEngine.allSoundOff()
        val noteIds = tones.mapNotNull { tone ->
            NativeAudioEngine.noteOn(
                key = tone.key,
                velocity = velocity,
                cents = tone.cents,
                channel = 0,
                program = selectedProgram,
                bankMsb = 0,
                bankLsb = 0
            )
        }
        delay(durationMillis)
        noteIds.forEach { NativeAudioEngine.noteOff(it) }
    }
}

private class ChordleSettings(context: android.content.Context) {
    private val preferences = context.getSharedPreferences("chordle_settings", android.content.Context.MODE_PRIVATE)

    fun loadPlayableRange(): IntRange {
        val low = preferences.getInt(KEY_LOW, DefaultPlayableRange.first)
        val high = preferences.getInt(KEY_HIGH, DefaultPlayableRange.last)
        return sanitizePlayableRange(low..high)
    }

    fun savePlayableRange(range: IntRange) {
        val sanitized = sanitizePlayableRange(range)
        preferences.edit()
            .putInt(KEY_LOW, sanitized.first)
            .putInt(KEY_HIGH, sanitized.last)
            .apply()
    }

    fun loadChordToneCount(): Int {
        return sanitizeChordToneCount(preferences.getInt(KEY_TONE_COUNT, DefaultChordToneCount))
    }

    fun saveChordToneCount(noteCount: Int) {
        preferences.edit()
            .putInt(KEY_TONE_COUNT, sanitizeChordToneCount(noteCount))
            .apply()
    }

    fun loadExtraEdo(): Int {
        return sanitizeExtraEdo(preferences.getInt(KEY_EXTRA_EDO, DefaultExtraEdo))
    }

    fun saveExtraEdo(edo: Int) {
        preferences.edit()
            .putInt(KEY_EXTRA_EDO, sanitizeExtraEdo(edo))
            .apply()
    }

    fun loadOvertoneRange(): IntRange {
        val low = preferences.getInt(KEY_OVERTONE_LOW, DefaultOvertoneRange.first)
        val high = preferences.getInt(KEY_OVERTONE_HIGH, DefaultOvertoneRange.last)
        return sanitizeOvertoneRange(low..high)
    }

    fun saveOvertoneRange(range: IntRange) {
        val sanitized = sanitizeOvertoneRange(range)
        preferences.edit()
            .putInt(KEY_OVERTONE_LOW, sanitized.first)
            .putInt(KEY_OVERTONE_HIGH, sanitized.last)
            .apply()
    }

    fun loadOvertoneToneCount(): Int {
        return sanitizeOvertoneToneCount(
            preferences.getInt(KEY_OVERTONE_TONE_COUNT, DefaultOvertoneToneCount),
            loadOvertoneRange()
        )
    }

    fun saveOvertoneToneCount(noteCount: Int, multiplierRange: IntRange = loadOvertoneRange()) {
        preferences.edit()
            .putInt(KEY_OVERTONE_TONE_COUNT, sanitizeOvertoneToneCount(noteCount, multiplierRange))
            .apply()
    }

    fun loadInstrumentProgram(): Int {
        return sanitizeMidiProgramNumber(preferences.getInt(KEY_INSTRUMENT_PROGRAM, DefaultMidiProgramNumber))
    }

    fun saveInstrumentProgram(program: Int) {
        preferences.edit()
            .putInt(KEY_INSTRUMENT_PROGRAM, sanitizeMidiProgramNumber(program))
            .apply()
    }

    fun loadKeyPitchPreviewEnabled(): Boolean {
        return preferences.getBoolean(KEY_KEY_PITCH_PREVIEW_ENABLED, DefaultKeyPitchPreviewEnabled)
    }

    fun saveKeyPitchPreviewEnabled(enabled: Boolean) {
        preferences.edit()
            .putBoolean(KEY_KEY_PITCH_PREVIEW_ENABLED, enabled)
            .apply()
    }

    private companion object {
        const val KEY_LOW = "playable_range_low"
        const val KEY_HIGH = "playable_range_high"
        const val KEY_TONE_COUNT = "chord_tone_count"
        const val KEY_EXTRA_EDO = "extra_edo"
        const val KEY_OVERTONE_LOW = "overtone_range_low"
        const val KEY_OVERTONE_HIGH = "overtone_range_high"
        const val KEY_OVERTONE_TONE_COUNT = "overtone_tone_count"
        const val KEY_INSTRUMENT_PROGRAM = "instrument_program"
        const val KEY_KEY_PITCH_PREVIEW_ENABLED = "key_pitch_preview_enabled"
    }
}

@Composable
private fun DiscreteIntRangeSlider(
    value: IntRange,
    onValueChange: (IntRange) -> Unit,
    valueRange: IntRange,
    steps: Int,
    modifier: Modifier = Modifier
) {
    RangeSlider(
        value = value.first.toFloat()..value.last.toFloat(),
        onValueChange = { selectedRange ->
            onValueChange(selectedRange.start.roundToInt()..selectedRange.endInclusive.roundToInt())
        },
        modifier = modifier,
        valueRange = valueRange.first.toFloat()..valueRange.last.toFloat(),
        steps = steps.coerceAtLeast(0)
    )
}

@Composable
private fun WhiteKeyRangeSlider(
    value: IntRange,
    onValueChange: (IntRange) -> Unit,
    modifier: Modifier = Modifier
) {
    val whiteKeys = PlayableWhiteKeyMidiNotes
    val sanitized = sanitizePlayableRange(value)
    val lowIndex = whiteKeys.indexOf(sanitized.first).coerceAtLeast(0)
    val highIndex = whiteKeys.indexOf(sanitized.last).coerceAtLeast(lowIndex)

    DiscreteIntRangeSlider(
        value = lowIndex..highIndex,
        onValueChange = { selectedRange ->
            val low = whiteKeys[selectedRange.first.coerceIn(whiteKeys.indices)]
            val high = whiteKeys[selectedRange.last.coerceIn(whiteKeys.indices)]
            onValueChange(sanitizePlayableRange(low..high))
        },
        valueRange = whiteKeys.indices,
        steps = whiteKeys.size - 2,
        modifier = modifier
    )
}

@Composable
private fun RangeSettingsDialog(
    range: IntRange,
    chordToneCount: Int,
    instrumentProgram: Int,
    keyPitchPreviewEnabled: Boolean,
    onDismiss: () -> Unit,
    onSave: (IntRange, Int, Int, Boolean) -> Unit
) {
    var low by remember(range) { mutableFloatStateOf(range.first.toFloat()) }
    var high by remember(range) { mutableFloatStateOf(range.last.toFloat()) }
    var toneCount by remember(chordToneCount) { mutableFloatStateOf(chordToneCount.toFloat()) }
    var program by remember(instrumentProgram) {
        mutableFloatStateOf(sanitizeMidiProgramNumber(instrumentProgram).toFloat())
    }
    var previewEnabled by remember(keyPitchPreviewEnabled) { mutableStateOf(keyPitchPreviewEnabled) }

    fun currentRange(): IntRange {
        return sanitizePlayableRange(low.toInt()..high.toInt())
    }

    fun currentProgram(): Int {
        return sanitizeMidiProgramNumber(program.toInt())
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = { onSave(currentRange(), toneCount.toInt(), currentProgram(), previewEnabled) }) {
                Text("保存")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消")
            }
        },
        title = { Text("游戏设置") },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                val sanitized = currentRange()
                Text("出题音域：${rangeLabel(sanitized)}")
                Text(
                    text = "默认 3 音、C3-C5；音数可设为 1-10，音域可在 A0-C8 内选择，最小跨度为一个八度。",
                    fontSize = 14.sp,
                    color = Color(0xFF6E5D75)
                )
                Text("播放音数：${sanitizeChordToneCount(toneCount.toInt())}", fontWeight = FontWeight.Bold)
                Slider(
                    value = toneCount,
                    onValueChange = { value ->
                        toneCount = sanitizeChordToneCount(value.toInt()).toFloat()
                    },
                    valueRange = MinChordToneCount.toFloat()..MaxChordToneCount.toFloat(),
                    steps = MaxChordToneCount - MinChordToneCount - 1
                )
                Text("音色（MIDI program number）：${currentProgram()}", fontWeight = FontWeight.Bold)
                Slider(
                    value = program,
                    onValueChange = { value ->
                        program = sanitizeMidiProgramNumber(value.toInt()).toFloat()
                    },
                    valueRange = MinMidiProgramNumber.toFloat()..MaxMidiProgramNumber.toFloat(),
                    steps = MaxMidiProgramNumber - MinMidiProgramNumber - 1
                )
                SettingSwitchRow(
                    text = "选择按键时预听音高",
                    checked = previewEnabled,
                    onCheckedChange = { previewEnabled = it }
                )
                Text(
                    "音域两端：${noteLabel(sanitized.first)} / ${noteLabel(sanitized.last)}",
                    fontWeight = FontWeight.Bold
                )
                WhiteKeyRangeSlider(
                    value = sanitized,
                    onValueChange = { value ->
                        val nextRange = sanitizePlayableRange(value)
                        low = nextRange.first.toFloat()
                        high = nextRange.last.toFloat()
                    }
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            low = DefaultPlayableRange.first.toFloat()
                            high = DefaultPlayableRange.last.toFloat()
                            toneCount = DefaultChordToneCount.toFloat()
                            program = DefaultMidiProgramNumber.toFloat()
                            previewEnabled = DefaultKeyPitchPreviewEnabled
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("默认")
                    }
                    OutlinedButton(
                        onClick = {
                            low = LowestPlayableMidiNote.toFloat()
                            high = HighestPlayableMidiNote.toFloat()
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("全键盘")
                    }
                }
            }
        },
        containerColor = Color(0xFFF8F0F8),
        titleContentColor = Color(0xFF4E4156),
        textContentColor = Color(0xFF4E4156)
    )
}

@Composable
private fun ExtraSettingsDialog(
    range: IntRange,
    chordToneCount: Int,
    extraEdo: Int,
    instrumentProgram: Int,
    keyPitchPreviewEnabled: Boolean,
    onDismiss: () -> Unit,
    onSave: (IntRange, Int, Int, Int, Boolean) -> Unit
) {
    val initialRange = sanitizeExtraPlayableRange(range)
    var low by remember(initialRange) { mutableFloatStateOf(initialRange.first.toFloat()) }
    var high by remember(initialRange) { mutableFloatStateOf(initialRange.last.toFloat()) }
    var toneCount by remember(chordToneCount) { mutableFloatStateOf(chordToneCount.toFloat()) }
    var edo by remember(extraEdo) { mutableFloatStateOf(sanitizeExtraEdo(extraEdo).toFloat()) }
    var program by remember(instrumentProgram) {
        mutableFloatStateOf(sanitizeMidiProgramNumber(instrumentProgram).toFloat())
    }
    var previewEnabled by remember(keyPitchPreviewEnabled) { mutableStateOf(keyPitchPreviewEnabled) }

    fun currentRange(): IntRange {
        return sanitizeExtraPlayableRange(low.toInt()..high.toInt())
    }

    fun currentEdo(): Int {
        return sanitizeExtraEdo(edo.roundToInt())
    }

    fun setEdo(value: Int) {
        edo = sanitizeExtraEdo(value).toFloat()
    }

    fun currentProgram(): Int {
        return sanitizeMidiProgramNumber(program.toInt())
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(
                onClick = {
                    onSave(currentRange(), toneCount.toInt(), currentEdo(), currentProgram(), previewEnabled)
                }
            ) {
                Text("保存")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消")
            }
        },
        title = { Text("Extra 设置") },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                val sanitized = currentRange()
                val sanitizedEdo = currentEdo()
                Text("EDO：${sanitizedEdo}EDO", fontWeight = FontWeight.Bold)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedButton(
                        onClick = { setEdo(sanitizedEdo - 1) },
                        enabled = sanitizedEdo > MinExtraEdo,
                        modifier = Modifier.width(52.dp),
                        contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp)
                    ) {
                        Text("-", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    }
                    Slider(
                        value = sanitizedEdo.toFloat(),
                        onValueChange = { value ->
                            setEdo(value.roundToInt())
                        },
                        modifier = Modifier.weight(1f),
                        valueRange = MinExtraEdo.toFloat()..MaxExtraEdo.toFloat(),
                        steps = MaxExtraEdo - MinExtraEdo - 1
                    )
                    OutlinedButton(
                        onClick = { setEdo(sanitizedEdo + 1) },
                        enabled = sanitizedEdo < MaxExtraEdo,
                        modifier = Modifier.width(52.dp),
                        contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp)
                    ) {
                        Text("+", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    }
                }
                Text("出题音域：${rangeLabel(sanitized)} · ${extraRangeLabel(sanitizedEdo, sanitized)}")
                Text(
                    text = "Extra 会按当前 EDO 把八度等分；音域两端只允许选择 C，并使用 XenSynth 的 1-72 EDO 标尺模板绘制键盘刻度。",
                    fontSize = 14.sp,
                    color = Color(0xFF6E5D75)
                )
                Text("播放音数：${sanitizeChordToneCount(toneCount.toInt())}", fontWeight = FontWeight.Bold)
                Slider(
                    value = toneCount,
                    onValueChange = { value ->
                        toneCount = sanitizeChordToneCount(value.toInt()).toFloat()
                    },
                    valueRange = MinChordToneCount.toFloat()..MaxChordToneCount.toFloat(),
                    steps = MaxChordToneCount - MinChordToneCount - 1
                )
                Text("音色（MIDI program number）：${currentProgram()}", fontWeight = FontWeight.Bold)
                Slider(
                    value = program,
                    onValueChange = { value ->
                        program = sanitizeMidiProgramNumber(value.toInt()).toFloat()
                    },
                    valueRange = MinMidiProgramNumber.toFloat()..MaxMidiProgramNumber.toFloat(),
                    steps = MaxMidiProgramNumber - MinMidiProgramNumber - 1
                )
                SettingSwitchRow(
                    text = "选择按键时预听音高",
                    checked = previewEnabled,
                    onCheckedChange = { previewEnabled = it }
                )
                Text(
                    "音域两端：${noteLabel(sanitized.first)} / ${noteLabel(sanitized.last)}",
                    fontWeight = FontWeight.Bold
                )
                DiscreteIntRangeSlider(
                    value = octaveForCMidiNote(sanitized.first)..octaveForCMidiNote(sanitized.last),
                    onValueChange = { value ->
                        val nextRange = sanitizeExtraPlayableRange(
                            cMidiNoteForOctave(value.first)..cMidiNoteForOctave(value.last)
                        )
                        low = nextRange.first.toFloat()
                        high = nextRange.last.toFloat()
                    },
                    valueRange = MinExtraRangeOctave..MaxExtraRangeOctave,
                    steps = MaxExtraRangeOctave - MinExtraRangeOctave - 1
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            low = DefaultPlayableRange.first.toFloat()
                            high = DefaultPlayableRange.last.toFloat()
                            toneCount = DefaultChordToneCount.toFloat()
                            edo = DefaultExtraEdo.toFloat()
                            program = DefaultMidiProgramNumber.toFloat()
                            previewEnabled = DefaultKeyPitchPreviewEnabled
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("默认")
                    }
                    OutlinedButton(
                        onClick = {
                            low = LowestExtraPlayableMidiNote.toFloat()
                            high = HighestExtraPlayableMidiNote.toFloat()
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("全C范围")
                    }
                }
            }
        },
        containerColor = Color(0xFFF8F0F8),
        titleContentColor = Color(0xFF4E4156),
        textContentColor = Color(0xFF4E4156)
    )
}

@Composable
private fun OvertoneSettingsDialog(
    multiplierRange: IntRange,
    toneCount: Int,
    instrumentProgram: Int,
    keyPitchPreviewEnabled: Boolean,
    onDismiss: () -> Unit,
    onSave: (IntRange, Int, Int, Boolean) -> Unit
) {
    val initialRange = sanitizeOvertoneRange(multiplierRange)
    var low by remember(initialRange) { mutableFloatStateOf(initialRange.first.toFloat()) }
    var high by remember(initialRange) { mutableFloatStateOf(initialRange.last.toFloat()) }
    var selectedToneCount by remember(toneCount, initialRange) {
        mutableFloatStateOf(sanitizeOvertoneToneCount(toneCount, initialRange).toFloat())
    }
    var program by remember(instrumentProgram) {
        mutableFloatStateOf(sanitizeMidiProgramNumber(instrumentProgram).toFloat())
    }
    var previewEnabled by remember(keyPitchPreviewEnabled) { mutableStateOf(keyPitchPreviewEnabled) }

    fun currentRange(): IntRange {
        return sanitizeOvertoneRange(low.toInt()..high.toInt())
    }

    fun currentToneCount(): Int {
        return sanitizeOvertoneToneCount(selectedToneCount.toInt(), currentRange())
    }

    fun currentProgram(): Int {
        return sanitizeMidiProgramNumber(program.toInt())
    }

    fun applyRange(nextRange: IntRange) {
        val sanitized = sanitizeOvertoneRange(nextRange)
        low = sanitized.first.toFloat()
        high = sanitized.last.toFloat()
        selectedToneCount = sanitizeOvertoneToneCount(selectedToneCount.toInt(), sanitized).toFloat()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = { onSave(currentRange(), currentToneCount(), currentProgram(), previewEnabled) }) {
                Text("保存")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消")
            }
        },
        title = { Text("Overtones 设置") },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                val sanitized = currentRange()
                val toneMax = maxOvertoneToneCount(sanitized)
                Text("倍音范围：${overtoneRangeLabel(sanitized)}")
                Text(
                    text = "可选 1-31 内的正整数子区间；最高值至少为最低值的 2 倍，区间端点会包含在内。",
                    fontSize = 14.sp,
                    color = Color(0xFF6E5D75)
                )
                Text(
                    text = "音的个数：${currentToneCount()}（最多 $toneMax）",
                    fontWeight = FontWeight.Bold
                )
                if (toneMax > MinOvertoneToneCount) {
                    Slider(
                        value = currentToneCount().toFloat(),
                        onValueChange = { value ->
                            selectedToneCount = sanitizeOvertoneToneCount(value.toInt(), sanitized).toFloat()
                        },
                        valueRange = MinOvertoneToneCount.toFloat()..toneMax.toFloat(),
                        steps = (toneMax - MinOvertoneToneCount - 1).coerceAtLeast(0)
                    )
                }
                Text("音色（MIDI program number）：${currentProgram()}", fontWeight = FontWeight.Bold)
                Slider(
                    value = program,
                    onValueChange = { value ->
                        program = sanitizeMidiProgramNumber(value.toInt()).toFloat()
                    },
                    valueRange = MinMidiProgramNumber.toFloat()..MaxMidiProgramNumber.toFloat(),
                    steps = MaxMidiProgramNumber - MinMidiProgramNumber - 1
                )
                SettingSwitchRow(
                    text = "选择按键时预听音高",
                    checked = previewEnabled,
                    onCheckedChange = { previewEnabled = it }
                )
                Text(
                    "倍频两端：${sanitized.first}x / ${sanitized.last}x",
                    fontWeight = FontWeight.Bold
                )
                DiscreteIntRangeSlider(
                    value = sanitized,
                    onValueChange = ::applyRange,
                    valueRange = MinOvertoneMultiplier..MaxOvertoneMultiplier,
                    steps = MaxOvertoneMultiplier - MinOvertoneMultiplier - 1
                )
                Text(
                    text = "每局会按最高倍频限制随机基音，保证播放的最高频率不超过 C8。",
                    fontSize = 14.sp,
                    color = Color(0xFF6E5D75)
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            low = DefaultOvertoneRange.first.toFloat()
                            high = DefaultOvertoneRange.last.toFloat()
                            selectedToneCount = DefaultOvertoneToneCount.toFloat()
                            program = DefaultMidiProgramNumber.toFloat()
                            previewEnabled = DefaultKeyPitchPreviewEnabled
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("默认")
                    }
                    OutlinedButton(
                        onClick = {
                            applyRange(MinOvertoneMultiplier..MaxOvertoneMultiplier)
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("全范围")
                    }
                }
            }
        },
        containerColor = Color(0xFFF8F0F8),
        titleContentColor = Color(0xFF4E4156),
        textContentColor = Color(0xFF4E4156)
    )
}

@Composable
private fun SettingSwitchRow(
    text: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = text,
            modifier = Modifier.weight(1f),
            fontWeight = FontWeight.Bold
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange
        )
    }
}

private fun findMicrotonalStep(
    x: Float,
    offsetX: Float,
    stepWidth: Float,
    rulerStepRange: IntRange,
    touchStepRange: IntRange
): Int? {
    val localX = x - offsetX
    if (localX < 0f || stepWidth <= 0f) {
        return null
    }
    val step = rulerStepRange.first + floor(localX / stepWidth).toInt()
    return step.takeIf { it in touchStepRange }
}

private fun expandedMicrotonalRulerStepRange(stepRange: IntRange, edo: Int): IntRange {
    val edgePaddingSteps = kotlin.math.ceil(sanitizeExtraEdo(edo) / 12.0).toInt().coerceAtLeast(1)
    return (stepRange.first - edgePaddingSteps)..(stepRange.last + edgePaddingSteps)
}

private fun edoMarkerForStep(edo: Int, octaveStep: Int): Char {
    val pattern = ExtraEdoScaleMarks[sanitizeExtraEdo(edo)].orEmpty()
    if (pattern.isEmpty()) {
        return HiddenExtraEdoMark
    }
    return pattern.getOrNull(octaveStep) ?: HiddenExtraEdoMark
}

private fun shouldDrawMicrotonalStepLabel(edo: Int, marker: Char): Boolean {
    val normalizedEdo = sanitizeExtraEdo(edo)
    return marker == SecondaryExtraEdoMark ||
        (marker == TertiaryExtraEdoMark && normalizedEdo in ExtraEdoTertiaryStepLabelEdos)
}

private fun denseLineVisibilityRatio(
    stepIndex: Int,
    step: Double,
    minPitchSpacing: Double,
    isAnchor: Boolean = false
): Float {
    if (isAnchor) {
        return 1f
    }
    if (step <= DenseLineStepEpsilon || minPitchSpacing <= DenseLineStepEpsilon) {
        return 1f
    }
    val desiredStride = minPitchSpacing / step
    if (!desiredStride.isFinite() || desiredStride <= 1.0) {
        return 1f
    }

    val fineStride = floor(desiredStride).toInt().coerceAtLeast(1)
    val coarseStride = kotlin.math.ceil(desiredStride).toInt().coerceAtLeast(1)
    if (fineStride == coarseStride) {
        return if (positiveModulo(stepIndex, coarseStride) == 0) 1f else 0f
    }

    val fineWeight = smoothStep((coarseStride - desiredStride).coerceIn(0.0, 1.0)).toFloat()
    val coarseWeight = 1f - fineWeight
    var ratio = 0f
    if (positiveModulo(stepIndex, fineStride) == 0) {
        ratio = max(ratio, fineWeight)
    }
    if (positiveModulo(stepIndex, coarseStride) == 0) {
        ratio = max(ratio, coarseWeight)
    }
    return if (ratio >= DenseLineMinVisibleRatio) ratio else 0f
}

private fun smoothStep(value: Double): Double {
    return value * value * (3.0 - 2.0 * value)
}

private fun positiveModulo(value: Int, mod: Int): Int {
    return if (mod == 0) 0 else ((value % mod) + mod) % mod
}

private fun xenRulerHighlight(alpha: Int): Color {
    return Color(0xFFFFDE6F).copy(alpha = alpha.coerceIn(0, 255) / 255f)
}

private const val DefaultKeyPitchPreviewEnabled = false
private const val HiddenExtraEdoMark = 'N'
private const val SecondaryExtraEdoMark = '1'
private const val TertiaryExtraEdoMark = '2'
private const val MicrotonalKeyboardMinTickSpacingPx = 1.1f
private const val MicrotonalCTickHeightRatio = 0.84f
private const val MicrotonalCTickAlpha = 184
private const val DenseLineStepEpsilon = 0.0001
private const val DenseLineMinVisibleRatio = 0.02f
private const val ControlValueStateAlpha = 0.58f
private const val SelectedValueAlpha = 0.38f
private const val MicrotonalValueStateBandAlpha = 0.18f
private const val MicrotonalValueStateHaloAlpha = 0.26f
private const val MicrotonalValueStateLineMinAlpha = 0.72f
private const val MicrotonalValueStateLineMinWidthDp = 2.6f
private const val MicrotonalValueStateMinBandHeightRatio = 0.3f
private val ChordleBackground = Color(0xFF121213)
private val ChordleSurface = Color(0xFF1A1A1B)
private val ChordleText = Color(0xFFF8F8F8)
private val ChordleMuted = Color(0xFFB8B8BB)
private val WordleBorder = Color(0xFF3A3A3C)
private val ChordleGreen = Color(0xFF6AAA64)
private val ChordleYellow = Color(0xFFCCB757)
private val ChordleGray = Color(0xFF86888A)
private val ExtraCorrectBlue = Color(0xFF8EB8FF)
private val ExtraNearPink = Color(0xFFF0A9C8)
private val SelectedValuePurple = Color(0xFFCBB8FF)
private val ExtraEdoMarkRatios = mapOf(
    '0' to 1f,
    '1' to 0.8f,
    '2' to 0.6f,
    '3' to 0.4f,
    '4' to 0.2f,
    HiddenExtraEdoMark to 0f,
    'S' to 0f
)
private val ExtraEdoScaleMarks = mapOf(
    1 to "0N",
    2 to "01",
    3 to "011",
    4 to "0111",
    5 to "01111",
    6 to "011111",
    7 to "0111111",
    8 to "02121212",
    9 to "022122122",
    10 to "0212121212",
    11 to "02121121121",
    12 to "021211212121",
    13 to "0212112121121",
    14 to "02121212121212",
    15 to "022122122122122",
    16 to "0323132313231323",
    17 to "02212211221221221",
    18 to "021212121212121212",
    19 to "0221221212212212212",
    20 to "03231331132313313231",
    21 to "022122122122122122122",
    22 to "0323132311323132313231",
    23 to "03323323332331332332333",
    24 to "032313231313231323132313",
    25 to "0332332332323321323323323",
    26 to "03231323133132313231323133",
    27 to "033332333322333313333233332",
    28 to "0323132313231323132313231323",
    29 to "03333233332323333133332333323",
    30 to "033332333233323333133323332333",
    31 to "0333323333233233331333323333233",
    32 to "03231323132313231323132313231323",
    33 to "033332333323332333313333233332333",
    34 to "0323231323231313232313232313232313",
    35 to "03333233332333323333133332333323333",
    36 to "033233233233133133233233233133233133",
    37 to "0332331332331133233133233133233133233",
    38 to "03232313232313231323231323231323231323",
    39 to "033333323333332323333331333333233333323",
    40 to "0332331332331333313323313323313323313333",
    41 to "03333332333333233233333313333332333333233",
    42 to "033323331333233311333233313332333133323331",
    43 to "0333333233333323332333333133333323333332333",
    44 to "03332333133323331313332333133323331333233313",
    45 to "033333323333332333323333331333333233333323333",
    46 to "0333233313332333133133323331333233313332333133",
    47 to "03333332333333233333233333313333332333333233333",
    48 to "033323331333233313331333233313332333133323331333",
    49 to "0332332331332332331313323323313323323313323323313",
    50 to "03332333133323331333313332333133323331333233313333",
    51 to "033233233133233233133133233233133233233133233233133",
    52 to "0333233313332333133333133323331333233313332333133333",
    53 to "03333333323333333323332333333331333333332333333332333",
    54 to "033323331333233313333331333233313332333133323331333333",
    55 to "0332332331332332331333313323323313323323313323323313333",
    56 to "03333233331333323333133133332333313333233331333323333133",
    57 to "033233233133233233133233133233233133233233133233233133233",
    58 to "0333323333133332333313331333323333133332333313333233331333",
    59 to "04424344144243441442434414424434244144342441443424414434244",
    60 to "044443444424444344442444424444344441444434444244443444424444",
    61 to "0333333333323333333333233233333333331333333333323333333333233",
    62 to "04343434342434343434243434243434343414343434342434343434243434",
    63 to "033333333332333333333323332333333333313333333333233333333332333",
    64 to "0434243414342434143424341434243414342434143424341434243414342434",
    65 to "03333333333233333333332333323333333333133333333332333333333323333",
    66 to "043434343424343434342434343424343434143434343424343434342434343424",
    67 to "0333333333323333333333233333233333333331333333333323333333333233333",
    68 to "04342434243414342434243414341434243424341434243424341434243424341434",
    69 to "033333333332333333333323333332333333333313333333333233333333332333333",
    70 to "0444443444442444443444442444424444434444414444434444424444434444424444",
    71 to "03333333333332333333333333233233333333333313333333333332333333333333233",
    72 to "044344244344144344244344144344144344244344144344244344144344244344144344"
)
private val ExtraEdoTertiaryStepLabelEdos = ExtraEdoScaleMarks
    .filter { (edo, marks) ->
        edo >= 20 && marks.count { it == SecondaryExtraEdoMark } <= 3
    }
    .keys
