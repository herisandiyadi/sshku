import 'dart:ui';

import 'package:sshku/features/terminal/domain/terminal_colors.dart';

enum _ParserState { normal, escape, csi }

class TerminalCell {
  String character;
  Color fgColor;
  Color bgColor;
  bool bold;

  TerminalCell({
    this.character = ' ',
    this.fgColor = TerminalColors.defaultFg,
    this.bgColor = TerminalColors.defaultBg,
    this.bold = false,
  });

  TerminalCell copy() => TerminalCell(
        character: character,
        fgColor: fgColor,
        bgColor: bgColor,
        bold: bold,
      );
}

class TerminalBuffer {
  static const int maxHistoryLines = 1000;

  int rows;
  int cols;
  late List<List<TerminalCell>> screenBuffer;
  int cursorRow = 0;
  int cursorCol = 0;
  int scrollOffset = 0;

  final List<List<TerminalCell>> history = [];

  // Inline parser state (avoids intermediate List<AnsiAction> allocation)
  _ParserState _parserState = _ParserState.normal;
  final StringBuffer _paramBuf = StringBuffer();

  // Current SGR attributes
  Color _fgColor = TerminalColors.defaultFg;
  Color _bgColor = TerminalColors.defaultBg;
  bool _bold = false;

  TerminalBuffer({this.rows = 24, this.cols = 80}) {
    screenBuffer = _createBuffer(rows, cols);
  }

  List<List<TerminalCell>> _createBuffer(int r, int c) =>
      List.generate(r, (_) => List.generate(c, (_) => TerminalCell()));

  /// Main entry point — write raw terminal data including escape sequences.
  void write(String data) {
    final len = data.length;
    var i = 0;
    while (i < len) {
      final c = data.codeUnitAt(i);
      switch (_parserState) {
        case _ParserState.normal:
          if (c == 0x1B) {
            _parserState = _ParserState.escape;
          } else if (c == 0x0A) {
            _newline();
          } else if (c == 0x0D) {
            cursorCol = 0;
          } else if (c == 0x08) {
            if (cursorCol > 0) cursorCol--;
          } else if (c == 0x09) {
            cursorCol = ((cursorCol ~/ 8) + 1) * 8;
            if (cursorCol >= cols) cursorCol = cols - 1;
          } else if (c >= 0x20) {
            _putChar(data[i]);
          }
          break;
        case _ParserState.escape:
          if (c == 0x5B) {
            // '['
            _parserState = _ParserState.csi;
            _paramBuf.clear();
          } else {
            _parserState = _ParserState.normal;
          }
          break;
        case _ParserState.csi:
          if (c >= 0x30 && c <= 0x3F) {
            _paramBuf.writeCharCode(c);
          } else if (c >= 0x20 && c <= 0x2F) {
            // intermediate bytes — skip
          } else {
            // final byte
            _parserState = _ParserState.normal;
            _dispatchCsi(c);
          }
          break;
      }
      i++;
    }
  }

  void clear() {
    screenBuffer = _createBuffer(rows, cols);
    cursorRow = 0;
    cursorCol = 0;
  }

  void resize(int newRows, int newCols) {
    final newBuf = _createBuffer(newRows, newCols);
    for (var r = 0; r < newRows && r < rows; r++) {
      for (var c = 0; c < newCols && c < cols; c++) {
        newBuf[r][c] = screenBuffer[r][c];
      }
    }
    rows = newRows;
    cols = newCols;
    screenBuffer = newBuf;
    cursorRow = cursorRow.clamp(0, rows - 1);
    cursorCol = cursorCol.clamp(0, cols - 1);
  }

  List<TerminalCell> getLine(int row) =>
      (row >= 0 && row < rows) ? screenBuffer[row] : [];

  int get maxScrollBack => history.length;

  List<TerminalCell> getVisibleLine(int row) {
    if (scrollOffset == 0) return getLine(row);
    final idx = history.length - scrollOffset + row;
    if (idx >= 0 && idx < history.length) return history[idx];
    final screenRow = idx - history.length;
    return getLine(screenRow);
  }

  // --- Private helpers ---

  List<int> _parseCsiParams() {
    final s = _paramBuf.toString();
    if (s.isEmpty) return const [];
    return s.split(';').map((p) => int.tryParse(p) ?? 0).toList();
  }

