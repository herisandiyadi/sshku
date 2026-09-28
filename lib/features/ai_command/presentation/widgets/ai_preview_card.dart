import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/ai_command.dart';

/// Kartu preview satu command hasil AI: badge risiko, teks command, deskripsi,
/// dan tombol Run (dinonaktifkan bila command terblokir).
class AiPreviewCard extends StatelessWidget {
  final AiCommand command;
  final VoidCallback onRun;

  const AiPreviewCard({super.key, required this.command, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final blocked = command.blocked;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: blocked ? AppColors.error : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RiskBadge(risk: command.risk, blocked: blocked),
              const Spacer(),
              if (blocked)
                const Text('Blocked',
                    style: TextStyle(color: AppColors.error, fontSize: 12))
              else
                TextButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            command.cmd,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.onSurface,
              fontSize: 13,
            ),
          ),
          if (command.desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              command.desc,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (blocked) ...[
            const SizedBox(height: 6),
            const Text(
              'Command ini diblokir demi keamanan. Ketik manual di terminal bila benar-benar diperlukan.',
              style: TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final AiRisk risk;
  final bool blocked;
  const _RiskBadge({required this.risk, required this.blocked});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (blocked ? null : risk) {
      null => (AppColors.error, 'BLOCKED'),
      AiRisk.safe => (AppColors.primary, 'SAFE'),
      AiRisk.caution => (const Color(0xFFE0A100), 'CAUTION'),
      AiRisk.dangerous => (AppColors.error, 'DANGEROUS'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
