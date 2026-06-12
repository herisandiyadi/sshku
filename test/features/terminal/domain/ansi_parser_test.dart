import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/terminal/domain/ansi_parser.dart';

void main() {
  late AnsiParser parser;

  setUp(() {
    parser = AnsiParser();
  });

  test('parses plain text as print actions', () {
    final actions = parser.parse('abc');
    expect(actions.length, 3);
    expect(actions.every((a) => a.type == AnsiActionType.print), true);
    expect(actions.map((a) => a.char).join(), 'abc');
  });

  test('parses \\x1B[31m as SGR red foreground', () {
    final actions = parser.parse('\x1B[31m');
    expect(actions.length, 1);
    expect(actions[0].type, AnsiActionType.sgr);
    expect(actions[0].params, [31]);
  });

  test('parses \\x1B[H as cursor home', () {
    final actions = parser.parse('\x1B[H');
    expect(actions.length, 1);
    expect(actions[0].type, AnsiActionType.cursorPosition);
    expect(actions[0].params, isEmpty);
  });

  test('parses \\x1B[2J as erase entire screen', () {
    final actions = parser.parse('\x1B[2J');
    expect(actions.length, 1);
    expect(actions[0].type, AnsiActionType.eraseDisplay);
    expect(actions[0].params, [2]);
  });

  test('parses \\x1B[A as cursor up', () {
    final actions = parser.parse('\x1B[A');
    expect(actions.length, 1);
    expect(actions[0].type, AnsiActionType.cursorUp);
  });
}
