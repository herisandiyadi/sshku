import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/terminal_buffer.dart';
import 'terminal_selection.dart';

class TerminalPainter extends CustomPainter {
  final TerminalBuffer buffer;
  final bool showCursor;
  final TerminalSelection? selection;
  final double fontSize;
  final int tick;

  late final double cellWidth;
  late final double cellHeight;

  static final Map<double, Size> _cellSizeCache = {};

  static Size cellSize([double fs = 14]) {
    return _cellSizeCache.putIfAbsent(fs, () {
      final tp = TextPainter(
        text: TextSpan(
          text: 'M',
          style: TextStyle(fontFamily: 'monospace', fontSize: fs),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return Size(tp.width, tp.height);
    });
  }

  TerminalPainter({
    required this.buffer,
    this.showCursor = true,
    this.selection,
    this.fontSize = 14,
    this.tick = 0,
  }) {
    final s = cellSize(fontSize);
    cellWidth = s.width;
    cellHeight = s.height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    final bgPaint = Paint();
    final visibleRows = (size.height / cellHeight).ceil().clamp(0, buffer.rows);

    for (int row = 0; row < visibleRows; row++) {
      final line = buffer.getVisibleLine(row);
      if (line.isEmpty) continue;
      final y = row * cellHeight;

      // Draw backgrounds and build paragraph for this line
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        maxLines: 1,
      ));

      int runStart = 0;
      for (int col = 0; col < line.length; col++) {
        final cell = line[col];

        // Draw non-default background
        if (cell.bgColor != const Color(0xFF000000)) {
          bgPaint.color = cell.bgColor;
          canvas.drawRect(Rect.fromLTWH(col * cellWidth, y, cellWidth, cellHeight), bgPaint);
        }

        final nextSameStyle = col + 1 < line.length &&
            line[col + 1].fgColor == cell.fgColor &&
            line[col + 1].bold == cell.bold;

        if (!nextSameStyle) {
          // Push style and text for this run
          pb.pushStyle(ui.TextStyle(
            color: cell.fgColor,
            fontSize: fontSize,
            fontFamily: 'monospace',
            fontWeight: cell.bold ? FontWeight.bold : FontWeight.normal,
          ));
          final runBuf = StringBuffer();
          for (int c = runStart; c <= col; c++) {
            runBuf.write(line[c].character);
          }
          pb.addText(runBuf.toString());
          pb.pop();
          runStart = col + 1;
        }
      }

      final paragraph = pb.build()
        ..layout(ui.ParagraphConstraints(width: size.width));
      canvas.drawParagraph(paragraph, Offset(0, y));
    }

    // Selection highlight
    if (selection != null && selection!.isSelecting) {
      _paintSelection(canvas);
    }

    // Cursor
    if (showCursor && buffer.scrollOffset == 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          buffer.cursorCol * cellWidth,
          buffer.cursorRow * cellHeight,
          cellWidth,
          cellHeight,
        ),
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _paintSelection(Canvas canvas) {
    final s = selection!;
    int r1 = s.startRow, c1 = s.startCol, r2 = s.endRow, c2 = s.endCol;
    if (r1 > r2 || (r1 == r2 && c1 > c2)) {
      final tr = r1, tc = c1;
      r1 = r2; c1 = c2; r2 = tr; c2 = tc;
    }
    final paint = Paint()..color = AppColors.primary.withValues(alpha: 0.3);
    for (int r = r1; r <= r2 && r < buffer.rows; r++) {
      final start = (r == r1) ? c1 : 0;
      final end = (r == r2) ? c2 : buffer.cols - 1;
      canvas.drawRect(
        Rect.fromLTWH(start * cellWidth, r * cellHeight, (end - start + 1) * cellWidth, cellHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TerminalPainter oldDelegate) =>
      oldDelegate.tick != tick ||
      oldDelegate.fontSize != fontSize;

  Size get preferredSize =>
      Size(buffer.cols * cellWidth, buffer.rows * cellHeight);
}
