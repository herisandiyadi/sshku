import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ssh_connection/data/models/connection_model.dart';

class ServerCard extends StatelessWidget {
  final ConnectionModel connection;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final bool isConnected;

  const ServerCard({
    super.key,
    required this.connection,
    this.onTap,
    this.onDelete,
    this.onLongPress,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = connection.name ?? connection.host;

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
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
                      '${connection.username}@${connection.host}:${connection.port}',
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
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  onSelected: (_) => onDelete?.call(),
                  itemBuilder: (_) => [
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
