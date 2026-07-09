package icu.ringona.chordle

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.log2
import kotlin.math.pow
import kotlin.random.Random

private val pitchNames = listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
private val extraPitchNames = mapOf(
    '1' to "C",
    '2' to "D",
    '3' to "E",
    '4' to "F",
    '5' to "G",
    '6' to "A",
    '7' to "B"
)
private val simpleExtraPitchNameTables = mapOf(
    7 to listOf("C", "D", "E", "F", "G", "A", "B"),
    14 to listOf("C", "^C", "D", "^D", "E", "^E", "F", "^F", "G", "^G", "A", "^A", "B", "^B"),
    21 to listOf(
        "C", "^C", "vD",
        "D", "^D", "vE",
        "E", "^E", "vF",
        "F", "^F", "vG",
        "G", "^G", "vA",
        "A", "^A", "vB",
        "B", "^B", "vC"
    ),
    28 to listOf(
        "C", "^C", "^^C", "vD",
        "D", "^D", "^^D", "vE",
        "E", "^E", "^^E", "vF",
        "F", "^F", "^^F", "vG",
        "G", "^G", "^^G", "vA",
        "A", "^A", "^^A", "vB",
        "B", "^B", "^^B", "vC"
    ),
    35 to listOf(
        "C", "^C", "^^C", "vvD", "vD",
        "D", "^D", "^^D", "vvE", "vE",
        "E", "^E", "^^E", "vvF", "vF",
        "F", "^F", "^^F", "vvG", "vG",
        "G", "^G", "^^G", "vvA", "vA",
        "A", "^A", "^^A", "vvB", "vB",
        "B", "^B", "^^B", "vvC", "vC"
    )
)
private val extraPitchNameTableCache = mutableMapOf<Int, List<ExtraPitchName?>>()
private val whiteMidiPitchClasses = setOf(0, 2, 4, 5, 7, 9, 11)
private const val DuplicateRowNoteMessage = "这一行不能填写两个相同的音"

const val LowestPlayableMidiNote = 21
const val HighestPlayableMidiNote = 108
const val MinimumPlayableRangeSemitones = 12
const val MinChordToneCount = 1
const val MaxChordToneCount = 10
const val DefaultChordToneCount = 3
const val MinExtraEdo = 1
const val MaxExtraEdo = 72
const val DefaultExtraEdo = 24
const val ExtraPitchToleranceCents = 50.0
const val LowestExtraPlayableMidiNote = 24
const val HighestExtraPlayableMidiNote = 108
const val MinExtraRangeOctave = 1
const val MaxExtraRangeOctave = 8
const val MinMidiProgramNumber = 0
const val MaxMidiProgramNumber = 127
const val DefaultMidiProgramNumber = 0
const val MinOvertoneMultiplier = 1
const val MaxOvertoneMultiplier = 31
const val MinOvertoneToneCount = 2
const val MaxOvertoneToneCount = 10
const val DefaultOvertoneToneCount = 4
val DefaultPlayableRange = 48..72
val FullPianoRange = LowestPlayableMidiNote..HighestPlayableMidiNote
val PlayableWhiteKeyMidiNotes = FullPianoRange.filter(::isWhiteMidiKey)
val DefaultOvertoneRange = 8..16

enum class TileState {
    Empty,
    Input,
    Carried,
    Correct,
    ExtraCorrect,
    Present,
    ExtraNear,
    Absent
}

enum class GameStatus {
    Playing,
    Won,
    Lost
}

data class GuessCell(
    val note: Int? = null,
    val state: TileState = TileState.Empty
)

