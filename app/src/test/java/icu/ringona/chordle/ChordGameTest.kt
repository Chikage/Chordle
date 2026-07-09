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
}
