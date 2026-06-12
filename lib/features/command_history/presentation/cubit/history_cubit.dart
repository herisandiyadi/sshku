import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/database_helper.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit() : super(HistoryInitial());

  Future<void> loadHistory() async {
    emit(HistoryLoading());
    try {
      final items = await DatabaseHelper.instance.getHistory();
      emit(HistoryLoaded(items));
    } catch (e) {
      emit(HistoryError(e.toString()));
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return loadHistory();
    try {
      final items = await DatabaseHelper.instance.searchHistory(query);
      emit(HistoryLoaded(items, searchQuery: query));
    } catch (e) {
      emit(HistoryError(e.toString()));
    }
  }

  Future<void> clearAll() async {
    await DatabaseHelper.instance.clearHistory();
    emit(HistoryLoaded([]));
  }
}
