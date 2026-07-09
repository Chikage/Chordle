package icu.ringona.chordle

import android.graphics.Paint as AndroidPaint
import android.graphics.Typeface
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
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
import kotlin.math.min

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
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val game = remember { ChordleGame(ChordPuzzle.random(3)) }
    var showHelp by remember { mutableStateOf(false) }
    var audioStatus by remember { mutableStateOf<AudioStatus>(AudioStatus.Loading) }

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
                onNewPuzzle = {
                    NativeAudioEngine.allSoundOff()
                    game.newPuzzle(3)
                    if (audioStatus == AudioStatus.Ready) {
                        scope.launch { playNotes(game.puzzle.notes, durationMillis = 1400) }
                    }
                }
            )

            GameStatusLine(
                audioStatus = audioStatus,
                toneCount = game.columns,
                attempt = game.currentRow + 1,
                maxAttempts = game.maxAttempts
            )

            BoardArea(
                game = game,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            )

            InputPanel(
                game = game,
                audioReady = audioStatus == AudioStatus.Ready,
                onPlayChord = {
                    if (audioStatus == AudioStatus.Ready) {
                        scope.launch { playNotes(game.puzzle.notes, durationMillis = 1600) }
                    } else {
                        game.clearMessage()
                    }
                },
                onPreviewNote = { note ->
                    game.selectNote(note)
                    if (audioStatus == AudioStatus.Ready) {
                        scope.launch { playNotes(listOf(note), velocity = 92, durationMillis = 520) }
                    }
                }
            )
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
        HelpDialog(onDismiss = { showHelp = false })
    }
}

@Composable
private fun ChordleHeader(
    onHelp: () -> Unit,
    onNewPuzzle: () -> Unit
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
            onClick = onNewPuzzle,
            modifier = Modifier.align(Alignment.CenterEnd),
            contentPadding = PaddingValues(horizontal = 12.dp)
        ) {
            Text("↻", fontSize = 24.sp, color = ChordleMuted, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun GameStatusLine(
    audioStatus: AudioStatus,
    toneCount: Int,
    attempt: Int,
    maxAttempts: Int
) {
    val statusText = when (audioStatus) {
        AudioStatus.Loading -> "音色加载中"
        AudioStatus.Ready -> "可播放"
        is AudioStatus.Error -> audioStatus.message
    }
    val statusColor = when (audioStatus) {
        AudioStatus.Ready -> ChordleGreen
        AudioStatus.Loading -> ChordleYellow
        is AudioStatus.Error -> Color(0xFFE57373)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(ChordleSurface)
            .padding(horizontal = 18.dp, vertical = 7.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "$toneCount 音和弦",
            color = ChordleMuted,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = statusText,
            color = statusColor,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = "$attempt/$maxAttempts",
            color = ChordleMuted,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun BoardArea(
    game: ChordleGame,
    modifier: Modifier = Modifier
) {
    BoxWithConstraints(
        modifier = modifier.padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        val gap = 6.dp
        val tileSize = remember(maxWidth, maxHeight, game.columns) {
            val horizontal = (maxWidth - gap * (game.columns - 1)) / game.columns
            val vertical = (maxHeight - gap * (game.maxAttempts - 1)) / game.maxAttempts
            minOf(64.dp, horizontal, vertical)
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(gap),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            repeat(game.maxAttempts) { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    repeat(game.columns) { column ->
                        ChordTile(
                            cell = game.cell(row, column),
                            active = game.status == GameStatus.Playing &&
                                row == game.currentRow &&
                                column == game.currentColumn,
                            size = tileSize
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
    size: Dp
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
            .border(width = 2.dp, color = border),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = cell.note?.let { noteLabel(it) }.orEmpty(),
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
                    drawIntoCanvas { canvas ->
                        labelPaint.color = android.graphics.Color.rgb(238, 238, 238)
                        labelPaint.textSize = 9.sp.toPx()
                        canvas.nativeCanvas.drawText(
                            noteLabel(note),
                            x + blackWidth / 2f,
                            blackHeight - 10.dp.toPx(),
                            labelPaint
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HelpDialog(onDismiss: () -> Unit) {
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
                Text("会随机播放一个 3 音和弦。")
                Text("从低到高选择钢琴键，逐个确认音符，填满一行后提交。")
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

private suspend fun playNotes(
    notes: List<Int>,
    velocity: Int = 104,
    durationMillis: Long = 1200
) {
    withContext(Dispatchers.Default) {
        NativeAudioEngine.allSoundOff()
        val noteIds = notes.mapNotNull { note ->
            NativeAudioEngine.noteOn(
                key = note,
                velocity = velocity,
                cents = 0f,
                channel = 0,
                program = 0,
                bankMsb = 0,
                bankLsb = 0
            )
        }
        delay(durationMillis)
        noteIds.forEach { NativeAudioEngine.noteOff(it) }
    }
}

private val PianoRange = 36..84
private val ChordleBackground = Color(0xFF121213)
private val ChordleSurface = Color(0xFF1A1A1B)
private val ChordleText = Color(0xFFF8F8F8)
private val ChordleMuted = Color(0xFFB8B8BB)
private val WordleBorder = Color(0xFF3A3A3C)
private val ChordleGreen = Color(0xFF6AAA64)
private val ChordleYellow = Color(0xFFCCB757)
private val ChordleGray = Color(0xFF86888A)
