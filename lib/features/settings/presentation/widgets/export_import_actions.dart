import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sshku/features/settings/data/backup_service.dart';

Future<void> exportConfig(BuildContext context) async {
  try {
    final json = await BackupService().exportToJson();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/sshku_backup_$timestamp.json');
    await file.writeAsString(json);

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: 'sshku_backup_$timestamp.json',
      bytes: file.readAsBytesSync(),
    );

    await file.delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result != null ? 'Backup exported successfully' : 'Export cancelled')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

Future<void> importConfig(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final json = await file.readAsString();

    await BackupService().importFromJson(json);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup imported successfully')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}
