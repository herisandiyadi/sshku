import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sshku/features/ssh_connection/data/models/connection_model.dart';
import 'package:sshku/features/ssh_connection/data/models/known_host_model.dart';
import 'package:sshku/features/quick_commands/data/models/snippet_model.dart';
import 'package:sshku/features/quick_commands/data/models/snippet_folder_model.dart';
import 'package:sshku/features/ssh_keys/data/models/ssh_key_model.dart';
import 'package:sshku/features/command_history/data/models/history_model.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'sshku.db');
    return openDatabase(path, version: 7, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createServerGroupsTable(db);
    await db.execute('''
      CREATE TABLE connections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        host TEXT NOT NULL,
        port INTEGER DEFAULT 22,
        username TEXT NOT NULL,
        auth_type TEXT,
        key_id INTEGER,
        created_at TEXT,
        group_id INTEGER REFERENCES server_groups(id)
      )
    ''');
    await _createSnippetTables(db);
    await _createCommandHistoryTable(db);
    await _createSshKeysTable(db);
    await _createKnownHostsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSnippetTables(db);
    }
    if (oldVersion < 3) {
      await _createCommandHistoryTable(db);
    }
    if (oldVersion < 4) {
      await _createSshKeysTable(db);
    }
    if (oldVersion < 5) {
      await _createServerGroupsTable(db);
      await db.execute('ALTER TABLE connections ADD COLUMN group_id INTEGER REFERENCES server_groups(id)');
    }
    if (oldVersion < 6) {
      await _createKnownHostsTable(db);
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE connections ADD COLUMN key_id INTEGER');
    }
  }

  Future<void> _createSshKeysTable(Database db) async {
    await db.execute('''
      CREATE TABLE ssh_keys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        public_key TEXT NOT NULL,
        encrypted_private_key TEXT NOT NULL,
        created_at TEXT
      )
    ''');
  }

  Future<void> _createCommandHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE command_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        command TEXT NOT NULL,
        server_host TEXT,
        executed_at TEXT
      )
    ''');
  }

  Future<void> _createSnippetTables(Database db) async {
    await db.execute('''
      CREATE TABLE snippet_folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE snippets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_id INTEGER REFERENCES snippet_folders(id),
        title TEXT NOT NULL,
        command TEXT NOT NULL,
        description TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
  }

  // Connection CRUD
  Future<int> insertConnection(ConnectionModel connection) async {
    final db = await database;
    return db.insert('connections', connection.toMap());
  }

  Future<List<ConnectionModel>> getConnections() async {
    final db = await database;
    final maps = await db.query('connections');
    return maps.map((m) => ConnectionModel.fromMap(m)).toList();
  }

  Future<ConnectionModel?> getConnectionById(int id) async {
    final db = await database;
    final maps = await db.query('connections', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ConnectionModel.fromMap(maps.first);
  }

  Future<int> updateConnection(ConnectionModel connection) async {
    final db = await database;
    return db.update('connections', connection.toMap(), where: 'id = ?', whereArgs: [connection.id]);
  }

  Future<int> deleteConnection(int id) async {
    final db = await database;
    return db.delete('connections', where: 'id = ?', whereArgs: [id]);
  }

  // SnippetFolder CRUD
  Future<int> insertSnippetFolder(SnippetFolderModel folder) async {
    final db = await database;
    return db.insert('snippet_folders', folder.toMap());
  }

  Future<List<SnippetFolderModel>> getSnippetFolders() async {
    final db = await database;
    final maps = await db.query('snippet_folders', orderBy: 'sort_order');
    return maps.map((m) => SnippetFolderModel.fromMap(m)).toList();
  }

  Future<int> deleteSnippetFolder(int id) async {
    final db = await database;
    return db.delete('snippet_folders', where: 'id = ?', whereArgs: [id]);
  }

  // Snippet CRUD
  Future<int> insertSnippet(SnippetModel snippet) async {
    final db = await database;
    return db.insert('snippets', snippet.toMap());
  }

  Future<List<SnippetModel>> getSnippets() async {
    final db = await database;
    final maps = await db.query('snippets', orderBy: 'sort_order');
    return maps.map((m) => SnippetModel.fromMap(m)).toList();
  }

  Future<List<SnippetModel>> getSnippetsByFolder(int folderId) async {
    final db = await database;
    final maps = await db.query('snippets', where: 'folder_id = ?', whereArgs: [folderId], orderBy: 'sort_order');
    return maps.map((m) => SnippetModel.fromMap(m)).toList();
  }

  Future<int> updateSnippet(SnippetModel snippet) async {
    final db = await database;
    return db.update('snippets', snippet.toMap(), where: 'id = ?', whereArgs: [snippet.id]);
  }

  Future<int> deleteSnippet(int id) async {
    final db = await database;
    return db.delete('snippets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSnippetOrder(int id, int sortOrder) async {
    final db = await database;
    await db.update('snippets', {'sort_order': sortOrder}, where: 'id = ?', whereArgs: [id]);
  }

  // Command History
  Future<int> insertHistory(HistoryModel history) async {
    final db = await database;
    return db.insert('command_history', history.toMap());
  }

  Future<List<HistoryModel>> getHistory({int limit = 50, int offset = 0}) async {
    final db = await database;
    final maps = await db.query('command_history', orderBy: 'id DESC', limit: limit, offset: offset);
    return maps.map((m) => HistoryModel.fromMap(m)).toList();
  }

  Future<List<HistoryModel>> searchHistory(String query) async {
    final db = await database;
    final maps = await db.query('command_history', where: 'command LIKE ?', whereArgs: ['%$query%'], orderBy: 'id DESC');
    return maps.map((m) => HistoryModel.fromMap(m)).toList();
  }

  Future<int> clearHistory() async {
    final db = await database;
    return db.delete('command_history');
  }

  // SSH Keys CRUD
  Future<int> insertKey(SshKeyModel key) async {
    final db = await database;
    return db.insert('ssh_keys', key.toMap());
  }

  Future<List<SshKeyModel>> getKeys() async {
    final db = await database;
    final maps = await db.query('ssh_keys', orderBy: 'id DESC');
    return maps.map((m) => SshKeyModel.fromMap(m)).toList();
  }

  Future<int> deleteKey(int id) async {
    final db = await database;
    return db.delete('ssh_keys', where: 'id = ?', whereArgs: [id]);
  }

  // Server Groups
  Future<void> _createServerGroupsTable(Database db) async {
    await db.execute('''
      CREATE TABLE server_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT,
        sort_order INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> insertGroup(ServerGroupModel group) async {
    final db = await database;
    return db.insert('server_groups', group.toMap());
  }

  Future<List<ServerGroupModel>> getGroups() async {
    final db = await database;
    final maps = await db.query('server_groups', orderBy: 'sort_order');
    return maps.map((m) => ServerGroupModel.fromMap(m)).toList();
  }

  Future<int> updateGroup(ServerGroupModel group) async {
    final db = await database;
    return db.update('server_groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<int> deleteGroup(int id) async {
    final db = await database;
    await db.update('connections', {'group_id': null}, where: 'group_id = ?', whereArgs: [id]);
    return db.delete('server_groups', where: 'id = ?', whereArgs: [id]);
  }

  // Known Hosts
  Future<void> _createKnownHostsTable(Database db) async {
    await db.execute('''
      CREATE TABLE known_hosts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        host TEXT NOT NULL,
        port INTEGER,
        fingerprint TEXT NOT NULL,
        key_type TEXT,
        first_seen TEXT
      )
    ''');
  }

  Future<int> insertKnownHost(KnownHostModel knownHost) async {
    final db = await database;
    return db.insert('known_hosts', knownHost.toMap());
  }

  Future<KnownHostModel?> getKnownHost(String host, int port) async {
    final db = await database;
    final maps = await db.query('known_hosts', where: 'host = ? AND port = ?', whereArgs: [host, port]);
    if (maps.isEmpty) return null;
    return KnownHostModel.fromMap(maps.first);
  }

  Future<int> updateKnownHost(KnownHostModel knownHost) async {
    final db = await database;
    return db.update('known_hosts', knownHost.toMap(), where: 'id = ?', whereArgs: [knownHost.id]);
  }
}
