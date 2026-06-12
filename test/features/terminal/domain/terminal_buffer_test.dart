import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/terminal/domain/terminal_buffer.dart';

void main() {
  late TerminalBuffer buffer;

  setUp(() {
    buffer = TerminalBuffer(rows: 5, cols: 10);
  });

  test('write plain text fills buffer correctly', () {
    buffer.write('Hello');
    final line = buffer.getLine(0).map((c) => c.character).join().trimRight();
    expect(line, 'Hello');
    expect(buffer.cursorCol, 5);
    expect(buffer.cursorRow, 0);
  });

  test('write newline moves cursor down', () {
    buffer.write('A\r\nB');
    expect(buffer.cursorRow, 1);
    expect(buffer.getLine(0)[0].character, 'A');
    expect(buffer.getLine(1)[0].character, 'B');
  });

  test('buffer scrolls when exceeding rows (history grows)', () {
    for (var i = 0; i < 6; i++) {
      buffer.write('L$i\n');
    }
    expect(buffer.history.isNotEmpty, true);
    // First line should have been pushed to history
    final histLine = buffer.history[0].map((c) => c.character).join().trimRight();
    expect(histLine, 'L0');
  });

  test('resize preserves content', () {
    buffer.write('Test');
    buffer.resize(10, 20);
    expect(buffer.rows, 10);
    expect(buffer.cols, 20);
    final line = buffer.getLine(0).map((c) => c.character).join().trimRight();
    expect(line, 'Test');
  });

  test('clear resets buffer', () {
    buffer.write('Data');
    buffer.clear();
    expect(buffer.cursorRow, 0);
    expect(buffer.cursorCol, 0);
    final line = buffer.getLine(0).map((c) => c.character).join().trimRight();
    expect(line, '');
  });

  test('scrollOffset and getVisibleLine work with history', () {
    // Fill buffer to generate history
    for (var i = 0; i < 7; i++) {
      buffer.write('R$i\n');
    }
    expect(buffer.history.length, greaterThan(0));
    buffer.scrollOffset = 1;
    final visibleLine = buffer.getVisibleLine(0).map((c) => c.character).join().trimRight();
    // Should show a history line
    expect(visibleLine.isNotEmpty, true);
  });
}
