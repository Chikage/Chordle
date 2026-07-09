package icu.ringona.chordle

import org.junit.Assert.assertEquals
import org.junit.Test

class ChordGameTest {
    @Test
    fun evaluateGuessMarksExactPositionsGreen() {
        val result = evaluateGuess(listOf(48, 52, 55), listOf(48, 52, 55))

        assertEquals(listOf(TileState.Correct, TileState.Correct, TileState.Correct), result)
    }

    @Test
    fun evaluateGuessMarksWrongPositionYellowAndMissingGray() {
        val result = evaluateGuess(listOf(52, 48, 59), listOf(48, 52, 55))

        assertEquals(listOf(TileState.Present, TileState.Present, TileState.Absent), result)
    }

    @Test
    fun sanitizePlayableRangeKeepsAtLeastOneOctave() {
        val range = sanitizePlayableRange(60..64)

        assertEquals(60..72, range)
    }

    @Test
    fun randomPuzzleStaysInsideSelectedRange() {
        repeat(50) {
            val puzzle = ChordPuzzle.random(noteCount = 3, noteRange = 60..72)

            assertEquals(true, puzzle.notes.all { it in 60..72 })
        }
    }

    @Test
    fun randomPuzzleUsesRequestedToneCount() {
        repeat(50) {
            val puzzle = ChordPuzzle.random(noteCount = 10, noteRange = 48..72)

            assertEquals(10, puzzle.notes.size)
            assertEquals(puzzle.notes.sorted(), puzzle.notes)
        }
    }

    @Test
    fun sanitizeChordToneCountLimitsToOneThroughTen() {
        assertEquals(1, sanitizeChordToneCount(-4))
        assertEquals(7, sanitizeChordToneCount(7))
        assertEquals(10, sanitizeChordToneCount(42))
    }

    @Test
    fun sanitizeMidiProgramNumberLimitsToZeroThroughOneTwentySeven() {
        assertEquals(0, sanitizeMidiProgramNumber(-1))
        assertEquals(64, sanitizeMidiProgramNumber(64))
        assertEquals(127, sanitizeMidiProgramNumber(200))
    }
}