data class ChordPuzzle(
    val notes: List<Int>,
    val label: String,
    val answerLabel: String = notes.joinToString("  ") { noteLabel(it) },
    val baseMidiNote: Int? = null
) {
    companion object {
        fun random(noteCount: Int = DefaultChordToneCount, noteRange: IntRange = DefaultPlayableRange): ChordPuzzle {
            val playableRange = sanitizePlayableRange(noteRange)
            val sanitizedCount = sanitizeChordToneCount(noteCount)
            val availableNotes = playableRange.toList()
            val notes = availableNotes
                .shuffled()
                .take(sanitizedCount.coerceAtMost(availableNotes.size))
                .sorted()
            val label = if (notes.size == 1) {
                "${noteLabel(notes.first())} single"
            } else {
                "${notes.size}-tone"
            }
            return ChordPuzzle(notes = notes, label = label)
        }

        fun randomExtra(
            noteCount: Int = DefaultChordToneCount,
            noteRange: IntRange = DefaultPlayableRange,
            edo: Int = DefaultExtraEdo
        ): ChordPuzzle {
            val normalizedEdo = sanitizeExtraEdo(edo)
            val playableRange = sanitizeExtraPlayableRange(noteRange)
            val sanitizedCount = sanitizeChordToneCount(noteCount)
            val availableSteps = extraStepRangeForMidiRange(normalizedEdo, playableRange).toList()
            val notes = availableSteps
                .shuffled()
                .take(sanitizedCount.coerceAtMost(availableSteps.size))
                .sorted()
            return ChordPuzzle(
                notes = notes,
                label = "${normalizedEdo}EDO",
                answerLabel = notes.joinToString("  ") { extraStepLabel(it, normalizedEdo) }
            )
        }

        fun randomOvertones(
            toneCount: Int = DefaultOvertoneToneCount,
            multiplierRange: IntRange = DefaultOvertoneRange
        ): ChordPuzzle {
            val overtoneRange = sanitizeOvertoneRange(multiplierRange)
            val sanitizedCount = sanitizeOvertoneToneCount(toneCount, overtoneRange)
            val multipliers = overtoneRange.toList()
                .shuffled()
                .take(sanitizedCount)
                .sorted()
            val baseMidiNote = randomOvertoneBaseMidiNote(overtoneRange)
            return ChordPuzzle(
                notes = multipliers,
                label = "${noteLabel(baseMidiNote)} · ${overtoneRange.first}-${overtoneRange.last}x",
                answerLabel = multipliers.joinToString("  "),
                baseMidiNote = baseMidiNote
            )
        }
    }
}

