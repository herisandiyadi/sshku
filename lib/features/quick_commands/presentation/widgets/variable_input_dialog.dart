import 'package:flutter/material.dart';

String _humanize(String name) => name
    .split('_')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

Future<Map<String, String>?> showVariableInputDialog(
  BuildContext context,
  List<String> variables,
) {
  final controllers = {for (final v in variables) v: TextEditingController()};
  final formKey = GlobalKey<FormState>();

  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Fill Variables'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: variables
                .map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: controllers[v],
                        decoration: InputDecoration(labelText: _humanize(v)),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, {for (final v in variables) v: controllers[v]!.text});
            }
          },
          child: const Text('Run'),
        ),
      ],
    ),
  );
}
