import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum HostKeyDialogType { firstConnection, keyChanged }

class HostKeyDialog extends StatelessWidget {
  final String host;
  final int port;
  final String fingerprint;
  final String? keyType;
  final HostKeyDialogType type;

  const HostKeyDialog({
    super.key,
    required this.host,
    required this.port,
    required this.fingerprint,
    this.keyType,
    required this.type,
  });

  static Future<bool> show(
    BuildContext context, {
    required String host,
    required int port,
    required String fingerprint,
    String? keyType,
    required HostKeyDialogType type,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HostKeyDialog(
        host: host,
        port: port,
        fingerprint: fingerprint,
        keyType: keyType,
        type: type,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isChanged = type == HostKeyDialogType.keyChanged;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        isChanged ? '⚠️ HOST KEY CHANGED!' : 'New Host Key',
        style: TextStyle(
          color: isChanged ? AppColors.error : AppColors.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isChanged)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'WARNING: The host key has changed since last connection. '
                'This could indicate a man-in-the-middle attack!',
                style: TextStyle(color: AppColors.error),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'First connection to this host. Verify the fingerprint:',
                style: TextStyle(color: AppColors.onSurface),
              ),
            ),
          Text('Host: $host:$port',
              style: const TextStyle(color: AppColors.onSurface)),
          if (keyType != null)
            Text('Key type: $keyType',
                style: const TextStyle(color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              fingerprint,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Reject'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isChanged ? AppColors.error : AppColors.primary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isChanged ? 'Accept Anyway' : 'Accept'),
        ),
      ],
    );
  }
}
