import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../data/models/snippet_model.dart';
import '../../data/models/snippet_folder_model.dart';
import '../cubit/snippet_cubit.dart';
import '../cubit/snippet_state.dart';
import '../widgets/command_result_sheet.dart';
import '../widgets/snippet_form_dialog.dart';

class QuickCommandsPage extends StatelessWidget {
  const QuickCommandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SnippetCubit()..loadSnippets(),
      child: const _QuickCommandsView(),
    );
  }
}

class _QuickCommandsView extends StatelessWidget {
  const _QuickCommandsView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SnippetCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Commands'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showAddFolderDialog(context, cubit),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final state = cubit.state;
              final folders = state is SnippetLoaded ? state.folders : <SnippetFolderModel>[];
              final result = await showSnippetFormDialog(context, folders: folders);
              if (result != null) cubit.addSnippet(result);
            },
          ),
        ],
      ),
      body: BlocBuilder<SnippetCubit, SnippetState>(
        builder: (context, state) {
          if (state is SnippetLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (state is SnippetError) {
            return ErrorStateWidget(
              message: state.message,
              onRetry: () => context.read<SnippetCubit>().loadSnippets(),
            );
          }
          if (state is SnippetLoaded) {
            return Column(
              children: [
                _FolderChips(folders: state.folders, selectedId: state.selectedFolderId),
                Expanded(
                  child: state.snippets.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.code,
                          title: 'No commands',
                          subtitle: 'Create command snippets for quick execution',
                        )
                      : _ReorderableSnippetList(snippets: state.snippets),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context, SnippetCubit cubit) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                cubit.addFolder(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _FolderChips extends StatelessWidget {
  final List<SnippetFolderModel> folders;
  final int? selectedId;
  const _FolderChips({required this.folders, this.selectedId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SnippetCubit>();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selectedId == null,
              onSelected: (_) => cubit.selectFolder(null),
            ),
          ),
          ...folders.map((f) => Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: GestureDetector(
              onLongPress: () => _confirmDeleteFolder(context, cubit, f),
              child: ChoiceChip(
                label: Text(f.name),
                selected: selectedId == f.id,
                onSelected: (_) => cubit.selectFolder(f.id),
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, SnippetCubit cubit, SnippetFolderModel folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Delete "${folder.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              cubit.deleteFolder(folder.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ReorderableSnippetList extends StatelessWidget {
  final List<SnippetModel> snippets;
  const _ReorderableSnippetList({required this.snippets});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SnippetCubit>();
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: snippets.length,
      onReorder: cubit.reorderSnippet,
      itemBuilder: (context, i) {
        final snippet = snippets[i];
        return Dismissible(
          key: ValueKey(snippet.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.md),
            color: AppColors.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => cubit.deleteSnippet(snippet.id!),
          child: Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              title: Text(snippet.title),
              subtitle: Text(snippet.command, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.drag_handle),
              onTap: () => showCommandResultSheet(context, snippet.command),
              onLongPress: () async {
                final state = cubit.state;
                final folders = state is SnippetLoaded ? state.folders : <SnippetFolderModel>[];
                final result = await showSnippetFormDialog(context, snippet: snippet, folders: folders);
                if (result != null) cubit.updateSnippet(result);
              },
            ),
          ),
        );
      },
    );
  }
}
