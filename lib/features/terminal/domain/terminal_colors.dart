import 'dart:ui';

abstract final class TerminalColors {
  // Standard 16 ANSI colors (0-7 normal, 8-15 bright)
  static const List<Color> ansi16 = [
    Color(0xFF000000), // 0 Black
    Color(0xFFAA0000), // 1 Red
    Color(0xFF00AA00), // 2 Green
    Color(0xFFAA5500), // 3 Yellow
    Color(0xFF0000AA), // 4 Blue
    Color(0xFFAA00AA), // 5 Magenta
    Color(0xFF00AAAA), // 6 Cyan
    Color(0xFFAAAAAA), // 7 White
    Color(0xFF555555), // 8 Bright Black
    Color(0xFFFF5555), // 9 Bright Red
    Color(0xFF55FF55), // 10 Bright Green
    Color(0xFFFFFF55), // 11 Bright Yellow
    Color(0xFF5555FF), // 12 Bright Blue
    Color(0xFFFF55FF), // 13 Bright Magenta
    Color(0xFF55FFFF), // 14 Bright Cyan
    Color(0xFFFFFFFF), // 15 Bright White
  ];

  static const Color defaultFg = Color(0xFFE0E0E0);
  static const Color defaultBg = Color(0xFF000000);

  /// Lookup color from 256-color palette index.
  static Color from256(int index) {
    if (index < 16) return ansi16[index];
    if (index < 232) {
      // 6x6x6 color cube (indices 16-231)
      final i = index - 16;
      final r = (i ~/ 36) * 51;
      final g = ((i % 36) ~/ 6) * 51;
      final b = (i % 6) * 51;
      return Color.fromARGB(255, r, g, b);
    }
    // Grayscale ramp (indices 232-255)
    final v = (index - 232) * 10 + 8;
    return Color.fromARGB(255, v, v, v);
  }
}