class ChordleGame(
    initialPuzzle: ChordPuzzle = ChordPuzzle.random(DefaultChordToneCount),
    val maxAttempts: Int = 6
) {
    var puzzle by mutableStateOf(initialPuzzle)
        private set

    var currentRow by mutableIntStateOf(0)
        private set

    var currentColumn by mutableIntStateOf(0)
        private set

    var selectedNote by mutableStateOf<Int?>(null)
        private set

    var status by mutableStateOf(GameStatus.Playing)
        private set

    var message by mutableStateOf<String?>(null)
        private set

    val cells = mutableStateListOf<GuessCell>()

    val columns: Int
        get() = puzzle.notes.size

    val answerText: String
        get() = puzzle.answerLabel

    init {
        rebuildCells()
    }

    fun selectNote(note: Int) {
        selectedNote = note
    }

    fun confirmSelectedNote() {
        confirmSelectedValue(
            missingSelectionMessage = "先在钢琴上选择一个音"
        )
    }

    fun confirmSelectedValue(
        missingSelectionMessage: String
    ) {
        if (status != GameStatus.Playing) {
            return
        }
        val note = selectedNote ?: run {
            message = missingSelectionMessage
            return
        }
        val column = nextOpenColumn(currentColumn)
        if (column >= columns) {
            message = "这一行已经填满"
            return
        }
        if (rejectDuplicateInCurrentRow(note, column)) {
            return
        }
        setCell(currentRow, column, GuessCell(note, TileState.Input))
        currentColumn = nextOpenColumn(column + 1)
    }

    fun deleteLast() {
        val column = previousInputColumn() ?: return
        setCell(currentRow, column, GuessCell())
        currentColumn = nextOpenColumn(0)
    }

    fun canDeleteLast(): Boolean {
        return previousInputColumn() != null
    }

    fun canSortRow(row: Int): Boolean {
        if (status != GameStatus.Playing || row != currentRow || row !in 0 until maxAttempts) {
            return false
        }
        return rowNotes(row).size > 1
    }

    fun sortRowBy(row: Int, sortKey: (Int) -> Int = { it }): Boolean {
        if (!canSortRow(row)) {
            return false
        }
        val sortedCells = (0 until columns)
            .map { column -> cell(row, column) }
            .filter { cell -> cell.note != null }
            .sortedWith(
                compareBy<GuessCell> { cell -> sortKey(cell.note ?: Int.MIN_VALUE) }
                    .thenBy { cell -> cell.note ?: Int.MIN_VALUE }
            )

        repeat(columns) { column ->
            setCell(row, column, sortedCells.getOrNull(column) ?: GuessCell())
        }
        currentColumn = nextOpenColumn(0)
        message = null
        return true
    }

    fun canCarryCorrectCellFromPreviousRow(sourceRow: Int, column: Int): Boolean {
        if (status != GameStatus.Playing || currentRow <= 0 || sourceRow != currentRow - 1 || column !in 0 until columns) {
            return false
        }
        val source = cell(sourceRow, column)
        val note = source.note ?: return false
        return source.state == TileState.Correct && !rowContainsNote(currentRow, note, exceptColumn = column)
    }

    fun canDragPresentCellFromPreviousRow(sourceRow: Int, column: Int): Boolean {
        if (status != GameStatus.Playing || currentRow <= 0 || sourceRow != currentRow - 1 || column !in 0 until columns) {
            return false
        }
        val source = cell(sourceRow, column)
        return source.state == TileState.Present && source.note != null
    }

    fun canPlacePresentCellFromPreviousRow(sourceRow: Int, sourceColumn: Int, targetColumn: Int): Boolean {
        return targetColumn in 0 until columns &&
            sourceColumn != targetColumn &&
            canDragPresentCellFromPreviousRow(sourceRow, sourceColumn) &&
            cell(sourceRow, sourceColumn).note?.let { note ->
                !rowContainsNote(currentRow, note, exceptColumn = targetColumn)
            } == true
    }

    fun carryCorrectCellFromPreviousRow(column: Int): Boolean {
        val sourceRow = currentRow - 1
        if (status != GameStatus.Playing || currentRow <= 0 || column !in 0 until columns) {
            return false
        }
        val source = cell(sourceRow, column)
        val note = source.note ?: return false
        if (source.state != TileState.Correct) {
            return false
        }
        if (rejectDuplicateInCurrentRow(note, column)) {
            return false
        }
        setCell(currentRow, column, GuessCell(note, TileState.Carried))
        currentColumn = nextOpenColumn(currentColumn)
        message = null
        return true
    }

    fun placePresentCellFromPreviousRow(sourceColumn: Int, targetColumn: Int): Boolean {
        val sourceRow = currentRow - 1
        if (
            targetColumn !in 0 until columns ||
            sourceColumn == targetColumn ||
            !canDragPresentCellFromPreviousRow(sourceRow, sourceColumn)
        ) {
            return false
        }
        val note = cell(sourceRow, sourceColumn).note ?: return false
        if (rejectDuplicateInCurrentRow(note, targetColumn)) {
            return false
        }
        setCell(currentRow, targetColumn, GuessCell(note, TileState.Input))
        currentColumn = nextOpenColumn(currentColumn)
        message = null
        return true
    }

    private fun previousInputColumn(): Int? {
        if (status != GameStatus.Playing) {
            return null
        }
        for (column in columns - 1 downTo 0) {
            if (cell(currentRow, column).state == TileState.Input) {
                return column
            }
        }
        return null
    }

    private fun nextOpenColumn(startColumn: Int): Int {
        var column = startColumn.coerceIn(0, columns)
        while (column < columns && cell(currentRow, column).note != null) {
            column += 1
        }
        return column
    }

    private fun rowContainsNote(row: Int, note: Int, exceptColumn: Int? = null): Boolean {
        return (0 until columns).any { column ->
            column != exceptColumn && cell(row, column).note == note
        }
    }

    private fun rejectDuplicateInCurrentRow(note: Int, exceptColumn: Int? = null): Boolean {
        if (!rowContainsNote(currentRow, note, exceptColumn)) {
            return false
        }
        message = DuplicateRowNoteMessage
        return true
    }

    fun submitGuess(itemName: String = "音") {
        submitGuessWithResult(
            itemName = itemName,
            resultForGuess = { guess -> evaluateGuess(guess, puzzle.notes) },
            isWinningResult = { result -> result.all { it == TileState.Correct } }
        )
    }

    fun submitExtraGuess(edo: Int) {
        submitGuessWithResult(
            itemName = "音",
            resultForGuess = { guess -> evaluateExtraGuess(guess, puzzle.notes, edo) },
            isWinningResult = { result -> result.all { it == TileState.Correct } }
        )
    }

    private fun submitGuessWithResult(
        itemName: String,
        resultForGuess: (List<Int>) -> List<TileState>,
        isWinningResult: (List<TileState>) -> Boolean
    ) {
        if (status != GameStatus.Playing) {
            return
        }
        val guess = rowNotes(currentRow)
        if (guess.size != columns) {
            message = "请先确认全部 ${columns} 个$itemName"
            return
        }
        val result = resultForGuess(guess)
        result.forEachIndexed { column, state ->
            setCell(currentRow, column, GuessCell(guess[column], state))
        }

        if (isWinningResult(result)) {
            status = GameStatus.Won
            message = "答对了：$answerText"
            return
        }

        if (currentRow == maxAttempts - 1) {
            status = GameStatus.Lost
            message = "答案是：$answerText"
            return
        }

        currentRow += 1
        currentColumn = 0
        selectedNote = null
    }

    fun newPuzzle(noteCount: Int = columns, noteRange: IntRange = DefaultPlayableRange) {
        newPuzzle(ChordPuzzle.random(sanitizeChordToneCount(noteCount), noteRange))
    }

    fun newPuzzle(nextPuzzle: ChordPuzzle) {
        puzzle = nextPuzzle
        currentRow = 0
        currentColumn = 0
        selectedNote = null
        status = GameStatus.Playing
        message = null
        rebuildCells()
    }

    fun clearMessage() {
        message = null
    }

    fun cell(row: Int, column: Int): GuessCell {
        return cells[row * columns + column]
    }

    fun rowIsFull(row: Int): Boolean {
        return rowNotes(row).size == columns
    }

    fun cellIsJudged(row: Int, column: Int): Boolean {
        return when (cell(row, column).state) {
            TileState.Correct,
            TileState.ExtraCorrect,
            TileState.Present,
            TileState.ExtraNear,
            TileState.Absent -> true
            TileState.Empty,
            TileState.Carried,
            TileState.Input -> false
        }
    }

    fun rowIsJudged(row: Int): Boolean {
        return (0 until columns).all { column -> cellIsJudged(row, column) }
    }

    fun rowNotes(row: Int): List<Int> {
        return (0 until columns).mapNotNull { column -> cell(row, column).note }
    }

    private fun setCell(row: Int, column: Int, cell: GuessCell) {
        cells[row * columns + column] = cell
    }

    private fun rebuildCells() {
        cells.clear()
        repeat(maxAttempts * columns) {
            cells += GuessCell()
        }
    }
}

