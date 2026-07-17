import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

enum BoardTileKind {
  empty,
  input,
  carried,
  correct,
  extraCorrect,
  present,
  extraNear,
  absent,
}

enum BoardDragKind { correct, present }

class BoardCellViewData {
  const BoardCellViewData({
    required this.kind,
    this.value,
    this.label = '',
    this.dragKind,
  });

  final int? value;
  final String label;
  final BoardTileKind kind;
  final BoardDragKind? dragKind;
}

class ChordBoard extends StatelessWidget {
  const ChordBoard({
    required this.rows,
    required this.columns,
    required this.currentRow,
    required this.currentColumn,
    required this.isPlaying,
    required this.cellAt,
    required this.canSortRow,
    required this.onSortRow,
    required this.canPlayRow,
    required this.onPlayRow,
    required this.canPlayCell,
    required this.onPlayCell,
    required this.canAcceptDrag,
    required this.onCarryCorrect,
    required this.onMovePresent,
    super.key,
  });

  final int rows;
  final int columns;
  final int currentRow;
  final int currentColumn;
  final bool isPlaying;
  final BoardCellViewData Function(int row, int column) cellAt;
  final bool Function(int row) canSortRow;
  final ValueChanged<int> onSortRow;
  final bool Function(int row) canPlayRow;
  final ValueChanged<int> onPlayRow;
  final bool Function(int row, int column) canPlayCell;
  final void Function(int row, int column, int value) onPlayCell;
  final bool Function(int sourceColumn, int value, int targetColumn)
  canAcceptDrag;
  final ValueChanged<int> onCarryCorrect;
  final void Function(int sourceColumn, int targetColumn) onMovePresent;

