import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/app_lock/presentation/cubit/app_lock_cubit.dart';
import 'features/app_lock/presentation/pages/lock_screen.dart';
import 'features/connection_manager/presentation/pages/server_list_page.dart';
import 'features/quick_commands/presentation/pages/quick_commands_page.dart';
import 'features/command_history/presentation/pages/history_page.dart';
import 'features/ssh_keys/presentation/pages/ssh_keys_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const SshkuApp());
}

class SshkuApp extends StatelessWidget {
  const SshkuApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppLockCubit()..checkLock()),
        BlocProvider(create: (_) => SettingsCubit()..load()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp(
            title: 'SSHKU',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: settings.themeMode,
            home: const _AppGate(),
          );
        },
      ),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppLockCubit, AppLockState>(
      builder: (context, state) {
        if (state is AppLockUnlocked) return const _MainShell();
        return const LockScreen();
      },
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;
  final _builtTabs = <int>{0}; // Only build tab 0 initially

  @override
  Widget build(BuildContext context) {
    _builtTabs.add(_index); // Mark current tab as built
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSHKU'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () => _showLockSettings(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const ServerListPage(),
          _builtTabs.contains(1) ? const QuickCommandsPage() : const SizedBox.shrink(),
          _builtTabs.contains(2) ? const HistoryPage() : const SizedBox.shrink(),
          _builtTabs.contains(3) ? const SshKeysPage() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Servers'),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Commands'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.vpn_key), label: 'Keys'),
        ],
      ),
    );
  }

  void _showLockSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _LockSettingsDialog(),
    );
  }
}

class _LockSettingsDialog extends StatefulWidget {
  const _LockSettingsDialog();
  @override
  State<_LockSettingsDialog> createState() => _LockSettingsDialogState();
}

class _LockSettingsDialogState extends State<_LockSettingsDialog> {
  bool _enabled = false;
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() => _enabled = prefs.getBool('lock_enabled') ?? false);
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('App Lock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Enable App Lock'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_enabled)
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Set PIN (4-6 digits)',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final cubit = context.read<AppLockCubit>();
            if (_enabled && _pinController.text.length >= 4) {
              await cubit.setPin(_pinController.text);
            } else if (!_enabled) {
              await cubit.toggleLock(false);
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
