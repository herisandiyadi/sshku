import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/ai_command/data/datasources/ai_response_parser.dart';

void main() {
  final parser = AiResponseParser();

  test('parses clean JSON', () {
    final result = parser.parse(
      '{"commands":[{"cmd":"ls -la","desc":"list files"}]}',
    );
    expect(result, hasLength(1));
    expect(result.first.cmd, 'ls -la');
    expect(result.first.desc, 'list files');
  });

  test('parses multiple commands', () {
    final result = parser.parse(
      '{"commands":[{"cmd":"apt update"},{"cmd":"apt install nginx"}]}',
    );
    expect(result.map((c) => c.cmd), ['apt update', 'apt install nginx']);
  });

  test('extracts JSON wrapped in prose / code fence', () {
    final result = parser.parse(
      'Sure! Here you go:\n```json\n{"commands":[{"cmd":"whoami"}]}\n```\nHope it helps.',
    );
    expect(result.single.cmd, 'whoami');
  });

  test('accepts "command"/"description" aliases', () {
    final result = parser.parse(
      '{"commands":[{"command":"pwd","description":"where am i"}]}',
    );
    expect(result.single.cmd, 'pwd');
    expect(result.single.desc, 'where am i');
  });

  test('skips entries with empty cmd', () {
    final result = parser.parse(
      '{"commands":[{"cmd":""},{"cmd":"ls"}]}',
    );
    expect(result.single.cmd, 'ls');
  });

  test('throws on garbage', () {
    expect(() => parser.parse('I cannot help with that.'),
        throwsA(isA<FormatException>()));
  });

  test('throws when commands missing', () {
    expect(() => parser.parse('{"foo":"bar"}'),
        throwsA(isA<FormatException>()));
  });

  test('throws when commands empty', () {
    expect(() => parser.parse('{"commands":[]}'),
        throwsA(isA<FormatException>()));
  });
}
