package icu.ringona.chordle

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.random.Random

private val pitchNames = listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")

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
    val label: String
) {
    companion object {
        fun random(noteCount: Int = 3): ChordPuzzle {
            val templates = when (noteCount) {
                4 -> listOf(
                    "maj7" to listOf(0, 4, 7, 11),
                    "min7" to listOf(0, 3, 7, 10),
                    "7" to listOf(0, 4, 7, 10),
                    "m7b5" to listOf(0, 3, 6, 10)
                )
                5 -> listOf(
                    "maj9" to listOf(0, 4, 7, 11, 14),
                    "min9" to listOf(0, 3, 7, 10, 14),
                    "9" to listOf(0, 4, 7, 10, 14)
                )
                else -> listOf(
                    "major" to listOf(0, 4, 7),
                    "minor" to listOf(0, 3, 7),
                    "dim" to listOf(0, 3, 6),
                    "sus4" to listOf(0, 5, 7),
                    "aug" to listOf(0, 4, 8)
                )
            }
            val (quality, intervals) = templates.random()
            val root = Random.nextInt(43, 60)
            val notes = intervals.map { root + it }
            return ChordPuzzle(notes = notes, label = "${noteLabel(root)} $quality")
        }
    }
}

class ChordleGame(
    initialPuzzle: ChordPuzzle = ChordPuzzle.random(3),
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
        get() = puzzle.notes.joinToString("  ") { noteLabel(it) }

    init {
        rebuildCells()
    }

    fun selectNote(note: Int) {
        selectedNote = note
    }

    fun confirmSelectedNote() {
        if (status != GameStatus.Playing) {
            return
        }
        val note = selectedNote ?: run {
            message = "先在钢琴上选择一个音"
            return
        }
        if (currentColumn >= columns) {
            message = "这一行已经填满"
            return
        }
        val previous = if (currentColumn > 0) cell(currentRow, currentColumn - 1).note else null
        if (previous != null && note <= previous) {
            message = "请按从低到高确认音符"
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

    fun submitGuess() {
        if (status != GameStatus.Playing) {
            return
        }
        val guess = rowNotes(currentRow)
        if (guess.size != columns) {
            message = "请先确认全部 ${columns} 个音"
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

    fun newPuzzle(noteCount: Int = columns) {
        puzzle = ChordPuzzle.random(noteCount)
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

    private fun rowNotes(row: Int): List<Int> {
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

fun isBlackKey(midiNote: Int): Boolean {
    return when (midiNote.floorMod(12)) {
        1, 3, 6, 8, 10 -> true
        else -> false
    }
}

private fun Int.floorMod(other: Int): Int {
    return ((this % other) + other) % other
}

