import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sshku/core/widgets/empty_state_widget.dart';
import 'package:sshku/core/widgets/error_state_widget.dart';
import 'package:sshku/features/ssh_keys/presentation/cubit/ssh_keys_cubit.dart';
import 'package:sshku/features/ssh_keys/presentation/cubit/ssh_keys_state.dart';
import 'package:sshku/features/ssh_keys/presentation/widgets/import_key_dialog.dart';

class SshKeysPage extends StatelessWidget {
  const SshKeysPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SshKeysCubit()..loadKeys(),
      child: const _SshKeysView(),
    );
  }
}

class _SshKeysView extends StatelessWidget {
  const _SshKeysView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Keys'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'generate'
                ? _showGenerateDialog(context)
                : _showImportDialog(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'generate', child: Text('Generate')),
              PopupMenuItem(value: 'import', child: Text('Import')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<SshKeysCubit, SshKeysState>(
        builder: (context, state) {
          if (state is SshKeysLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (state is SshKeysError) {
            return ErrorStateWidget(
              message: state.message,
              onRetry: () => context.read<SshKeysCubit>().loadKeys(),
            );
          }
          if (state is SshKeysLoaded && state.keys.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.vpn_key_outlined,
              title: 'No SSH keys',
              subtitle: 'Generate or import keys to authenticate',
            );
          }
          if (state is SshKeysLoaded) {
            return ListView.builder(
              itemCount: state.keys.length,
              itemBuilder: (context, i) {
                final key = state.keys[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(key.name),
                    subtitle: Text(key.createdAt.split('T').first),
                    leading: Chip(
                      label: Text(key.type, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy public key',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: key.publicKey));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Public key copied!')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          tooltip: 'Delete',
                          onPressed: () => context.read<SshKeysCubit>().deleteKey(key.id!),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showImportDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ImportKeyDialog(),
    );
    if (result == true && context.mounted) {
      context.read<SshKeysCubit>().loadKeys();
    }
  }

  void _showGenerateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _GenerateKeyDialog(
        onGenerate: (name, type) => context.read<SshKeysCubit>().generateKey(name, type),
      ),
    );
  }
}

class _GenerateKeyDialog extends StatefulWidget {
  final void Function(String name, String type) onGenerate;
  const _GenerateKeyDialog({required this.onGenerate});

  @override
  State<_GenerateKeyDialog> createState() => _GenerateKeyDialogState();
}

class _GenerateKeyDialogState extends State<_GenerateKeyDialog> {
  final _nameController = TextEditingController();
  String _type = 'ed25519';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate SSH Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Key Name'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ed25519', label: Text('Ed25519')),
              ButtonSegment(value: 'rsa', label: Text('RSA')),
            ],
            selected: {_type},
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            widget.onGenerate(_nameController.text.trim(), _type);
            Navigator.pop(context);
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