fun evaluateGuess(guess: List<Int>, answer: List<Int>): List<TileState> {
    val result = MutableList(guess.size) { TileState.Absent }
    val remaining = mutableMapOf<Int, Int>()
    answer.forEach { note ->
        remaining[note] = (remaining[note] ?: 0) + 1
    }

    guess.forEachIndexed { index, note ->
        if (answer.getOrNull(index) == note) {
            result[index] = TileState.Correct
            remaining[note] = (remaining[note] ?: 0) - 1
        }
    }

    guess.forEachIndexed { index, note ->
        if (result[index] == TileState.Correct) {
            return@forEachIndexed
        }
        val count = remaining[note] ?: 0
        if (count > 0) {
            result[index] = TileState.Present
            remaining[note] = count - 1
        }
    }
    return result
}

fun evaluateExtraGuess(guess: List<Int>, answer: List<Int>, edo: Int): List<TileState> {
    val normalizedEdo = sanitizeExtraEdo(edo)
    return guess.mapIndexed { index, note ->
        val answerAtPosition = answer.getOrNull(index)
        when {
            answerAtPosition != null && note == answerAtPosition -> {
                TileState.Correct
            }
            answer.contains(note) -> {
                TileState.Present
            }
            answerAtPosition != null && extraStepCentsDistance(note, answerAtPosition, normalizedEdo) <= ExtraPitchToleranceCents -> {
                TileState.ExtraCorrect
            }
            answer.any { answerNote -> extraStepCentsDistance(note, answerNote, normalizedEdo) <= ExtraPitchToleranceCents } -> {
                TileState.ExtraNear
            }
            else -> TileState.Absent
        }
    }
}

