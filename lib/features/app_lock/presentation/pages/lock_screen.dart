import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/app_lock_cubit.dart';
import '../widgets/pin_pad.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _localAuth = LocalAuthentication();
  String? _error;
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppLockCubit>().state;
    if (state is AppLockSetup) {
      _showPin = true;
    } else {
      _attemptBiometric();
    }
  }

  Future<void> _attemptBiometric() async {
    try {
      final available = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!available) {
        setState(() => _showPin = true);
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock SSHKU',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (authenticated && mounted) {
        context.read<AppLockCubit>().unlock();
      } else {
        setState(() => _showPin = true);
      }
    } catch (_) {
      setState(() => _showPin = true);
    }
  }

  Future<void> _onPinSubmit(String pin) async {
    final cubit = context.read<AppLockCubit>();
    if (cubit.state is AppLockSetup) {
      await cubit.setPin(pin);
    } else {
      final success = await cubit.verifyPin(pin);
      if (!success) {
        setState(() => _error = 'Incorrect PIN');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = context.read<AppLockCubit>().state is AppLockSetup;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                isSetup ? 'Set your PIN' : 'Enter PIN to unlock',
                style: const TextStyle(
                  fontSize: 20,
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_showPin)
                PinPad(onSubmit: _onPinSubmit, error: _error)
              else
                Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => setState(() => _showPin = true),
                      child: const Text('Use PIN instead'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
