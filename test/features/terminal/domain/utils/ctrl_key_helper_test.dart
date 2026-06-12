import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/terminal/domain/utils/ctrl_key_helper.dart';

void main() {
  test('ctrlChar c returns \\x03', () {
    expect(ctrlChar('c'), '\x03');
  });

  test('ctrlChar d returns \\x04', () {
    expect(ctrlChar('d'), '\x04');
  });

  test('ctrlChar z returns \\x1A', () {
    expect(ctrlChar('z'), '\x1A');
  });

  test('ctrlChar C (uppercase) returns \\x03', () {
    expect(ctrlChar('C'), '\x03');
  });
}
