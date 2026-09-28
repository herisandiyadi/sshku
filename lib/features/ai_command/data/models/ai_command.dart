import 'package:equatable/equatable.dart';

/// Tingkat risiko command hasil AI. `dangerous` bukan berarti terblokir —
/// blokir ditentukan terpisah oleh [SafetyEngine].
enum AiRisk { safe, caution, dangerous }

/// Satu shell command yang dihasilkan AI, siap di-preview user.
class AiCommand extends Equatable {
  final String cmd;
  final String desc;

  /// True bila command cocok dengan pola blocklist katastrofik.
  /// Command terblokir tidak boleh dieksekusi meski user menyetujui.
  final bool blocked;
  final AiRisk risk;

  const AiCommand({
    required this.cmd,
    this.desc = '',
    this.blocked = false,
    this.risk = AiRisk.safe,
  });

  AiCommand copyWith({String? cmd, String? desc, bool? blocked, AiRisk? risk}) =>
      AiCommand(
        cmd: cmd ?? this.cmd,
        desc: desc ?? this.desc,
        blocked: blocked ?? this.blocked,
        risk: risk ?? this.risk,
      );

  @override
  List<Object?> get props => [cmd, desc, blocked, risk];
}
