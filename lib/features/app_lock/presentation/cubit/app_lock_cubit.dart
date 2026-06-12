import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// States
abstract class AppLockState extends Equatable {
  const AppLockState();
  @override
  List<Object?> get props => [];
}

class AppLockLocked extends AppLockState {}

class AppLockUnlocked extends AppLockState {}

class AppLockSetup extends AppLockState {}

// Cubit
class AppLockCubit extends Cubit<AppLockState> {
  AppLockCubit() : super(AppLockLocked());

  static const _keyEnabled = 'lock_enabled';
  static const _keyPinHash = 'pin_hash';

  Future<void> checkLock() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    if (!enabled) {
      emit(AppLockUnlocked());
      return;
    }
    final pinHash = prefs.getString(_keyPinHash);
    if (pinHash == null) {
      emit(AppLockSetup());
    } else {
      emit(AppLockLocked());
    }
  }

  Future<void> unlock() async {
    emit(AppLockUnlocked());
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    final hash = _hashPin(pin);
    if (hash == stored) {
      emit(AppLockUnlocked());
      return true;
    }
    return false;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, _hashPin(pin));
    await prefs.setBool(_keyEnabled, true);
    emit(AppLockUnlocked());
  }

  Future<void> toggleLock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    if (!enabled) {
      await prefs.remove(_keyPinHash);
    }
  }

  bool get isEnabled {
    return state is AppLockLocked || state is AppLockSetup;
  }

  String _hashPin(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();
}
