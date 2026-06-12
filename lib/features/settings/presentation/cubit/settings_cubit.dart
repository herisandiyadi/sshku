import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final double terminalFontSize;

  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.terminalFontSize = 14,
  });

  SettingsState copyWith({ThemeMode? themeMode, double? terminalFontSize}) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 2; // dark default
    final fontSize = (prefs.getDouble('terminal_font_size') ?? 14).clamp(8.0, 24.0);
    emit(SettingsState(
      themeMode: ThemeMode.values[themeIndex],
      terminalFontSize: fontSize,
    ));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('terminal_font_size', size);
    emit(state.copyWith(terminalFontSize: size));
  }
}