fun extraStepCentsDistance(firstStep: Int, secondStep: Int, edo: Int): Double {
    val normalizedEdo = sanitizeExtraEdo(edo)
    return abs(firstStep - secondStep) * 1200.0 / normalizedEdo
}

fun noteLabel(midiNote: Int): String {
    val pitch = pitchNames[midiNote.floorMod(12)]
    val octave = midiNote / 12 - 1
    return "$pitch$octave"
}

fun isWhiteMidiKey(midiNote: Int): Boolean {
    return midiNote.floorMod(12) in whiteMidiPitchClasses
}

fun rangeLabel(range: IntRange): String {
    val sanitized = sanitizePlayableRange(range)
    return "${noteLabel(sanitized.first)}-${noteLabel(sanitized.last)}"
}

fun sanitizePlayableRange(range: IntRange): IntRange {
    var low = nextWhiteKeyAtOrAbove(
        range.first.coerceIn(LowestPlayableMidiNote, HighestPlayableMidiNote - MinimumPlayableRangeSemitones)
    )
    var high = previousWhiteKeyAtOrBelow(
        range.last.coerceIn(LowestPlayableMidiNote + MinimumPlayableRangeSemitones, HighestPlayableMidiNote)
    )
    if (high - low < MinimumPlayableRangeSemitones) {
        high = nextWhiteKeyAtOrAbove(low + MinimumPlayableRangeSemitones)
            .coerceAtMost(HighestPlayableMidiNote)
        low = previousWhiteKeyAtOrBelow(high - MinimumPlayableRangeSemitones)
            .coerceAtLeast(LowestPlayableMidiNote)
    }
    return low..high
}

fun sanitizeChordToneCount(noteCount: Int): Int {
    return noteCount.coerceIn(MinChordToneCount, MaxChordToneCount)
}

fun sanitizeExtraEdo(edo: Int): Int {
    return edo.coerceIn(MinExtraEdo, MaxExtraEdo)
}

fun sanitizeExtraPlayableRange(range: IntRange): IntRange {
    val playableRange = sanitizePlayableRange(range)
    var low = nextCAtOrAbove(playableRange.first)
        .coerceIn(LowestExtraPlayableMidiNote, HighestExtraPlayableMidiNote - MinimumPlayableRangeSemitones)
    var high = previousCAtOrBelow(playableRange.last)
        .coerceIn(LowestExtraPlayableMidiNote + MinimumPlayableRangeSemitones, HighestExtraPlayableMidiNote)
    if (high - low < MinimumPlayableRangeSemitones) {
        high = (low + MinimumPlayableRangeSemitones).coerceAtMost(HighestExtraPlayableMidiNote)
        low = (high - MinimumPlayableRangeSemitones).coerceAtLeast(LowestExtraPlayableMidiNote)
    }
    return low..high
}

fun cMidiNoteForOctave(octave: Int): Int {
    return ((octave + 1) * 12).coerceIn(LowestExtraPlayableMidiNote, HighestExtraPlayableMidiNote)
}

fun octaveForCMidiNote(midiNote: Int): Int {
    return midiNote / 12 - 1
}

fun sanitizeMidiProgramNumber(program: Int): Int {
    return program.coerceIn(MinMidiProgramNumber, MaxMidiProgramNumber)
}

