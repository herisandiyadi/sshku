import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshku/features/app_lock/presentation/cubit/app_lock_cubit.dart';

String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  blocTest<AppLockCubit, AppLockState>(
    'initial state is locked when lock enabled',
    setUp: () {
      SharedPreferences.setMockInitialValues({
        'lock_enabled': true,
        'pin_hash': _hashPin('1234'),
      });
    },
    build: () => AppLockCubit(),
    act: (c) => c.checkLock(),
    expect: () => [isA<AppLockLocked>()],
  );

  blocTest<AppLockCubit, AppLockState>(
    'verifyPin with correct PIN unlocks',
    setUp: () {
      SharedPreferences.setMockInitialValues({
        'lock_enabled': true,
        'pin_hash': _hashPin('1234'),
      });
    },
    build: () => AppLockCubit(),
    act: (c) => c.verifyPin('1234'),
    expect: () => [isA<AppLockUnlocked>()],
  );

  blocTest<AppLockCubit, AppLockState>(
    'verifyPin with wrong PIN stays locked',
    setUp: () {
      SharedPreferences.setMockInitialValues({
        'lock_enabled': true,
        'pin_hash': _hashPin('1234'),
      });
    },
    build: () => AppLockCubit(),
    act: (c) => c.verifyPin('9999'),
    expect: () => [],
  );
}
