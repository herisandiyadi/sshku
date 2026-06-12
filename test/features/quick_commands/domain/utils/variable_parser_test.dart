import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/quick_commands/domain/utils/variable_parser.dart';

void main() {
  test('extractVariables finds {{var}} patterns', () {
    expect(extractVariables('ssh {{host}} -p {{port}}'), containsAll(['host', 'port']));
  });

  test('substituteVariables replaces correctly', () {
    final result = substituteVariables('echo {{name}}', {'name': 'world'});
    expect(result, 'echo world');
  });

  test('handles multiple variables', () {
    final result = substituteVariables(
      '{{a}} and {{b}}',
      {'a': '1', 'b': '2'},
    );
    expect(result, '1 and 2');
  });

  test('returns empty list for no variables', () {
    expect(extractVariables('no variables here'), isEmpty);
  });
}
