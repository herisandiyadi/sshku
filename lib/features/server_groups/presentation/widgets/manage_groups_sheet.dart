import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sshku/core/theme/app_colors.dart';
import 'package:sshku/core/theme/app_spacing.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';
import 'package:sshku/features/server_groups/presentation/cubit/server_groups_cubit.dart';
import 'package:sshku/features/server_groups/presentation/cubit/server_groups_state.dart';

const _groupColors = [
  'FF00BFA5', 'FF2196F3', 'FFFF9800', 'FFE91E63',
  'FF9C27B0', 'FF4CAF50', 'FFFF5722', 'FF607D8B',
];

class ManageGroupsSheet extends StatelessWidget {
  const ManageGroupsSheet({super.key});

  static Future<void> show(BuildContext context, ServerGroupsCubit cubit) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => BlocProvider.value(value: cubit, child: const ManageGroupsSheet()),
    );
  }

  void _addGroup(BuildContext context) {
    _showGroupDialog(context);
  }

  void _editGroup(BuildContext context, ServerGroupModel group) {
    _showGroupDialog(context, group: group);
  }

  void _showGroupDialog(BuildContext context, {ServerGroupModel? group}) {
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    String selectedColor = group?.color ?? _groupColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(group == null ? 'Add Group' : 'Edit Group',
              style: const TextStyle(color: AppColors.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: _groupColors.map((c) => GestureDetector(
                  onTap: () => setState(() => selectedColor = c),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(int.parse(c, radix: 16)),
                    child: selectedColor == c
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final cubit = context.read<ServerGroupsCubit>();
                if (group == null) {
                  cubit.addGroup(ServerGroupModel(name: name, color: selectedColor));
                } else {
                  cubit.updateGroup(ServerGroupModel(id: group.id, name: name, color: selectedColor, sortOrder: group.sortOrder));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerGroupsCubit, ServerGroupsState>(
      builder: (context, state) {
        final groups = state is ServerGroupsLoaded ? state.groups : <ServerGroupModel>[];
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Groups', style: TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: () => _addGroup(context)),
                ],
              ),
              const Divider(color: Colors.grey),
              ...groups.map((g) => ListTile(
                leading: CircleAvatar(radius: 12, backgroundColor: Color(int.parse(g.color ?? 'FF00BFA5', radix: 16))),
                title: Text(g.name, style: const TextStyle(color: AppColors.onSurface)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: () => _editGroup(context, g)),
                    IconButton(icon: const Icon(Icons.delete, size: 20, color: AppColors.error), onPressed: () => context.read<ServerGroupsCubit>().deleteGroup(g.id!)),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}
