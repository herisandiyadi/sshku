import '../../data/models/snippet_model.dart';
import '../../data/models/snippet_folder_model.dart';

sealed class SnippetState {}

class SnippetInitial extends SnippetState {}

class SnippetLoading extends SnippetState {}

class SnippetLoaded extends SnippetState {
  final List<SnippetModel> snippets;
  final List<SnippetFolderModel> folders;
  final int? selectedFolderId;
  SnippetLoaded(this.snippets, {this.folders = const [], this.selectedFolderId});
}

class SnippetError extends SnippetState {
  final String message;
  SnippetError(this.message);
}
