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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import icu.ringona.chordle.audio.NativeAudioEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.min
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
    var overtoneRange by remember { mutableStateOf(settings.loadOvertoneRange()) }
    var overtoneToneCount by remember { mutableStateOf(settings.loadOvertoneToneCount()) }
    var instrumentProgram by remember { mutableStateOf(settings.loadInstrumentProgram()) }
    var keyPitchPreviewEnabled by remember { mutableStateOf(settings.loadKeyPitchPreviewEnabled()) }
    val game = remember(mode) {
        ChordleGame(
            when (mode) {
                ChordleMode.Overtones -> ChordPuzzle.randomOvertones(overtoneToneCount, overtoneRange)
                ChordleMode.Normal,
                ChordleMode.Extra -> ChordPuzzle.random(chordToneCount, playableRange)
            }
        )
    }
    var showHelp by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var audioStatus by remember { mutableStateOf<AudioStatus>(AudioStatus.Loading) }
    val statusDetail = when (mode) {
        ChordleMode.Overtones -> "${game.columns} 音 · ${overtoneRangeLabel(overtoneRange)}"
        ChordleMode.Normal,
        ChordleMode.Extra -> "${game.columns} 音 · ${rangeLabel(playableRange)}"
    }

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
                        ChordleMode.Normal,
                        ChordleMode.Extra -> {
                            game.newPuzzle(chordToneCount, playableRange)
                        }
                    }
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

            BoardArea(
                game = game,
                audioReady = audioStatus == AudioStatus.Ready,
                onPlayRow = { row ->
                    scope.launch {
                        playTones(
                            playbackTonesForMode(mode, game.puzzle, game.rowNotes(row)),
                            program = instrumentProgram,
                            durationMillis = 1200
                        )
                    }
                },
                onPlayValue = { value ->
                    scope.launch {
                        playTones(
                            playbackTonesForMode(mode, game.puzzle, listOf(value)),
                            velocity = 92,
                            program = instrumentProgram,
                            durationMillis = 520
                        )
                    }
                },
                valueLabel = valueLabelForMode(mode),
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            )

            if (mode == ChordleMode.Overtones) {
                OvertoneInputPanel(
                    game = game,
                    overtoneRange = overtoneRange,
                    audioReady = audioStatus == AudioStatus.Ready,
                    onPlayChord = {
                        if (audioStatus == AudioStatus.Ready) {
                            scope.launch {
                                playTones(
                                    playbackTonesForMode(mode, game.puzzle, game.puzzle.notes),
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
                InputPanel(
                    game = game,
                    audioReady = audioStatus == AudioStatus.Ready,
                    onPlayChord = {
                        if (audioStatus == AudioStatus.Ready) {
                            scope.launch {
                                playNotes(game.puzzle.notes, program = instrumentProgram, durationMillis = 1600)
                            }
                        } else {
                            game.clearMessage()
                        }
                    },
                    onPreviewNote = { note ->
                        game.selectNote(note)
                        if (keyPitchPreviewEnabled && audioStatus == AudioStatus.Ready) {
                            scope.launch {
                                playNotes(
                                    listOf(note),
                                    velocity = 92,
                                    program = instrumentProgram,
                                    durationMillis = 520
                                )
                            }
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
    onPlayRow: (Int) -> Unit,
    onPlayValue: (Int) -> Unit,
    valueLabel: (Int) -> String,
    modifier: Modifier = Modifier
) {
    BoxWithConstraints(
        modifier = modifier.padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
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
                    Row(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalArrangement = Arrangement.spacedBy(gap),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        repeat(game.columns) { column ->
                            ChordTile(
                                cell = game.cell(row, column),
                                active = game.status == GameStatus.Playing &&
                                    row == game.currentRow &&
                                    column == game.currentColumn,
                                size = tileSize,
                                valueLabel = valueLabel,
                                onClick = game.cell(row, column).note
                                    ?.takeIf { audioReady }
                                    ?.let { value -> { onPlayValue(value) } }
                            )
                        }
                    }
                    TextButton(
                        onClick = { onPlayRow(row) },
                        enabled = audioReady && game.rowNotes(row).isNotEmpty(),
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .size(34.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Text(
                            text = "▶",
                            color = if (audioReady && game.rowNotes(row).isNotEmpty()) ChordleMuted else WordleBorder,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChordTile(
    cell: GuessCell,
    active: Boolean,
    size: Dp,
    valueLabel: (Int) -> String,
    onClick: (() -> Unit)?
) {
    val background = when (cell.state) {
        TileState.Correct -> ChordleGreen
        TileState.Present -> ChordleYellow
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
        modifier = Modifier
            .size(size)
            .background(background)
            .border(width = 2.dp, color = border)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = cell.note?.let(valueLabel).orEmpty(),
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Clip
        )
    }
}

@Composable
private fun InputPanel(
    game: ChordleGame,
    audioReady: Boolean,
    onPlayChord: () -> Unit,
    onPreviewNote: (Int) -> Unit
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
                    text = game.selectedNote?.let { "选中 ${noteLabel(it)}" } ?: "未选音",
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
                onClick = { game.confirmSelectedNote() },
                enabled = game.status == GameStatus.Playing,
                modifier = Modifier.weight(1f)
            ) {
                Text("确认此音", maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            OutlinedButton(
                onClick = { game.deleteLast() },
                enabled = game.status == GameStatus.Playing && game.currentColumn > 0,
                modifier = Modifier.weight(0.72f)
            ) {
                Text("删除", maxLines = 1)
            }
            Button(
                onClick = { game.submitGuess() },
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

        PianoKeyboard(
            selectedNote = game.selectedNote,
            onNotePressed = onPreviewNote,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun OvertoneInputPanel(
    game: ChordleGame,
    overtoneRange: IntRange,
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
                enabled = game.status == GameStatus.Playing && game.currentColumn > 0,
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
            onMultiplierPressed = onPreviewMultiplier,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun OvertoneNumberPad(
    multiplierRange: IntRange,
    selectedMultiplier: Int?,
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
                    Button(
                        onClick = { onMultiplierPressed(multiplier) },
                        modifier = Modifier
                            .weight(1f)
                            .height(42.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (selected) ChordleGreen else ChordleSurface,
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
    selectedNote: Int?,
    onNotePressed: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val whiteNotes = remember { PianoRange.filterNot(::isBlackKey) }
    val blackNotes = remember { PianoRange.filter(::isBlackKey) }
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
                    val fill = if (note == selectedNote) Color(0xFFA9DCA2) else Color(0xFFE9EAEC)
                    drawRoundRect(
                        color = fill,
                        topLeft = Offset(x + keyGap / 2f, 0f),
                        size = Size(whiteWidthPx - keyGap, size.height),
                        cornerRadius = corner
                    )
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
                    val fill = if (note == selectedNote) Color(0xFF6AAA64) else Color(0xFF151518)
                    drawRoundRect(
                        color = fill,
                        topLeft = Offset(x, 0f),
                        size = Size(blackWidth, blackHeight),
                        cornerRadius = corner
                    )
                }
            }
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

private fun valueLabelForMode(mode: ChordleMode): (Int) -> String {
    return when (mode) {
        ChordleMode.Overtones -> { value -> value.toString() }
        ChordleMode.Normal,
        ChordleMode.Extra -> ::noteLabel
    }
}

private fun playbackTonesForMode(
    mode: ChordleMode,
    puzzle: ChordPuzzle,
    values: List<Int>
): List<PlaybackTone> {
    return when (mode) {
        ChordleMode.Overtones -> overtonePlaybackTones(puzzle, values)
        ChordleMode.Normal,
        ChordleMode.Extra -> values.map { PlaybackTone(key = it) }
    }
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
                DiscreteIntRangeSlider(
                    value = sanitized,
                    onValueChange = { value ->
                        val nextRange = sanitizePlayableRange(value)
                        low = nextRange.first.toFloat()
                        high = nextRange.last.toFloat()
                    },
                    valueRange = LowestPlayableMidiNote..HighestPlayableMidiNote,
                    steps = HighestPlayableMidiNote - LowestPlayableMidiNote - 1
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

private val PianoRange = FullPianoRange
private const val DefaultKeyPitchPreviewEnabled = false
private val ChordleBackground = Color(0xFF121213)
private val ChordleSurface = Color(0xFF1A1A1B)
private val ChordleText = Color(0xFFF8F8F8)
private val ChordleMuted = Color(0xFFB8B8BB)
private val WordleBorder = Color(0xFF3A3A3C)
private val ChordleGreen = Color(0xFF6AAA64)
private val ChordleYellow = Color(0xFFCCB757)
private val ChordleGray = Color(0xFF86888A)
