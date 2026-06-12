import '../../domain/terminal_buffer.dart';

class TerminalSelection {
  int startRow = 0;
  int startCol = 0;
  int endRow = 0;
  int endCol = 0;
  bool isSelecting = false;

  void start(int row, int col) {
    startRow = row;
    startCol = col;
    endRow = row;
    endCol = col;
    isSelecting = true;
  }

  void update(int row, int col) {
    endRow = row;
    endCol = col;
  }

  void clear() {
    isSelecting = false;
  }

  String getSelectedText(TerminalBuffer buffer) {
    int r1 = startRow, c1 = startCol, r2 = endRow, c2 = endCol;
    if (r1 > r2 || (r1 == r2 && c1 > c2)) {
      final tr = r1, tc = c1;
      r1 = r2; c1 = c2; r2 = tr; c2 = tc;
    }
    final lines = <String>[];
    for (int r = r1; r <= r2 && r < buffer.rows; r++) {
      final row = buffer.screenBuffer[r];
      final start = (r == r1) ? c1 : 0;
      final end = (r == r2) ? c2 : row.length - 1;
      final sb = StringBuffer();
      for (int c = start; c <= end && c < row.length; c++) {
        sb.write(row[c].character);
      }
      lines.add(sb.toString().trimRight());
    }
    return lines.join('\n');
  }
}
