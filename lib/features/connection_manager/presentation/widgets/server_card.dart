import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ssh_connection/data/models/connection_model.dart';

class ServerCard extends StatefulWidget {
  final ConnectionModel connection;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  const ServerCard({
    super.key,
    required this.connection,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onLongPress,
  });

  @override
  State<ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<ServerCard> {
  bool? _isReachable;

  @override
  void initState() {
    super.initState();
    _checkReachability();
  }

  Future<void> _checkReachability() async {
    try {
      final socket = await Socket.connect(
        widget.connection.host,
        widget.connection.port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      if (mounted) setState(() => _isReachable = true);
    } catch (_) {
      if (mounted) setState(() => _isReachable = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.connection.name ?? widget.connection.host;

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  displayName[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.onPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.onSurface,
                          ),
                    ),
                    Text(
                      '${widget.connection.username}@${widget.connection.host}:${widget.connection.port}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (_isReachable) {
                    true => Colors.green,
                    false => Colors.red,
                    null => Colors.grey,
                  },
                ),
              ),
              if (widget.onDelete != null || widget.onEdit != null)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') widget.onEdit?.call();
                    if (v == 'delete') widget.onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (widget.onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (widget.onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