fun sanitizeOvertoneRange(range: IntRange): IntRange {
    var low = range.first.coerceIn(MinOvertoneMultiplier, MaxOvertoneMultiplier / 2)
    var high = range.last.coerceIn(MinOvertoneMultiplier, MaxOvertoneMultiplier)
    val requiredHigh = maxOf(low * 2, low + MinOvertoneToneCount)

    if (high < requiredHigh) {
        high = requiredHigh
    }
    if (high > MaxOvertoneMultiplier) {
        high = MaxOvertoneMultiplier
        low = low
            .coerceAtMost(high / 2)
            .coerceAtMost(high - MinOvertoneToneCount)
            .coerceAtLeast(MinOvertoneMultiplier)
    }

    return low..high
}

fun maxOvertoneToneCount(multiplierRange: IntRange): Int {
    val sanitized = sanitizeOvertoneRange(multiplierRange)
    return minOf(MaxOvertoneToneCount, sanitized.last - sanitized.first)
        .coerceAtLeast(MinOvertoneToneCount)
}

fun sanitizeOvertoneToneCount(noteCount: Int, multiplierRange: IntRange): Int {
    return noteCount.coerceIn(MinOvertoneToneCount, maxOvertoneToneCount(multiplierRange))
}

fun midiNoteFrequency(midiNote: Int): Double {
    return 440.0 * 2.0.pow((midiNote - 69) / 12.0)
}

fun extraStepRangeForMidiRange(edo: Int, noteRange: IntRange): IntRange {
    val normalizedEdo = sanitizeExtraEdo(edo)
    val playableRange = sanitizeExtraPlayableRange(noteRange)
    val low = ceil(playableRange.first * normalizedEdo / 12.0 - 0.000001).toInt()
    val high = floor(playableRange.last * normalizedEdo / 12.0 + 0.000001).toInt()
    return if (high >= low) low..high else low..low
}

fun midiValueForExtraStep(step: Int, edo: Int): Double {
    return step * 12.0 / sanitizeExtraEdo(edo)
}

fun extraStepLabel(step: Int, edo: Int): String {
    val normalizedEdo = sanitizeExtraEdo(edo)
    val octave = Math.floorDiv(step, normalizedEdo) - 1
    val octaveStep = step.floorMod(normalizedEdo)
    return extraPitchName(octaveStep, normalizedEdo)
        ?.let { pitch -> "${pitch.name}${octave + pitch.octaveOffset}" }
        ?: legacyExtraStepLabel(octave, octaveStep)
}

fun extraStepTileLabel(step: Int, edo: Int): String {
    val normalizedEdo = sanitizeExtraEdo(edo)
    val octave = Math.floorDiv(step, normalizedEdo) - 1
    val octaveStep = step.floorMod(normalizedEdo)
    return extraPitchName(octaveStep, normalizedEdo)
        ?.let { pitch -> "${pitch.name}${octave + pitch.octaveOffset}" }
        ?: legacyExtraStepTileLabel(octave, octaveStep, normalizedEdo)
}

private data class ExtraPitchName(
    val name: String,
    val octaveOffset: Int
)

private fun legacyExtraStepLabel(octave: Int, octaveStep: Int): String {
    return if (octaveStep == 0) {
        "C$octave"
    } else {
        "C$octave+$octaveStep"
    }
}

private fun legacyExtraStepTileLabel(octave: Int, octaveStep: Int, edo: Int): String {
    return if (octaveStep == 0) {
        "C$octave"
    } else {
        "C$octave\n+$octaveStep\\$edo"
    }
}

private fun extraPitchName(octaveStep: Int, edo: Int): ExtraPitchName? {
    return extraPitchNameTable(edo).getOrNull(octaveStep)
}

private fun extraPitchNameTable(edo: Int): List<ExtraPitchName?> {
    return extraPitchNameTableCache.getOrPut(edo) {
        simpleExtraPitchNameTables[edo]?.let { names ->
            names.map { pitch ->
                ExtraPitchName(name = pitch, octaveOffset = 0)
            }
        } ?: run {
            List(edo) { octaveStep ->
                potdNumericName(octaveStep, edo)?.toExtraPitchName()
            }
        }
    }
}

