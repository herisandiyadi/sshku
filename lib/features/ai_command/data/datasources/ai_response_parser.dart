import 'dart:convert';

import '../models/ai_command.dart';

/// Mengubah teks `message.content` dari provider menjadi daftar [AiCommand].
///
/// Toleran terhadap model yang membungkus JSON dengan teks atau code fence:
/// mencoba parse langsung, lalu fallback ekstraksi blok JSON pertama.
/// Lempar [FormatException] bila tidak ada JSON valid yang bisa dibaca.
class AiResponseParser {
  List<AiCommand> parse(String content) {
    final json = _extractJson(content);
    if (json == null) {
      throw const FormatException('AI response tidak dapat dibaca');
    }

    final commandsRaw = json['commands'];
    if (commandsRaw is! List) {
      throw const FormatException('AI response tidak memuat "commands"');
    }

    final commands = <AiCommand>[];
    for (final item in commandsRaw) {
      if (item is! Map) continue;
      final cmd = (item['cmd'] ?? item['command'])?.toString().trim();
      if (cmd == null || cmd.isEmpty) continue;
      commands.add(AiCommand(
        cmd: cmd,
        desc: (item['desc'] ?? item['description'] ?? '').toString().trim(),
      ));
    }

    if (commands.isEmpty) {
      throw const FormatException('AI tidak menghasilkan command');
    }
    return commands;
  }

  /// Coba parse langsung; jika gagal, ekstrak substring dari `{` pertama
  /// sampai `}` terakhir dan parse itu.
  Map<String, dynamic>? _extractJson(String content) {
    final direct = _tryDecode(content);
    if (direct != null) return direct;

    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return _tryDecode(content.substring(start, end + 1));
  }

  Map<String, dynamic>? _tryDecode(String s) {
    try {
      final decoded = jsonDecode(s.trim());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
