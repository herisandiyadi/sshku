import '../data/models/ai_command.dart';

/// Memeriksa command hasil AI terhadap blocklist katastrofik dan memberi
/// penanda risiko. Menjadi seam utama safety — diuji lewat [classify].
class SafetyEngine {
  /// Pola yang TIDAK PERNAH boleh dieksekusi, meski user menyetujui.
  /// Case-insensitive, dicek terhadap teks command yang sudah dinormalisasi
  /// (whitespace beruntun -> satu spasi).
  static final List<RegExp> _blocklist = [
    // rm -rf pada root / home-root saja: target harus '/', '/*', '~', '/ ' atau '~/'
    // diikuti akhir string / spasi — BUKAN path dalam seperti /home/user/build.
    RegExp(r'\brm\s+-[a-z]*\s*(/|/\*|~|/\.\*)(\s|$)', caseSensitive: false),
    RegExp(r'\bmkfs', caseSensitive: false),
    RegExp(r'\bdd\b.*\bof=/dev/(sd|nvme|vd|hd)', caseSensitive: false),
    RegExp(r':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:'), // fork bomb
    RegExp(r'\bchmod\s+-[a-z]*r[a-z]*\s+(000|777)\s+/', caseSensitive: false),
    RegExp(r'>\s*/dev/(sd|nvme|vd|hd)', caseSensitive: false),
    RegExp(r'\b(shutdown|reboot|halt|poweroff)\b', caseSensitive: false),
    RegExp(r'\binit\s+0\b', caseSensitive: false),
  ];

  /// Pola command yang menulis/menghapus/mengubah izin -> tandai dangerous.
  static final List<RegExp> _dangerous = [
    RegExp(r'\brm\b', caseSensitive: false),
    RegExp(r'\brmdir\b', caseSensitive: false),
    RegExp(r'\bchmod\b', caseSensitive: false),
    RegExp(r'\bchown\b', caseSensitive: false),
    RegExp(r'\b(kill|killall|pkill)\b', caseSensitive: false),
    RegExp(r'\bdocker\s+(rm|rmi|volume\s+rm|system\s+prune)\b', caseSensitive: false),
    RegExp(r'\b(curl|wget)\b.*\|\s*(ba)?sh\b', caseSensitive: false), // pipe to shell
    RegExp(r'\bdrop\s+(database|table)\b', caseSensitive: false),
  ];

  /// Pola write ringan / service change -> caution.
  static final List<RegExp> _caution = [
    RegExp(r'\b(apt|apt-get|yum|dnf|apk|pacman)\s+(install|remove|update|upgrade)\b', caseSensitive: false),
    RegExp(r'\bsystemctl\s+(start|stop|restart|reload|enable|disable)\b', caseSensitive: false),
    RegExp(r'\bdocker\s+(start|stop|restart|pull|run|compose)\b', caseSensitive: false),
    RegExp(r'\b(cp|mv|mkdir|touch|tee)\b', caseSensitive: false),
    RegExp(r'\bsudo\b', caseSensitive: false),
    RegExp(r'>', caseSensitive: false), // redirect (write)
  ];

  /// Kembalikan salinan command dengan `blocked` dan `risk` terisi.
  AiCommand classify(AiCommand command) {
    final normalized = command.cmd.replaceAll(RegExp(r'\s+'), ' ').trim();
    final blocked = _blocklist.any((re) => re.hasMatch(normalized));
    return command.copyWith(blocked: blocked, risk: _riskOf(normalized));
  }

  AiRisk _riskOf(String normalized) {
    if (_dangerous.any((re) => re.hasMatch(normalized))) return AiRisk.dangerous;
    if (_caution.any((re) => re.hasMatch(normalized))) return AiRisk.caution;
    return AiRisk.safe;
  }
}
