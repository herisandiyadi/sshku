import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/database_helper.dart';
import '../../data/models/snippet_model.dart';
import '../../data/models/snippet_folder_model.dart';
import 'snippet_state.dart';

class SnippetCubit extends Cubit<SnippetState> {
  final _db = DatabaseHelper.instance;
  int? _selectedFolderId;

  SnippetCubit() : super(SnippetInitial());

  Future<void> loadSnippets() async {
    emit(SnippetLoading());
    try {
      final folders = await _db.getSnippetFolders();
      final snippets = _selectedFolderId == null
          ? await _db.getSnippets()
          : await _db.getSnippetsByFolder(_selectedFolderId!);
      emit(SnippetLoaded(snippets, folders: folders, selectedFolderId: _selectedFolderId));
    } catch (e) {
      emit(SnippetError(e.toString()));
    }
  }

  Future<void> selectFolder(int? folderId) async {
    _selectedFolderId = folderId;
    await loadSnippets();
  }

  Future<void> addFolder(String name) async {
    try {
      await _db.insertSnippetFolder(SnippetFolderModel(name: name));
      await loadSnippets();
    } catch (e) {
      emit(SnippetError(e.toString()));
    }
  }

  Future<void> deleteFolder(int id) async {
    try {
      await _db.deleteSnippetFolder(id);
      if (_selectedFolderId == id) _selectedFolderId = null;
      await loadSnippets();
    } catch (e) {
      emit(SnippetError(e.toString()));
    }
  }

  Future<void> addSnippet(SnippetModel snippet) async {
    try {
      await _db.insertSnippet(snippet);
      await loadSnippets();
    } catch (e) {
      emit(SnippetError(e.toString()));
    }
  }

  Future<void> updateSnippet(SnippetModel snippet) async {
    try {
      await _db.updateSnippet(snippet);
      await loadSnippets();
    } catch (e) {
      emit(SnippetError(e.toString()));
    }
  }

  Future<void> deleteSnippet(int id) async {
    try {
      await _db.deleteSnippet(id);
      await loadSnippets();
    } catch (e) {
      emit(SnippetError(e.toString()));
    }
  }

  Future<void> reorderSnippet(int oldIndex, int newIndex) async {
    if (state is! SnippetLoaded) return;
    final current = (state as SnippetLoaded).snippets.toList();
    if (newIndex > oldIndex) newIndex--;
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    try {
      for (var i = 0; i < current.length; i++) {
        await _db.updateSnippetOrder(current[i].id!, i);
      }
      await loadSnippets();
    } catch (e) {
      emit(SnippetError(e.toString()));
    }
  }
}
