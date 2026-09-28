import 'package:flutter/material.dart';

import '../../../../core/security/credential_manager.dart';
import '../../../../core/platform/keystore_platform_channel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ai_command/data/datasources/ai_provider_datasource.dart';
import '../../../ai_command/data/repositories/ai_config_repository.dart';
import '../../../ai_command/domain/prompt_builder.dart';

/// Halaman konfigurasi AI Command (BYOK): base URL, API key, model.
class AiConfigPage extends StatefulWidget {
  const AiConfigPage({super.key});

  @override
  State<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends State<AiConfigPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  final _repo = AiConfigRepository(CredentialManager(KeystorePlatformChannel()));

  bool _obscureKey = true;
  bool _loading = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _repo.load();
    if (!mounted) return;
    setState(() {
      _baseUrlController.text = config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _repo.save(
      baseUrl: _baseUrlController.text,
      model: _modelController.text,
      apiKey: _apiKeyController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('AI config disimpan')));
    Navigator.pop(context);
  }

  Future<void> _clear() async {
    await _repo.clear();
    if (!mounted) return;
    setState(() {
      _baseUrlController.clear();
      _apiKeyController.clear();
      _modelController.clear();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('AI config dihapus')));
  }

  Future<void> _test() async {
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    if (baseUrl.isEmpty || model.isEmpty) {
      _snack('Base URL dan Model wajib diisi', isError: true);
      return;
    }
    setState(() => _testing = true);
    try {
      await AiProviderDatasource().generate(
        baseUrl: baseUrl,
        apiKey: _apiKeyController.text,
        model: model,
        systemPrompt: PromptBuilder().systemPrompt(),
        instruction: 'echo hello',
      );
      _snack('Koneksi berhasil');
    } catch (e) {
      _snack('Gagal: ${e.toString().replaceFirst('Exception: ', '')}',
          isError: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Command'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Gunakan API key Anda sendiri (BYOK). Endpoint harus kompatibel '
                  'dengan OpenAI Chat Completions.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Provider Base URL',
                    hintText: 'https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'API Key (opsional untuk endpoint lokal)',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureKey ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _modelController,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'gpt-4o-mini',
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: Text(_testing ? 'Menguji...' : 'Test Connection'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text('Hapus Konfigurasi',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
    );
  }
}
