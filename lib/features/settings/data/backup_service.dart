import 'dart:convert';

import 'package:sshku/core/database/database_helper.dart';
import 'package:sshku/features/ssh_connection/data/models/connection_model.dart';
import 'package:sshku/features/ssh_connection/data/models/known_host_model.dart';
import 'package:sshku/features/quick_commands/data/models/snippet_model.dart';
import 'package:sshku/features/quick_commands/data/models/snippet_folder_model.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';
import 'package:sshku/features/ssh_keys/data/models/ssh_key_model.dart';
import 'package:sshku/features/command_history/data/models/history_model.dart';

class BackupService {
  final _db = DatabaseHelper.instance;

  Future<String> exportToJson() async {
    final connections = await _db.getConnections();
    final snippets = await _db.getSnippets();
    final folders = await _db.getSnippetFolders();
    final groups = await _db.getGroups();
    final keys = await _db.getKeys();
    final history = await _db.getHistory(limit: 99999);
    final knownHosts = await _getKnownHosts();

    final data = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'connections': connections.map((c) => c.toMap()).toList(),
      'snippets': snippets.map((s) => s.toMap()).toList(),
      'snippetFolders': folders.map((f) => f.toMap()).toList(),
      'serverGroups': groups.map((g) => g.toMap()).toList(),
      'sshKeys': keys.map((k) => k.toMap()).toList(),
      'commandHistory': history.map((h) => h.toMap()).toList(),
      'knownHosts': knownHosts,
    };

    return jsonEncode(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final db = await _db.database;

    await db.delete('connections');
    await db.delete('snippets');
    await db.delete('snippet_folders');
    await db.delete('server_groups');
    await db.delete('ssh_keys');
    await db.delete('command_history');
    await db.delete('known_hosts');

    final groups = (data['serverGroups'] as List?) ?? [];
    for (final g in groups) {
      await _db.insertGroup(ServerGroupModel.fromMap(Map<String, dynamic>.from(g)));
    }

    final folders = (data['snippetFolders'] as List?) ?? [];
    for (final f in folders) {
      await _db.insertSnippetFolder(SnippetFolderModel.fromMap(Map<String, dynamic>.from(f)));
    }

    final connections = (data['connections'] as List?) ?? [];
    for (final c in connections) {
      await _db.insertConnection(ConnectionModel.fromMap(Map<String, dynamic>.from(c)));
    }

    final snippets = (data['snippets'] as List?) ?? [];
    for (final s in snippets) {
      await _db.insertSnippet(SnippetModel.fromMap(Map<String, dynamic>.from(s)));
    }

    final keys = (data['sshKeys'] as List?) ?? [];
    for (final k in keys) {
      await _db.insertKey(SshKeyModel.fromMap(Map<String, dynamic>.from(k)));
    }

    final history = (data['commandHistory'] as List?) ?? [];
    for (final h in history) {
      await _db.insertHistory(HistoryModel.fromMap(Map<String, dynamic>.from(h)));
    }

    final knownHosts = (data['knownHosts'] as List?) ?? [];
    for (final kh in knownHosts) {
      await _db.insertKnownHost(KnownHostModel.fromMap(Map<String, dynamic>.from(kh)));
    }
  }

  Future<List<Map<String, dynamic>>> _getKnownHosts() async {
    final db = await _db.database;
    return db.query('known_hosts');
  }
}
