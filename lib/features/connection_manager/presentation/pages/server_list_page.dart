import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sshku/core/theme/app_colors.dart';
import 'package:sshku/core/theme/app_spacing.dart';
import 'package:sshku/core/widgets/empty_state_widget.dart';
import 'package:sshku/core/widgets/error_state_widget.dart';
import 'package:sshku/features/connection_manager/presentation/cubit/server_list_cubit.dart';
import 'package:sshku/features/connection_manager/presentation/cubit/server_list_state.dart';
import 'package:sshku/features/connection_manager/presentation/pages/add_edit_server_page.dart';
import 'package:sshku/features/connection_manager/presentation/widgets/server_card.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';
import 'package:sshku/features/server_groups/presentation/cubit/server_groups_cubit.dart';
import 'package:sshku/features/server_groups/presentation/cubit/server_groups_state.dart';
import 'package:sshku/features/server_groups/presentation/widgets/manage_groups_sheet.dart';
import 'package:sshku/features/terminal/presentation/pages/terminal_page.dart';

class ServerListPage extends StatelessWidget {
  const ServerListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ServerListCubit()..loadServers()),
        BlocProvider(create: (_) => ServerGroupsCubit()..loadGroups()),
      ],
      child: const _ServerListView(),
    );
  }
}

class _ServerListView extends StatefulWidget {
  const _ServerListView();

  @override
  State<_ServerListView> createState() => _ServerListViewState();
}

class _ServerListViewState extends State<_ServerListView> {
  int? _selectedGroupId;

  Future<void> _navigateToAdd(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditServerPage()),
    );
    if (result == true && context.mounted) {
      context.read<ServerListCubit>().loadServers();
    }
  }

  Future<void> _navigateToEdit(BuildContext context, connection) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditServerPage(connection: connection)),
    );
    if (result == true && context.mounted) {
      context.read<ServerListCubit>().loadServers();
    }
  }

  void _navigateToTerminal(BuildContext context, connection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TerminalPage(
          host: connection.host,
          port: connection.port,
          username: connection.username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSHKU'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'manage_groups', child: Text('Manage Groups')),
            ],
            onSelected: (v) {
              if (v == 'manage_groups') {
                ManageGroupsSheet.show(context, context.read<ServerGroupsCubit>());
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGroupChips(),
          Expanded(
            child: BlocBuilder<ServerListCubit, ServerListState>(
              builder: (context, state) {
                if (state is ServerListLoading) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }
                if (state is ServerListError) {
                  return ErrorStateWidget(
                    message: state.message,
                    onRetry: () => context.read<ServerListCubit>().loadServers(),
                  );
                }
                if (state is ServerListLoaded) {
                  final connections = _selectedGroupId == null
                      ? state.connections
                      : state.connections.where((c) => c.groupId == _selectedGroupId).toList();
                  if (connections.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.dns_outlined,
                      title: 'No servers',
                      subtitle: 'Tap + to add your first server',
                      actionLabel: 'Add Server',
                      onAction: () => _navigateToAdd(context),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: connections.length,
                    itemBuilder: (context, index) {
                      final conn = connections[index];
                      return ServerCard(
                        connection: conn,
                        onTap: () => _navigateToTerminal(context, conn),
                        onLongPress: () => _navigateToEdit(context, conn),
                        onDelete: () {
                          if (conn.id != null) {
                            context.read<ServerListCubit>().deleteServer(conn.id!);
                          }
                        },
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _navigateToAdd(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupChips() {
    return BlocBuilder<ServerGroupsCubit, ServerGroupsState>(
      builder: (context, state) {
        final groups = state is ServerGroupsLoaded ? state.groups : <ServerGroupModel>[];
        if (groups.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              _chip('All', null),
              ...groups.map((g) => _chip(g.name, g.id, color: g.color)),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, int? groupId, {String? color}) {
    final selected = _selectedGroupId == groupId;
    final chipColor = color != null ? Color(int.parse(color, radix: 16)) : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: chipColor.withValues(alpha: 0.3),
        checkmarkColor: chipColor,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(color: selected ? chipColor : AppColors.onSurface),
        onSelected: (_) => setState(() => _selectedGroupId = groupId),
      ),
    );
  }
}
