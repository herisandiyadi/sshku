import '../../data/models/history_model.dart';

abstract class HistoryState {}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<HistoryModel> items;
  final String? searchQuery;

  HistoryLoaded(this.items, {this.searchQuery});
}

class HistoryError extends HistoryState {
  final String message;
  HistoryError(this.message);
}