private fun String.toExtraPitchName(): ExtraPitchName? {
    var octaveOffset = 0
    var index = 0
    while (index < length) {
        when (this[index]) {
            '\'' -> octaveOffset += 1
            '`' -> octaveOffset -= 1
            else -> break
        }
        index += 1
    }
    val body = drop(index)
    val degree = body.lastOrNull() ?: return null
    val pitch = extraPitchNames[degree] ?: return null
    val accidental = body.dropLast(1)
    return ExtraPitchName(name = "$accidental$pitch", octaveOffset = octaveOffset)
}

private fun potdNumericName(step: Int, edo: Int): String? {
    if (edo <= 0) {
        return null
    }
    val oc = edo
    val tr = (edo * log2(3.0)).roundHalfToEven()
    val hp = (edo * log2(7.0)).roundHalfToEven()
    val ded = 2 * tr - 3 * oc
    val xed = 8 * oc - 5 * tr
    val zid = 7 * tr - 11 * oc
    val maxStep = maxOf(ded, xed)

    val mav: Int
    val neu: Map<String, Int>
    val neuj: Map<String, Int>
    val fls: Map<String, Int>
    if (xed > 0) {
        mav = maxOf(3 * oc - hp - xed, maxStep.floorDiv(2))
        neu = linkedMapOf(
            "1" to 0,
            "2" to ded,
            "3" to 2 * ded,
            "4" to 2 * ded + xed,
            "5" to 3 * ded + xed,
            "6" to edo - ded - xed,
            "7" to edo - xed
        )
        neuj = mapOf(
            "1" to ded,
            "2" to ded,
            "3" to xed,
            "4" to ded,
            "5" to ded,
            "6" to ded,
            "7" to xed
        )
        fls = mapOf("1" to 0, "2" to 0, "3" to 0, "4" to 0, "5" to 0, "6" to 0, "7" to 1)
    } else {
        mav = maxOf(3 * oc - hp - (xed + ded), maxStep.floorDiv(2))
        neu = linkedMapOf(
            "1" to 0,
            "2" to ded,
            "3" to 2 * ded,
            "5" to 3 * ded + xed,
            "6" to edo - ded - xed
        )
        neuj = mapOf(
            "1" to ded,
            "2" to ded,
            "3" to xed + ded,
            "5" to ded,
            "6" to ded + xed
        )
        fls = mapOf("1" to 0, "2" to 0, "3" to 0, "5" to 0, "6" to 1)
    }

    var namePrefix = ""
    var degree: String? = null
    var cha = edo
    var rec: String? = null
    for ((name, position) in neu) {
        if (position == step) {
            degree = name
            cha = 0
            break
        }
        val distance = step - position
        if (distance in 1 until cha) {
            rec = name
            cha = distance
        }
    }
    if (degree == null) {
        val record = rec ?: return null
        val zcha = neuj[record] ?: return null
        val ycha = zcha - cha
        val condition = if (zcha == maxStep) {
            ycha <= mav
        } else {
            ycha <= mav + (zcha - maxStep).floorDiv(2)
        }
        if (condition) {
            cha = -ycha
            if (fls[record] == 1) {
                degree = "1"
                namePrefix = "'"
            } else {
                degree = nextExtraDegree(record, neuj)
            }
        } else {
            degree = record
        }
    }

    val accidental = potdAccidental(cha, zid, xed) ?: return null
    return "$namePrefix$accidental$degree"
}

private fun nextExtraDegree(degree: String, neuj: Map<String, Int>): String {
    val next = degree.toInt() + 1
    return if (next.toString() in neuj) {
        next.toString()
    } else {
        (next + 1).toString()
    }
}

private fun potdAccidental(cha: Int, zid: Int, xed: Int): String? {
    if (xed <= 0) {
        return if (cha >= 0) "^".repeat(cha) else "v".repeat(-cha)
    }
    if (zid == 0) {
        return null
    }
    return if (zid.floorMod(2) == 1) {
        val zzha = roundRatioHalfToEven(cha, zid)
        val yzha = cha - zzha * zid
        extraUpDown(yzha) + extraSharpFlat(zzha)
    } else {
        val zzha = roundRatioHalfToEven(2 * cha, zid)
        val yzha = cha - zzha * (zid / 2)
        extraUpDown(yzha) + extraHalfSharpFlat(zzha)
    }
}

