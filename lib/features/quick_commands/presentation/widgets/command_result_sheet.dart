import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/platform/dart_ssh_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ssh_connection/data/models/connection_model.dart';
import '../../domain/utils/variable_parser.dart';
import 'variable_input_dialog.dart';

Future<void> showCommandResultSheet(BuildContext context, String command) async {
  final vars = extractVariables(command);
  if (vars.isNotEmpty) {
    final values = await showVariableInputDialog(context, vars);
    if (values == null) return;
    command = substituteVariables(command, values);
  }

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => _CommandResultSheet(command: command),
  );
}

class _CommandResultSheet extends StatefulWidget {
  final String command;
  const _CommandResultSheet({required this.command});

  @override
  State<_CommandResultSheet> createState() => _CommandResultSheetState();
}

class _CommandResultSheetState extends State<_CommandResultSheet> {
  List<ConnectionModel> _connections = [];
  ConnectionModel? _selected;
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final conns = await DatabaseHelper.instance.getConnections();
    setState(() => _connections = conns);
  }

  Future<void> _execute() async {
    if (_selected == null) return;
    setState(() { _loading = true; _result = null; _error = null; });

    final ssh = DartSshService();
    try {
      await ssh.connect(
        host: _selected!.host,
        port: _selected!.port,
        username: _selected!.username,
        password: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
      );
      final session = await ssh.execute(widget.command);
      setState(() => _result = session);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      ssh.dispose();
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Execute: ${widget.command}',
              style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<ConnectionModel>(
            dropdownColor: AppColors.surface,
            decoration: const InputDecoration(
              labelText: 'Select Server',
              labelStyle: TextStyle(color: AppColors.onSurface),
              border: OutlineInputBorder(),
            ),
            items: _connections.map((c) => DropdownMenuItem(
              value: c,
              child: Text('${c.name ?? c.host}:${c.port}',
                  style: const TextStyle(color: AppColors.onSurface)),
            )).toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: const InputDecoration(
              labelText: 'Password (if required)',
              labelStyle: TextStyle(color: AppColors.onSurface),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(
            onPressed: _loading || _selected == null ? null : _execute,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Execute'),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(
                  _result!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.onSurface),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
