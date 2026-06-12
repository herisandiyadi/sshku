import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/terminal/domain/terminal_buffer.dart';
import 'package:sshku/features/terminal/presentation/widgets/terminal_selection.dart';

void main() {
  test('start and update set correct bounds', () {
    final sel = TerminalSelection();
    sel.start(1, 2);
    expect(sel.startRow, 1);
    expect(sel.startCol, 2);
    expect(sel.isSelecting, true);

    sel.update(3, 5);
    expect(sel.endRow, 3);
    expect(sel.endCol, 5);
  });

  test('getSelectedText extracts correct characters from buffer', () {
    final buffer = TerminalBuffer(rows: 5, cols: 10);
    buffer.write('HelloWorld');
    final sel = TerminalSelection();
    sel.start(0, 0);
    sel.update(0, 4);
    expect(sel.getSelectedText(buffer), 'Hello');
  });

  test('clear resets selection', () {
    final sel = TerminalSelection();
    sel.start(0, 0);
    sel.clear();
    expect(sel.isSelecting, false);
  });
}