  void _dispatchCsi(int finalByte) {
    final params = _parseCsiParams();
    final p1 = (params.isNotEmpty && params[0] > 0) ? params[0] : 1;

    switch (finalByte) {
      case 0x41: // 'A' cursor up
        cursorRow = (cursorRow - p1).clamp(0, rows - 1);
      case 0x42: // 'B' cursor down
        cursorRow = (cursorRow + p1).clamp(0, rows - 1);
      case 0x43: // 'C' cursor forward
        cursorCol = (cursorCol + p1).clamp(0, cols - 1);
      case 0x44: // 'D' cursor back
        cursorCol = (cursorCol - p1).clamp(0, cols - 1);
      case 0x48: // 'H' cursor position
      case 0x66: // 'f' cursor position
        final r = params.isNotEmpty ? params[0] : 1;
        final c = params.length > 1 ? params[1] : 1;
        cursorRow = (r - 1).clamp(0, rows - 1);
        cursorCol = (c - 1).clamp(0, cols - 1);
      case 0x4A: // 'J' erase display
        _eraseDisplay(params.isNotEmpty ? params[0] : 0);
      case 0x4B: // 'K' erase line
        _eraseLine(params.isNotEmpty ? params[0] : 0);
      case 0x6D: // 'm' SGR
        _applySgr(params);
    }
  }

  void _putChar(String ch) {
    if (cursorCol >= cols) {
      cursorCol = 0;
      _newline();
    }
    screenBuffer[cursorRow][cursorCol]
      ..character = ch
      ..fgColor = _fgColor
      ..bgColor = _bgColor
      ..bold = _bold;
    cursorCol++;
  }

  void _newline() {
    if (cursorRow < rows - 1) {
      cursorRow++;
    } else {
      // Push top row to history
      history.add(screenBuffer.removeAt(0));
      if (history.length > maxHistoryLines) history.removeAt(0);
      screenBuffer.add(List.generate(cols, (_) => TerminalCell()));
    }
  }

  void _eraseDisplay(int mode) {
    switch (mode) {
      case 0: // Cursor to end
        _eraseLine(0);
        for (var r = cursorRow + 1; r < rows; r++) {
          _clearRow(r);
        }
        break;
      case 1: // Start to cursor
        for (var r = 0; r < cursorRow; r++) {
          _clearRow(r);
        }
        for (var c = 0; c <= cursorCol && c < cols; c++) {
          screenBuffer[cursorRow][c] = TerminalCell();
        }
        break;
      case 2: // Entire screen
      case 3:
        clear();
        break;
    }
  }

  void _eraseLine(int mode) {
    switch (mode) {
      case 0: // Cursor to end
        for (var c = cursorCol; c < cols; c++) {
          screenBuffer[cursorRow][c] = TerminalCell();
        }
        break;
      case 1: // Start to cursor
        for (var c = 0; c <= cursorCol && c < cols; c++) {
          screenBuffer[cursorRow][c] = TerminalCell();
        }
        break;
      case 2: // Entire line
        _clearRow(cursorRow);
        break;
    }
  }

  void _clearRow(int row) {
    for (var c = 0; c < cols; c++) {
      screenBuffer[row][c] = TerminalCell();
    }
  }

  void _applySgr(List<int> params) {
    if (params.isEmpty) params = [0];
    for (var i = 0; i < params.length; i++) {
      final p = params[i];
      switch (p) {
        case 0:
          _fgColor = TerminalColors.defaultFg;
          _bgColor = TerminalColors.defaultBg;
          _bold = false;
          break;
        case 1:
          _bold = true;
          break;
        case 22:
          _bold = false;
          break;
        case 39:
          _fgColor = TerminalColors.defaultFg;
          break;
        case 49:
          _bgColor = TerminalColors.defaultBg;
          break;
        default:
          // FG standard (30-37)
          if (p >= 30 && p <= 37) {
            _fgColor = TerminalColors.ansi16[p - 30];
          }
          // BG standard (40-47)
          else if (p >= 40 && p <= 47) {
            _bgColor = TerminalColors.ansi16[p - 40];
          }
          // FG bright (90-97)
          else if (p >= 90 && p <= 97) {
            _fgColor = TerminalColors.ansi16[p - 90 + 8];
          }
          // BG bright (100-107)
          else if (p >= 100 && p <= 107) {
            _bgColor = TerminalColors.ansi16[p - 100 + 8];
          }
          // 256-color / RGB extended
          else if (p == 38 && i + 1 < params.length) {
            if (params[i + 1] == 5 && i + 2 < params.length) {
              _fgColor = TerminalColors.from256(params[i + 2]);
              i += 2;
            } else if (params[i + 1] == 2 && i + 4 < params.length) {
              _fgColor = Color.fromARGB(
                  255, params[i + 2], params[i + 3], params[i + 4]);
              i += 4;
            }
          } else if (p == 48 && i + 1 < params.length) {
            if (params[i + 1] == 5 && i + 2 < params.length) {
              _bgColor = TerminalColors.from256(params[i + 2]);
              i += 2;
            } else if (params[i + 1] == 2 && i + 4 < params.length) {
              _bgColor = Color.fromARGB(
                  255, params[i + 2], params[i + 3], params[i + 4]);
              i += 4;
            }
          }
      }
    }
  }
}
