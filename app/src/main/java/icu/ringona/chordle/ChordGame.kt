package icu.ringona.chordle

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.math.pow
import kotlin.random.Random

private val pitchNames = listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")

const val LowestPlayableMidiNote = 21
const val HighestPlayableMidiNote = 108
const val MinimumPlayableRangeSemitones = 12
const val MinChordToneCount = 1
const val MaxChordToneCount = 10
const val DefaultChordToneCount = 3
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
val DefaultOvertoneRange = 8..16

enum class TileState {
    Empty,
    Input,
    Correct,
    Present,
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
        if (currentColumn >= columns) {
            message = "这一行已经填满"
            return
        }
        setCell(currentRow, currentColumn, GuessCell(note, TileState.Input))
        currentColumn += 1
    }

    fun deleteLast() {
        if (status != GameStatus.Playing || currentColumn <= 0) {
            return
        }
        currentColumn -= 1
        setCell(currentRow, currentColumn, GuessCell())
    }

    fun submitGuess(itemName: String = "音") {
        if (status != GameStatus.Playing) {
            return
        }
        val guess = rowNotes(currentRow)
        if (guess.size != columns) {
            message = "请先确认全部 ${columns} 个$itemName"
            return
        }
        val result = evaluateGuess(guess, puzzle.notes)
        result.forEachIndexed { column, state ->
            setCell(currentRow, column, GuessCell(guess[column], state))
        }

        if (result.all { it == TileState.Correct }) {
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

fun noteLabel(midiNote: Int): String {
    val pitch = pitchNames[midiNote.floorMod(12)]
    val octave = midiNote / 12 - 1
    return "$pitch$octave"
}

fun rangeLabel(range: IntRange): String {
    val sanitized = sanitizePlayableRange(range)
    return "${noteLabel(sanitized.first)}-${noteLabel(sanitized.last)}"
}

fun sanitizePlayableRange(range: IntRange): IntRange {
    var low = range.first.coerceIn(LowestPlayableMidiNote, HighestPlayableMidiNote - MinimumPlayableRangeSemitones)
    var high = range.last.coerceIn(LowestPlayableMidiNote + MinimumPlayableRangeSemitones, HighestPlayableMidiNote)
    if (high - low < MinimumPlayableRangeSemitones) {
        high = (low + MinimumPlayableRangeSemitones).coerceAtMost(HighestPlayableMidiNote)
        low = (high - MinimumPlayableRangeSemitones).coerceAtLeast(LowestPlayableMidiNote)
    }
    return low..high
}

fun sanitizeChordToneCount(noteCount: Int): Int {
    return noteCount.coerceIn(MinChordToneCount, MaxChordToneCount)
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

private fun Int.floorMod(other: Int): Int {
    return ((this % other) + other) % other
}
