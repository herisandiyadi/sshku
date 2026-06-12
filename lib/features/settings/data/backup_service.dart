import 'dart:convert';

import 'package:sshku/core/database/database_helper.dart';
import 'package:sshku/features/ssh_connection/data/models/connection_model.dart';
import 'package:sshku/features/quick_commands/data/models/snippet_model.dart';
import 'package:sshku/features/quick_commands/data/models/snippet_folder_model.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';

class BackupService {
  final _db = DatabaseHelper.instance;

  Future<String> exportToJson() async {
    final connections = await _db.getConnections();
    final snippets = await _db.getSnippets();
    final folders = await _db.getSnippetFolders();
    final groups = await _db.getGroups();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'connections': connections.map((c) => c.toMap()).toList(),
      'snippets': snippets.map((s) => s.toMap()).toList(),
      'snippetFolders': folders.map((f) => f.toMap()).toList(),
      'serverGroups': groups.map((g) => g.toMap()).toList(),
    };

    return jsonEncode(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    final db = await _db.database;

    // Clear existing data (replace strategy)
    await db.delete('connections');
    await db.delete('snippets');
    await db.delete('snippet_folders');
    await db.delete('server_groups');

    // Insert groups first (connections reference them)
    final groups = (data['serverGroups'] as List?) ?? [];
    for (final g in groups) {
      await _db.insertGroup(ServerGroupModel.fromMap(Map<String, dynamic>.from(g)));
    }

    // Insert snippet folders
    final folders = (data['snippetFolders'] as List?) ?? [];
    for (final f in folders) {
      await _db.insertSnippetFolder(SnippetFolderModel.fromMap(Map<String, dynamic>.from(f)));
    }

    // Insert connections
    final connections = (data['connections'] as List?) ?? [];
    for (final c in connections) {
      await _db.insertConnection(ConnectionModel.fromMap(Map<String, dynamic>.from(c)));
    }

    // Insert snippets
    final snippets = (data['snippets'] as List?) ?? [];
    for (final s in snippets) {
      await _db.insertSnippet(SnippetModel.fromMap(Map<String, dynamic>.from(s)));
    }
  }
}
