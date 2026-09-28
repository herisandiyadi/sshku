import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/ai_command.dart';
import '../../data/repositories/ai_config_repository.dart';
import '../cubit/ai_command_cubit.dart';
import '../cubit/ai_command_state.dart';
import 'ai_preview_card.dart';

/// Bottom sheet AI Command: user mengetik instruksi, melihat preview command,
/// dan menjalankannya. Command yang disetujui dikirim lewat [onRun].
class AiInputPanel extends StatelessWidget {
  /// Dipanggil saat user menyetujui sebuah command. Implementasi terminal
  /// mengirimnya ke shell (mis. `sendInput('$cmd\r')`).
  final void Function(String command) onRun;

  const AiInputPanel({super.key, required this.onRun});

  static Future<void> show(BuildContext context,
      {required void Function(String command) onRun}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AiInputPanel(onRun: onRun),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AiCommandCubit(
        configRepo: AiConfigRepository.create(),
      ),
      child: _AiInputView(onRun: onRun),
    );
  }
}

class _AiInputView extends StatefulWidget {
  final void Function(String command) onRun;
  const _AiInputView({required this.onRun});

  @override
  State<_AiInputView> createState() => _AiInputViewState();
}

class _AiInputViewState extends State<_AiInputView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(BuildContext context, String cmd) {
    widget.onRun(cmd);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dijalankan: $cmd'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('AI Command',
                  style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.onSurface),
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (v) => context.read<AiCommandCubit>().generate(v),
            decoration: InputDecoration(
              hintText: 'Instruksi, mis. "restart nginx lalu cek statusnya"',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: () =>
                    context.read<AiCommandCubit>().generate(_controller.text),
              ),
            ),
          ),
          const SizedBox(height: 12),
          BlocBuilder<AiCommandCubit, AiCommandState>(
            builder: (context, state) => _buildResult(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, AiCommandState state) {
    switch (state) {
      case AiIdle():
        return const SizedBox.shrink();
      case AiGenerating():
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        );
      case AiError(:final message):
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(message, style: const TextStyle(color: AppColors.error)),
        );
      case AiPreview(:final commands):
        return _buildPreview(context, commands);
    }
  }

  Widget _buildPreview(BuildContext context, List<AiCommand> commands) {
    final runnable = commands.where((c) => !c.blocked).toList();
    final allSafe = runnable.isNotEmpty &&
        runnable.every((c) => c.risk == AiRisk.safe) &&
        runnable.length == commands.length;

    return Flexible(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final cmd in commands)
            AiPreviewCard(command: cmd, onRun: () => _run(context, cmd.cmd)),
          if (allSafe && runnable.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  final count = runnable.length;
                  for (final c in runnable) {
                    widget.onRun(c.cmd);
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Menjalankan $count command'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.playlist_play),
                label: const Text('Run all'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
