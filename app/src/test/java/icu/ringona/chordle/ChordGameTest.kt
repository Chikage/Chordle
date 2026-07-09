package icu.ringona.chordle

import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.random.Random

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
    fun confirmSelectedValueAcceptsOutOfOrderValuesBeforeValidation() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))

        listOf(55, 52, 48).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        assertEquals(listOf(55, 52, 48), game.rowNotes(0))
        assertEquals(
            listOf(TileState.Present, TileState.Correct, TileState.Present),
            (0 until game.columns).map { column -> game.cell(0, column).state }
        )
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

    @Test
    fun sanitizeOvertoneRangeKeepsLegalMultiplierWindow() {
        assertEquals(8..16, sanitizeOvertoneRange(8..16))
        assertEquals(1..3, sanitizeOvertoneRange(1..2))
        assertEquals(15..31, sanitizeOvertoneRange(20..31))
    }

    @Test
    fun sanitizeOvertoneToneCountDependsOnRangeSize() {
        assertEquals(2, sanitizeOvertoneToneCount(10, 1..3))
        assertEquals(4, sanitizeOvertoneToneCount(4, 8..16))
        assertEquals(8, sanitizeOvertoneToneCount(10, 8..16))
        assertEquals(10, sanitizeOvertoneToneCount(30, 1..31))
    }

    @Test
    fun overtoneBaseWeightsFavorLowerCandidates() {
        val candidates = overtoneBaseCandidates(16..31)
        val middleIndex = candidates.lastIndex / 2

        assertEquals(
            true,
            overtoneBaseCandidateWeight(0, candidates.size) >
                overtoneBaseCandidateWeight(middleIndex, candidates.size)
        )
        assertEquals(
            true,
            overtoneBaseCandidateWeight(middleIndex, candidates.size) >
                overtoneBaseCandidateWeight(candidates.lastIndex, candidates.size)
        )
    }

    @Test
    fun randomOvertoneBaseMidiNoteBiasesTowardLowerHalf() {
        val candidates = overtoneBaseCandidates(16..31)
        val midpoint = candidates[candidates.size / 2]
        val random = Random(20260709)
        val draws = List(400) { randomOvertoneBaseMidiNote(16..31, random) }
        val lowerHalfDraws = draws.count { it <= midpoint }

        assertEquals(true, lowerHalfDraws > draws.size * 3 / 4)
    }

    @Test
    fun randomOvertonePuzzleStaysInRangeAndUnderC8() {
        repeat(50) {
            val puzzle = ChordPuzzle.randomOvertones(toneCount = 4, multiplierRange = 8..16)
            val baseMidiNote = puzzle.baseMidiNote ?: error("Overtone puzzle should include a base note")
            val highestFrequency = midiNoteFrequency(baseMidiNote) * puzzle.notes.max()

            assertEquals(4, puzzle.notes.size)
            assertEquals(puzzle.notes.sorted(), puzzle.notes)
            assertEquals(true, puzzle.notes.all { it in 8..16 })
            assertEquals(true, highestFrequency <= midiNoteFrequency(HighestPlayableMidiNote) + 0.000001)
        }
    }
}
