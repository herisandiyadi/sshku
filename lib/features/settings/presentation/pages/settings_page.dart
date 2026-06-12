import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_lock/presentation/cubit/app_lock_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/settings_cubit.dart';
import '../widgets/export_import_actions.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _lockEnabled = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _lockEnabled = prefs.getBool('lock_enabled') ?? false;
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsCubit = context.watch<SettingsCubit>();
    final settings = settingsCubit.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              onChanged: (mode) {
                if (mode != null) settingsCubit.setThemeMode(mode);
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Terminal Font Size'),
            subtitle: Slider(
              value: settings.terminalFontSize,
              min: 8,
              max: 24,
              divisions: 16,
              label: settings.terminalFontSize.round().toString(),
              onChanged: (v) => settingsCubit.setFontSize(v),
            ),
            trailing: Text('${settings.terminalFontSize.round()}'),
          ),
          _sectionHeader('Security'),
          SwitchListTile(
            secondary: const Icon(Icons.lock),
            title: const Text('App Lock'),
            value: _lockEnabled,
            onChanged: (v) async {
              if (v) {
                _showPinSetup();
              } else {
                await context.read<AppLockCubit>().toggleLock(false);
                setState(() => _lockEnabled = false);
              }
            },
          ),
          if (_lockEnabled)
            ListTile(
              leading: const Icon(Icons.pin),
              title: const Text('Change PIN'),
              onTap: _showPinSetup,
            ),
          _sectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export Config'),
            onTap: () => exportConfig(context),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Config'),
            onTap: () => importConfig(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.error),
            title: const Text('Clear All Data'),
            onTap: _confirmClearData,
          ),
          _sectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text(_version),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source Code'),
            subtitle: const Text('GitHub'),
            onTap: () => launchUrl(Uri.parse('https://github.com/sshku/sshku')),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  void _showPinSetup() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN (4-6 digits)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.length >= 4) {
                await context.read<AppLockCubit>().setPin(controller.text);
                setState(() => _lockEnabled = true);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will delete all servers, keys, and command history. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
