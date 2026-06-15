import 'package:flutter/material.dart';
import 'package:sshku/core/database/database_helper.dart';
import 'package:sshku/core/theme/app_colors.dart';
import 'package:sshku/core/theme/app_spacing.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';
import 'package:sshku/features/ssh_connection/data/models/connection_model.dart';
import 'package:sshku/features/ssh_keys/data/models/ssh_key_model.dart';

import '../widgets/test_connection_button.dart';

class AddEditServerPage extends StatefulWidget {
  final ConnectionModel? connection;
  const AddEditServerPage({super.key, this.connection});

  @override
  State<AddEditServerPage> createState() => _AddEditServerPageState();
}

class _AddEditServerPageState extends State<AddEditServerPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passwordCtrl;
  String _authType = 'password';
  int? _selectedGroupId;
  int? _selectedKeyId;
  List<ServerGroupModel> _groups = [];
  List<SshKeyModel> _keys = [];

  bool get _isEdit => widget.connection != null;

  @override
  void initState() {
    super.initState();
    final c = widget.connection;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _hostCtrl = TextEditingController(text: c?.host ?? '');
    _portCtrl = TextEditingController(text: '${c?.port ?? 22}');
    _userCtrl = TextEditingController(text: c?.username ?? '');
    _passwordCtrl = TextEditingController();
    _authType = c?.authType ?? 'password';
    _selectedGroupId = c?.groupId;
    _selectedKeyId = c?.keyId;
    _loadGroups();
    _loadKeys();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await DatabaseHelper.instance.getGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {}
  }

  Future<void> _loadKeys() async {
    try {
      final keys = await DatabaseHelper.instance.getKeys();
      if (mounted) setState(() => _keys = keys);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final model = ConnectionModel(
      id: widget.connection?.id,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text) ?? 22,
      username: _userCtrl.text.trim(),
      authType: _authType,
      keyId: _authType == 'key' ? _selectedKeyId : null,
      createdAt: widget.connection?.createdAt,
      groupId: _selectedGroupId,
    );
    final db = DatabaseHelper.instance;
    if (_isEdit) {
      await db.updateConnection(model);
    } else {
      await db.insertConnection(model);
    }
    if (mounted) Navigator.pop(context, true);
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.7)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.onSurface.withValues(alpha: 0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Server' : 'Add Server'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _decoration('Name (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _hostCtrl,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _decoration('Host'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Host is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _portCtrl,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _decoration('Port'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final port = int.tryParse(v ?? '');
                return (port == null || port <= 0) ? 'Port must be > 0' : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _userCtrl,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _decoration('Username'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int?>(
              initialValue: _selectedGroupId,
              dropdownColor: AppColors.surface,
              decoration: _decoration('Group (optional)'),
              style: const TextStyle(color: AppColors.onSurface),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ..._groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
              ],
              onChanged: (v) => setState(() => _selectedGroupId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'password', label: Text('Password')),
                ButtonSegment(value: 'key', label: Text('Key')),
              ],
              selected: {_authType},
              onSelectionChanged: (v) => setState(() => _authType = v.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ),
            if (_authType == 'password') ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordCtrl,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: _decoration('Password'),
                obscureText: true,
              ),
            ],
            if (_authType == 'key') ...[
              const SizedBox(height: AppSpacing.md),
              if (_keys.isEmpty)
                const Text(
                  'No SSH keys imported. Go to Keys tab to add one.',
                  style: TextStyle(color: AppColors.error),
                )
              else
                DropdownButtonFormField<int?>(
                  value: _selectedKeyId,
                  dropdownColor: AppColors.surface,
                  decoration: _decoration('SSH Key'),
                  style: const TextStyle(color: AppColors.onSurface),
                  items: _keys.map((k) => DropdownMenuItem(
                    value: k.id,
                    child: Text('${k.name} (${k.type})'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedKeyId = v),
                  validator: (v) => v == null ? 'Select an SSH key' : null,
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TestConnectionButton(
              host: _hostCtrl.text,
              port: int.tryParse(_portCtrl.text) ?? 22,
              username: _userCtrl.text,
              password: _authType == 'password' ? _passwordCtrl.text : null,
              keyId: _authType == 'key' ? _selectedKeyId : null,
            ),
          ],
        ),
      ),
    );
  }
}
