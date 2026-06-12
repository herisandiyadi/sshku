import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../data/models/history_model.dart';
import '../cubit/history_cubit.dart';
import '../cubit/history_state.dart';

class HistoryPage extends StatelessWidget {
  final void Function(String command)? onReplay;
  const HistoryPage({super.key, this.onReplay});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryCubit()..loadHistory(),
      child: _HistoryView(onReplay: onReplay),
    );
  }
}

class _HistoryView extends StatefulWidget {
  final void Function(String command)? onReplay;
  const _HistoryView({this.onReplay});

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search commands...', border: InputBorder.none),
                onChanged: (q) => context.read<HistoryCubit>().search(q),
              )
            : const Text('History'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchController.clear();
                context.read<HistoryCubit>().loadHistory();
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') context.read<HistoryCubit>().clearAll();
            },
            itemBuilder: (_) => [const PopupMenuItem(value: 'clear', child: Text('Clear All'))],
          ),
        ],
      ),
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          if (state is HistoryLoading || state is HistoryInitial) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (state is HistoryError) {
            return ErrorStateWidget(
              message: state.message,
              onRetry: () => context.read<HistoryCubit>().loadHistory(),
            );
          }
          if (state is! HistoryLoaded) return const SizedBox.shrink();
          if (state.items.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history,
              title: 'No history yet',
              subtitle: 'Commands you run will appear here',
            );
          }
          return ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (context, i) => _HistoryTile(
              item: state.items[i],
              onTap: () => widget.onReplay?.call(state.items[i].command),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryModel item;
  final VoidCallback onTap;
  const _HistoryTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.command, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([if (item.serverHost != null) item.serverHost!, _timeAgo(item.executedAt)].join(' • ')),
      onTap: onTap,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: item.command));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
      },
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(iso));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
