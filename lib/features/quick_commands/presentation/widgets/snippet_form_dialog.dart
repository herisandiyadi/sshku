import 'package:flutter/material.dart';
import '../../data/models/snippet_model.dart';
import '../../data/models/snippet_folder_model.dart';

Future<SnippetModel?> showSnippetFormDialog(
  BuildContext context, {
  SnippetModel? snippet,
  List<SnippetFolderModel> folders = const [],
}) {
  final titleCtrl = TextEditingController(text: snippet?.title ?? '');
  final commandCtrl = TextEditingController(text: snippet?.command ?? '');
  final descCtrl = TextEditingController(text: snippet?.description ?? '');
  final formKey = GlobalKey<FormState>();
  int? selectedFolderId = snippet?.folderId;

  return showDialog<SnippetModel>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(snippet == null ? 'Add Snippet' : 'Edit Snippet'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: commandCtrl,
                  decoration: const InputDecoration(labelText: 'Command'),
                  maxLines: 4,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                if (folders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedFolderId,
                    decoration: const InputDecoration(labelText: 'Folder'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                    ],
                    onChanged: (v) => setState(() => selectedFolderId = v),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  ctx,
                  SnippetModel(
                    id: snippet?.id,
                    folderId: selectedFolderId,
                    title: titleCtrl.text,
                    command: commandCtrl.text,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    sortOrder: snippet?.sortOrder ?? 0,
                    createdAt: snippet?.createdAt,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
