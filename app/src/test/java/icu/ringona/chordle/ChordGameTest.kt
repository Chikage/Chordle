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
    fun rowsAndCellsBecomeJudgedOnlyAfterSubmit() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))

        listOf(55, 52, 48).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }

        assertEquals(false, game.cellIsJudged(0, 0))
        assertEquals(false, game.rowIsJudged(0))

        game.submitGuess()

        assertEquals(true, game.cellIsJudged(0, 0))
        assertEquals(true, game.rowIsJudged(0))
        assertEquals(false, game.rowIsJudged(1))
    }

    @Test
    fun confirmSelectedValueRejectsDuplicateNoteInCurrentRow() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))

        game.selectNote(48)
        game.confirmSelectedValue(missingSelectionMessage = "missing")
        game.selectNote(48)
        game.confirmSelectedValue(missingSelectionMessage = "missing")

        assertEquals(listOf(48), game.rowNotes(0))
        assertEquals(null, game.cell(0, 1).note)
        assertEquals(1, game.currentColumn)
        assertEquals("这一行不能填写两个相同的音", game.message)
    }

    @Test
    fun carriedCorrectCellRejectsDuplicateNoteInCurrentRow() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(47, 52, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        game.selectNote(52)
        game.confirmSelectedValue(missingSelectionMessage = "missing")

        assertEquals(false, game.canCarryCorrectCellFromPreviousRow(0, 1))
        assertEquals(false, game.carryCorrectCellFromPreviousRow(1))
        assertEquals(null, game.cell(1, 1).note)
        assertEquals(1, game.currentColumn)
        assertEquals("这一行不能填写两个相同的音", game.message)
    }

    @Test
    fun movedPresentCellRejectsDuplicateNoteInCurrentRow() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(52, 48, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        game.selectNote(52)
        game.confirmSelectedValue(missingSelectionMessage = "missing")

        assertEquals(false, game.canPlacePresentCellFromPreviousRow(0, 0, 1))
        assertEquals(false, game.placePresentCellFromPreviousRow(sourceColumn = 0, targetColumn = 1))
        assertEquals(null, game.cell(1, 1).note)
        assertEquals(1, game.currentColumn)
        assertEquals("这一行不能填写两个相同的音", game.message)
    }

    @Test
    fun carriedCorrectCellSkipsThatColumnWhileFillingNextGuess() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(48, 57, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        assertEquals(true, game.carryCorrectCellFromPreviousRow(0))
        assertEquals(48, game.cell(1, 0).note)
        assertEquals(TileState.Carried, game.cell(1, 0).state)
        assertEquals(false, game.cellIsJudged(1, 0))
        assertEquals(1, game.currentColumn)

        listOf(52, 55).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }

        assertEquals(listOf(48, 52, 55), game.rowNotes(1))
        game.submitGuess()
        assertEquals(GameStatus.Won, game.status)
    }

    @Test
    fun carriedCorrectCellCanReplaceFilledMatchingColumn() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(47, 52, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        listOf(48, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        assertEquals(59, game.cell(1, 1).note)

        assertEquals(true, game.carryCorrectCellFromPreviousRow(1))

        assertEquals(52, game.cell(1, 1).note)
        assertEquals(TileState.Carried, game.cell(1, 1).state)
        assertEquals(2, game.currentColumn)
    }

    @Test
    fun deleteLastSkipsCarriedCells() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(48, 57, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()
        game.carryCorrectCellFromPreviousRow(0)
        game.selectNote(52)
        game.confirmSelectedValue(missingSelectionMessage = "missing")

        game.deleteLast()

        assertEquals(48, game.cell(1, 0).note)
        assertEquals(TileState.Carried, game.cell(1, 0).state)
        assertEquals(null, game.cell(1, 1).note)
        assertEquals(1, game.currentColumn)
        assertEquals(false, game.canDeleteLast())
    }

    @Test
    fun sortRowByReordersFilledCellsAndKeepsNextOpenColumn() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(55, 48).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }

        assertEquals(true, game.sortRowBy(0))

        assertEquals(listOf(48, 55), game.rowNotes(0))
        assertEquals(48, game.cell(0, 0).note)
        assertEquals(55, game.cell(0, 1).note)
        assertEquals(null, game.cell(0, 2).note)
        assertEquals(2, game.currentColumn)
    }

    @Test
    fun sortRowByPreservesCellStatesWithSortedValues() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(48, 57, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()
        game.carryCorrectCellFromPreviousRow(0)
        listOf(55, 52).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }

        assertEquals(true, game.sortRowBy(1))

        assertEquals(listOf(48, 52, 55), game.rowNotes(1))
        assertEquals(
            listOf(TileState.Carried, TileState.Input, TileState.Input),
            (0 until game.columns).map { column -> game.cell(1, column).state }
        )
        assertEquals(3, game.currentColumn)
    }

    @Test
    fun presentCellCanMoveToDifferentColumnAsInput() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(52, 48, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        assertEquals(TileState.Present, game.cell(0, 0).state)
        assertEquals(false, game.placePresentCellFromPreviousRow(sourceColumn = 0, targetColumn = 0))
        assertEquals(true, game.placePresentCellFromPreviousRow(sourceColumn = 0, targetColumn = 1))

        assertEquals(52, game.cell(1, 1).note)
        assertEquals(TileState.Input, game.cell(1, 1).state)
        assertEquals(0, game.currentColumn)

        listOf(48, 55).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }

        assertEquals(listOf(48, 52, 55), game.rowNotes(1))
        game.submitGuess()
        assertEquals(GameStatus.Won, game.status)
    }

    @Test
    fun presentCellCanReplaceFilledDifferentColumn() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(52, 48, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        listOf(48, 60).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        assertEquals(60, game.cell(1, 1).note)

        assertEquals(true, game.placePresentCellFromPreviousRow(sourceColumn = 0, targetColumn = 1))

        assertEquals(52, game.cell(1, 1).note)
        assertEquals(TileState.Input, game.cell(1, 1).state)
        assertEquals(2, game.currentColumn)
    }

    @Test
    fun deleteLastCanRemovePresentCellMovedAheadOfCurrentColumn() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(48, 52, 55), label = "test"))
        listOf(52, 48, 59).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }
        game.submitGuess()

        game.placePresentCellFromPreviousRow(sourceColumn = 0, targetColumn = 2)

        assertEquals(52, game.cell(1, 2).note)
        assertEquals(0, game.currentColumn)
        assertEquals(true, game.canDeleteLast())

        game.deleteLast()

        assertEquals(null, game.cell(1, 2).note)
        assertEquals(0, game.currentColumn)
        assertEquals(false, game.canDeleteLast())
    }

    @Test
    fun sanitizePlayableRangeKeepsAtLeastOneOctave() {
        val range = sanitizePlayableRange(60..64)

        assertEquals(60..72, range)
    }

    @Test
    fun sanitizePlayableRangeLimitsEndpointsToWhiteKeys() {
        assertEquals(62..74, sanitizePlayableRange(61..73))
        assertEquals(21..33, sanitizePlayableRange(21..34))
        assertEquals(96..108, sanitizePlayableRange(97..108))
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
    fun sanitizeExtraPlayableRangeLimitsEndpointsToC() {
        assertEquals(36..72, sanitizeExtraPlayableRange(34..77))
        assertEquals(24..36, sanitizeExtraPlayableRange(21..33))
        assertEquals(96..108, sanitizeExtraPlayableRange(107..108))
    }

    @Test
    fun randomExtraPuzzleUsesCOnlyRangeBoundaries() {
        repeat(50) {
            val puzzle = ChordPuzzle.randomExtra(noteCount = 3, noteRange = 34..77, edo = 12)

            assertEquals(true, puzzle.notes.all { it in 36..72 })
            assertEquals(puzzle.notes.sorted(), puzzle.notes)
        }
    }

    @Test
    fun extraStepTileLabelUsesPotdPitchNames() {
        assertEquals("C3", extraStepTileLabel(96, 24))
        assertEquals("dE3", extraStepTileLabel(103, 24))
        assertEquals("B4", extraStepTileLabel(49 + 53 * 5, 53))
        assertEquals("B4", extraStepLabel(49 + 53 * 5, 53))
    }

    @Test
    fun extraStepLabelUsesSimpleDiatonicNamesForSevenEdo() {
        val labels = (0..6).map { step -> extraStepLabel(step + 7 * 5, 7) }

        assertEquals(listOf("C4", "D4", "E4", "F4", "G4", "A4", "B4"), labels)
    }

    @Test
    fun extraStepLabelUsesRaisedDiatonicNamesForFourteenEdo() {
        val labels = (0..13).map { step -> extraStepLabel(step + 14 * 5, 14) }

        assertEquals(
            listOf("C4", "^C4", "D4", "^D4", "E4", "^E4", "F4", "^F4", "G4", "^G4", "A4", "^A4", "B4", "^B4"),
            labels
        )
    }

    @Test
    fun extraStepLabelUsesThirdToneDiatonicNamesForTwentyOneEdo() {
        val labels = (0..20).map { step -> extraStepLabel(step + 21 * 5, 21) }

        assertEquals(
            listOf(
                "C4", "^C4", "vD4",
                "D4", "^D4", "vE4",
                "E4", "^E4", "vF4",
                "F4", "^F4", "vG4",
                "G4", "^G4", "vA4",
                "A4", "^A4", "vB4",
                "B4", "^B4", "vC4"
            ),
            labels
        )
    }

    @Test
    fun extraStepLabelUsesQuarterToneDiatonicNamesForTwentyEightEdo() {
        val labels = (0..27).map { step -> extraStepLabel(step + 28 * 5, 28) }

        assertEquals(
            listOf(
                "C4", "^C4", "^^C4", "vD4",
                "D4", "^D4", "^^D4", "vE4",
                "E4", "^E4", "^^E4", "vF4",
                "F4", "^F4", "^^F4", "vG4",
                "G4", "^G4", "^^G4", "vA4",
                "A4", "^A4", "^^A4", "vB4",
                "B4", "^B4", "^^B4", "vC4"
            ),
            labels
        )
    }

    @Test
    fun extraStepLabelUsesFifthToneDiatonicNamesForThirtyFiveEdo() {
        val labels = (0..34).map { step -> extraStepLabel(step + 35 * 5, 35) }

        assertEquals(
            listOf(
                "C4", "^C4", "^^C4", "vvD4", "vD4",
                "D4", "^D4", "^^D4", "vvE4", "vE4",
                "E4", "^E4", "^^E4", "vvF4", "vF4",
                "F4", "^F4", "^^F4", "vvG4", "vG4",
                "G4", "^G4", "^^G4", "vvA4", "vA4",
                "A4", "^A4", "^^A4", "vvB4", "vB4",
                "B4", "^B4", "^^B4", "vvC4", "vC4"
            ),
            labels
        )
    }

    @Test
    fun evaluateExtraGuessUsesFiftyCentTolerance() {
        val result = evaluateExtraGuess(
            guess = listOf(97, 108, 100),
            answer = listOf(96, 108, 120),
            edo = 24
        )

        assertEquals(
            listOf(TileState.ExtraCorrect, TileState.Correct, TileState.Absent),
            result
        )
    }

    @Test
    fun evaluateExtraGuessMarksExactChordToneWrongPositionYellow() {
        val result = evaluateExtraGuess(
            guess = listOf(108, 96),
            answer = listOf(96, 108),
            edo = 24
        )

        assertEquals(listOf(TileState.Present, TileState.Present), result)
    }

    @Test
    fun evaluateExtraGuessMarksNearChordToneWrongPositionPink() {
        val result = evaluateExtraGuess(
            guess = listOf(109, 97),
            answer = listOf(96, 108),
            edo = 24
        )

        assertEquals(listOf(TileState.ExtraNear, TileState.ExtraNear), result)
    }

    @Test
    fun submitExtraGuessDoesNotWinOnToleranceOnlyCells() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(96, 108), label = "extra"))
        listOf(97, 109).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }

        game.submitExtraGuess(24)

        assertEquals(GameStatus.Playing, game.status)
        assertEquals(
            listOf(TileState.ExtraCorrect, TileState.ExtraCorrect),
            (0 until game.columns).map { column -> game.cell(0, column).state }
        )
    }

    @Test
    fun submitExtraGuessWinsOnlyOnExactGreenCells() {
        val game = ChordleGame(ChordPuzzle(notes = listOf(96, 108), label = "extra"))
        listOf(96, 108).forEach { value ->
            game.selectNote(value)
            game.confirmSelectedValue(missingSelectionMessage = "missing")
        }

        game.submitExtraGuess(24)

        assertEquals(GameStatus.Won, game.status)
        assertEquals(
            listOf(TileState.Correct, TileState.Correct),
            (0 until game.columns).map { column -> game.cell(0, column).state }
        )
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
