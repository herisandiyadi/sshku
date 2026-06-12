import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:sshku/core/platform/keystore_platform_channel.dart';
import 'package:sshku/core/database/database_helper.dart';
import 'package:sshku/features/ssh_keys/data/models/ssh_key_model.dart';

class ImportKeyDialog extends StatefulWidget {
  const ImportKeyDialog({super.key});

  @override
  State<ImportKeyDialog> createState() => _ImportKeyDialogState();
}

class _ImportKeyDialogState extends State<ImportKeyDialog> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _passphraseController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      final content = await File(result.files.single.path!).readAsString();
      _keyController.text = content;
    }
  }

  Future<void> _import() async {
    if (_nameController.text.trim().isEmpty || _keyController.text.trim().isEmpty) {
      setState(() => _error = 'Name and key content are required');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final channel = KeystorePlatformChannel();
      final result = await channel.importKey(
        _keyController.text.trim(),
        passphrase: _passphraseController.text.isEmpty ? null : _passphraseController.text,
      );

      final model = SshKeyModel(
        name: _nameController.text.trim(),
        type: result['type'] as String,
        publicKey: result['publicKey'] as String,
        encryptedPrivateKey: result['encryptedPrivateKey'] as String,
        createdAt: DateTime.now().toIso8601String(),
      );

      await DatabaseHelper.instance.insertKey(model);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('PlatformException(', '').split(',').take(2).join(': '));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import SSH Key'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Key Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: 'Private Key Content',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.file_open),
                  onPressed: _pickFile,
                  tooltip: 'Pick file',
                ),
              ),
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passphraseController,
              decoration: const InputDecoration(labelText: 'Passphrase (optional)'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _import,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Import'),
        ),
      ],
    );
  }
}