  @override
  Widget build(BuildContext context) {
    if (columns <= 0 || rows <= 0) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.55;
        final gap = columns >= 8 ? 3.0 : 6.0;
        final sideLane = width < 400 ? 30.0 : 38.0;
        final horizontal =
            (width - sideLane * 2 - gap * (columns - 1)) / columns;
        final vertical = (height - gap * (rows - 1)) / rows;
        final tileSize = math.max(
          16.0,
          math.min(64.0, math.min(horizontal, vertical)),
        );
        final rowWidth =
            tileSize * columns + gap * (columns - 1) + sideLane * 2;

        return Center(
          child: SizedBox(
            width: math.min(width, rowWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var row = 0; row < rows; row++) ...[
                  _BoardRow(
                    row: row,
                    columns: columns,
                    tileSize: tileSize,
                    gap: gap,
                    currentRow: currentRow,
                    currentColumn: currentColumn,
                    sideLane: sideLane,
                    isPlaying: isPlaying,
                    cellAt: cellAt,
                    canSort: canSortRow(row),
                    onSort: () => onSortRow(row),
                    canPlay: canPlayRow(row),
                    onPlay: () => onPlayRow(row),
                    canPlayCell: canPlayCell,
                    onPlayCell: onPlayCell,
                    canAcceptDrag: canAcceptDrag,
                    onCarryCorrect: onCarryCorrect,
                    onMovePresent: onMovePresent,
                  ),
                  if (row != rows - 1) SizedBox(height: gap),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.row,
    required this.columns,
    required this.tileSize,
    required this.gap,
    required this.currentRow,
    required this.currentColumn,
    required this.sideLane,
    required this.isPlaying,
    required this.cellAt,
    required this.canSort,
    required this.onSort,
    required this.canPlay,
    required this.onPlay,
    required this.canPlayCell,
    required this.onPlayCell,
    required this.canAcceptDrag,
    required this.onCarryCorrect,
    required this.onMovePresent,
  });

  final int row;
  final int columns;
  final double tileSize;
  final double gap;
  final int currentRow;
  final int currentColumn;
  final double sideLane;
  final bool isPlaying;
  final BoardCellViewData Function(int row, int column) cellAt;
  final bool canSort;
  final VoidCallback onSort;
  final bool canPlay;
  final VoidCallback onPlay;
  final bool Function(int row, int column) canPlayCell;
  final void Function(int row, int column, int value) onPlayCell;
  final bool Function(int sourceColumn, int value, int targetColumn)
  canAcceptDrag;
  final ValueChanged<int> onCarryCorrect;
  final void Function(int sourceColumn, int targetColumn) onMovePresent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileSize,
      child: Row(
        children: [
          SizedBox(
            width: sideLane,
            child: IconButton(
              onPressed: canSort ? onSort : null,
              tooltip: '排序此行',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.sort_rounded,
                size: math.min(21, tileSize * 0.46),
                color: canSort ? ChordleColors.muted : ChordleColors.border,
              ),
            ),
          ),
          for (var column = 0; column < columns; column++) ...[
            _BoardCell(
              row: row,
              column: column,
              currentRow: currentRow,
              currentColumn: currentColumn,
              isPlaying: isPlaying,
              size: tileSize,
              data: cellAt(row, column),
              canPlay: canPlayCell(row, column),
              onPlay: (value) => onPlayCell(row, column, value),
              canAcceptDrag: canAcceptDrag,
              onCarryCorrect: onCarryCorrect,
              onMovePresent: onMovePresent,
            ),
            if (column != columns - 1) SizedBox(width: gap),
          ],
          SizedBox(
            width: sideLane,
            child: IconButton(
              onPressed: canPlay ? onPlay : null,
              tooltip: '回放此行',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.play_arrow_rounded,
                size: math.min(24, tileSize * 0.52),
                color: canPlay ? ChordleColors.muted : ChordleColors.border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({
    required this.row,
    required this.column,
    required this.currentRow,
    required this.currentColumn,
    required this.isPlaying,
    required this.size,
    required this.data,
    required this.canPlay,
    required this.onPlay,
    required this.canAcceptDrag,
    required this.onCarryCorrect,
    required this.onMovePresent,
  });

  final int row;
  final int column;
  final int currentRow;
  final int currentColumn;
  final bool isPlaying;
  final double size;
  final BoardCellViewData data;
  final bool canPlay;
  final ValueChanged<int> onPlay;
  final bool Function(int sourceColumn, int value, int targetColumn)
  canAcceptDrag;
  final ValueChanged<int> onCarryCorrect;
  final void Function(int sourceColumn, int targetColumn) onMovePresent;

  @override
  Widget build(BuildContext context) {
    final active = isPlaying && row == currentRow && column == currentColumn;
    final tile = ChordTile(
      data: data,
      active: active,
      size: size,
      onTap: canPlay && data.value != null ? () => onPlay(data.value!) : null,
    );
    final draggable = data.dragKind;
    Widget result = tile;
    if (draggable != null && data.value != null) {
      final payload = _BoardDragData(
        sourceColumn: column,
        value: data.value!,
        kind: draggable,
        tile: data,
      );
      result = LongPressDraggable<_BoardDragData>(
        data: payload,
        delay: const Duration(milliseconds: 260),
        hapticFeedbackOnStart: true,
        feedback: Material(
          type: MaterialType.transparency,
          child: ChordTile(
            data: BoardCellViewData(
              value: data.value,
              label: data.label,
              kind: draggable == BoardDragKind.correct
                  ? BoardTileKind.carried
                  : data.kind,
            ),
            active: false,
            size: size,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.28, child: tile),
        child: tile,
      );
    }

    if (row == currentRow && isPlaying) {
      final targetChild = result;
      result = DragTarget<_BoardDragData>(
        onWillAcceptWithDetails: (details) {
          final drag = details.data;
          return canAcceptDrag(drag.sourceColumn, drag.value, column);
        },
        onAcceptWithDetails: (details) {
          final drag = details.data;
          switch (drag.kind) {
            case BoardDragKind.correct:
              onCarryCorrect(column);
            case BoardDragKind.present:
              onMovePresent(drag.sourceColumn, column);
          }
        },
        builder: (context, candidateData, rejectedData) {
          if (candidateData.isEmpty) return targetChild;
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Color(0x55FFFFFF), blurRadius: 10),
              ],
            ),
            child: targetChild,
          );
        },
      );
    }
    return result;
  }
}

class _BoardDragData {
  const _BoardDragData({
    required this.sourceColumn,
    required this.value,
    required this.kind,
    required this.tile,
  });

  final int sourceColumn;
  final int value;
  final BoardDragKind kind;
  final BoardCellViewData tile;
}

class ChordTile extends StatelessWidget {
  const ChordTile({
    required this.data,
    required this.active,
    required this.size,
    this.onTap,
    super.key,
  });

  final BoardCellViewData data;
  final bool active;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = switch (data.kind) {
      BoardTileKind.carried || BoardTileKind.correct => ChordleColors.green,
      BoardTileKind.extraCorrect => ChordleColors.extraCorrect,
      BoardTileKind.present => ChordleColors.yellow,
      BoardTileKind.extraNear => ChordleColors.extraNear,
      BoardTileKind.absent => ChordleColors.gray,
      BoardTileKind.empty || BoardTileKind.input => ChordleColors.background,
    };
    final border = active
        ? Colors.white
        : switch (data.kind) {
            BoardTileKind.input => ChordleColors.muted,
            BoardTileKind.empty => ChordleColors.border,
            _ => background,
          };

    return Semantics(
      button: onTap != null,
      label: data.label.isEmpty ? '空格' : data.label.replaceAll('\n', ' '),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          alignment: Alignment.center,
          padding: EdgeInsets.all(math.max(2, size * 0.055)),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: 2),
          ),
          child: data.label.isEmpty
              ? null
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data.label,
                    maxLines: data.label.contains('\n') ? 2 : 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: data.label.contains('\n') ? 13 : 18,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