private fun extraSharpFlat(amount: Int): String {
    if (amount <= 0) {
        return "b".repeat(-amount)
    }
    return "#".repeat(amount.floorMod(2)) + "x".repeat(amount / 2)
}

private fun extraHalfSharpFlat(twiceAmount: Int): String {
    if (twiceAmount <= 0) {
        val amount = -twiceAmount
        return "d".repeat(amount.floorMod(2)) + "b".repeat(amount / 2)
    }
    return "#".repeat(if (twiceAmount.floorMod(4) >= 2) 1 else 0) +
        "+".repeat(twiceAmount.floorMod(2)) +
        "x".repeat(twiceAmount / 4)
}

private fun extraUpDown(amount: Int): String {
    return if (amount <= 0) {
        "v".repeat(-amount)
    } else {
        "^".repeat(amount)
    }
}

private fun roundRatioHalfToEven(numerator: Int, denominator: Int): Int {
    var n = numerator
    var d = denominator
    if (d < 0) {
        n = -n
        d = -d
    }
    val floor = Math.floorDiv(n, d)
    val remainder = n - floor * d
    val twice = remainder * 2
    return when {
        twice < d -> floor
        twice > d -> floor + 1
        floor.floorMod(2) == 0 -> floor
        else -> floor + 1
    }
}

private fun Double.roundHalfToEven(): Int {
    val floorValue = floor(this).toInt()
    val remainder = this - floorValue
    return when {
        remainder < 0.5 -> floorValue
        remainder > 0.5 -> floorValue + 1
        floorValue.floorMod(2) == 0 -> floorValue
        else -> floorValue + 1
    }
}

fun extraRangeLabel(edo: Int, noteRange: IntRange): String {
    val stepRange = extraStepRangeForMidiRange(edo, noteRange)
    val normalizedEdo = sanitizeExtraEdo(edo)
    return "${extraStepLabel(stepRange.first, normalizedEdo)}-${extraStepLabel(stepRange.last, normalizedEdo)}"
}

fun randomOvertoneBaseMidiNote(
    multiplierRange: IntRange,
    random: Random = Random.Default
): Int {
    val candidates = overtoneBaseCandidates(multiplierRange)
    val totalWeight = candidates.indices.sumOf { index ->
        overtoneBaseCandidateWeight(index, candidates.size)
    }
    var ticket = random.nextInt(totalWeight)
    candidates.forEachIndexed { index, midiNote ->
        ticket -= overtoneBaseCandidateWeight(index, candidates.size)
        if (ticket < 0) {
            return midiNote
        }
    }
    return candidates.first()
}

fun overtoneBaseCandidates(multiplierRange: IntRange): List<Int> {
    val sanitized = sanitizeOvertoneRange(multiplierRange)
    val highestFrequency = midiNoteFrequency(HighestPlayableMidiNote)
    return FullPianoRange.filter { midiNote ->
        midiNoteFrequency(midiNote) * sanitized.last <= highestFrequency + 0.000001
    }
}

fun overtoneBaseCandidateWeight(index: Int, candidateCount: Int): Int {
    val lowBias = (candidateCount - index).coerceAtLeast(1)
    return lowBias * lowBias
}

fun isBlackKey(midiNote: Int): Boolean {
    return when (midiNote.floorMod(12)) {
        1, 3, 6, 8, 10 -> true
        else -> false
    }
}

private fun nextCAtOrAbove(midiNote: Int): Int {
    return midiNote + (12 - midiNote.floorMod(12)).floorMod(12)
}

private fun previousCAtOrBelow(midiNote: Int): Int {
    return midiNote - midiNote.floorMod(12)
}

private fun nextWhiteKeyAtOrAbove(midiNote: Int): Int {
    var note = midiNote
    while (!isWhiteMidiKey(note)) {
        note += 1
    }
    return note
}

private fun previousWhiteKeyAtOrBelow(midiNote: Int): Int {
    var note = midiNote
    while (!isWhiteMidiKey(note)) {
        note -= 1
    }
    return note
}

private fun Int.floorMod(other: Int): Int {
    return ((this % other) + other) % other
}
