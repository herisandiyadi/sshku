import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/ai_provider_datasource.dart';
import '../../data/repositories/ai_config_repository.dart';
import '../../domain/prompt_builder.dart';
import '../../domain/safety_engine.dart';
import 'ai_command_state.dart';

/// Mengorkestrasi: baca config -> panggil provider -> klasifikasi safety ->
/// preview. Tidak mengeksekusi command; eksekusi diserahkan ke pemanggil
/// (terminal) lewat callback agar Cubit ini tetap bebas dependensi terminal.
class AiCommandCubit extends Cubit<AiCommandState> {
  final AiConfigRepository _configRepo;
  final AiProviderDatasource _datasource;
  final PromptBuilder _promptBuilder;
  final SafetyEngine _safety;

  AiCommandCubit({
    required AiConfigRepository configRepo,
    AiProviderDatasource? datasource,
    PromptBuilder? promptBuilder,
    SafetyEngine? safety,
  })  : _configRepo = configRepo,
        _datasource = datasource ?? AiProviderDatasource(),
        _promptBuilder = promptBuilder ?? PromptBuilder(),
        _safety = safety ?? SafetyEngine(),
        super(const AiIdle());

  Future<void> generate(String instruction) async {
    final trimmed = instruction.trim();
    if (trimmed.isEmpty) return;

    emit(const AiGenerating());
    try {
      final config = await _configRepo.load();
      if (!config.isConfigured) {
        emit(const AiError('AI belum dikonfigurasi. Buka Settings > AI Command.'));
        return;
      }

      final raw = await _datasource.generate(
        baseUrl: config.baseUrl,
        apiKey: config.apiKey,
        model: config.model,
        systemPrompt: _promptBuilder.systemPrompt(),
        instruction: trimmed,
      );

      final classified = raw.map(_safety.classify).toList();
      emit(AiPreview(classified));
    } catch (e) {
      emit(AiError(_clean(e)));
    }
  }

  void reset() => emit(const AiIdle());

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').replaceFirst('FormatException: ', '');
}
