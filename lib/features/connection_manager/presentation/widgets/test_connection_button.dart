import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/platform/dart_ssh_service.dart';
import '../../../../core/platform/keystore_platform_channel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ssh_connection/data/models/known_host_model.dart';
import '../../../ssh_connection/presentation/widgets/host_key_dialog.dart';

class TestConnectionButton extends StatefulWidget {
  final String host;
  final int port;
  final String username;
  final String? password;
  final int? keyId;

  const TestConnectionButton({
    super.key,
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.keyId,
  });

  @override
  State<TestConnectionButton> createState() => _TestConnectionButtonState();
}

enum _Status { idle, loading, success, failure }

class _TestConnectionButtonState extends State<TestConnectionButton> {
  _Status _status = _Status.idle;
  String? _errorMessage;

  Future<void> _testConnection() async {
    setState(() => _status = _Status.loading);
    final ssh = DartSshService();
    try {
      // Resolve private key if keyId provided
      String? privateKey;
      if (widget.keyId != null) {
        final keys = await DatabaseHelper.instance.getKeys();
        final key = keys.where((k) => k.id == widget.keyId).firstOrNull;
        if (key != null) {
          privateKey = await KeystorePlatformChannel().decrypt(key.encryptedPrivateKey);
        }
      }

      // Host key verification
      final hostKeyInfo = await ssh.getHostFingerprintMap(
        host: widget.host,
        port: widget.port,
      );
      final fingerprint = hostKeyInfo['fingerprint']!;
      final keyType = hostKeyInfo['keyType'];

      final knownHost = await DatabaseHelper.instance.getKnownHost(widget.host, widget.port);

      if (knownHost == null || knownHost.fingerprint != fingerprint) {
        if (!mounted) return;
        final accepted = await HostKeyDialog.show(
          context,
          host: widget.host,
          port: widget.port,
          fingerprint: fingerprint,
          keyType: keyType,
          type: knownHost == null
              ? HostKeyDialogType.firstConnection
              : HostKeyDialogType.keyChanged,
        );
        if (!accepted) {
          setState(() => _status = _Status.idle);
          return;
        }
        if (knownHost != null) {
          await DatabaseHelper.instance.updateKnownHost(KnownHostModel(
            id: knownHost.id,
            host: widget.host,
            port: widget.port,
            fingerprint: fingerprint,
            keyType: keyType,
            firstSeen: knownHost.firstSeen,
          ));
        } else {
          await DatabaseHelper.instance.insertKnownHost(KnownHostModel(
            host: widget.host,
            port: widget.port,
            fingerprint: fingerprint,
            keyType: keyType,
          ));
        }
      }

      await ssh.connect(
        host: widget.host,
        port: widget.port,
        username: widget.username,
        password: widget.password,
        privateKey: privateKey,
      );
      setState(() => _status = _Status.success);
      await ssh.close();
    } catch (e) {
      setState(() {
        _status = _Status.failure;
        _errorMessage = e.toString();
      });
    } finally {
      ssh.dispose();
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _status = _Status.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _Status.loading => const Center(child: CircularProgressIndicator()),
      _Status.success => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Connected!', style: TextStyle(color: Colors.green)),
          ],
        ),
      _Status.failure => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, color: AppColors.error),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _errorMessage ?? 'Connection failed',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      _Status.idle => ElevatedButton(
          onPressed: _testConnection,
          child: const Text('Test Connection'),
        ),
    };
  }
}
// 108.136.43.35
// ec2-user
