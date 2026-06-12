import 'package:flutter/material.dart';

import '../../domain/utils/ctrl_key_helper.dart';

/// Mixin providing Ctrl modifier toggle logic for terminal keyboard bars.
mixin CtrlModifier<T extends StatefulWidget> on State<T> {
  bool isCtrlActive = false;

  void toggleCtrl() {
    setState(() => isCtrlActive = !isCtrlActive);
  }

  /// Transforms input if Ctrl is active. Returns the transformed string.
  /// Auto-deactivates Ctrl after use.
  String applyCtrlModifier(String input) {
    if (!isCtrlActive || input.isEmpty) return input;
    final result = ctrlChar(input);
    setState(() => isCtrlActive = false);
    return result;
  }
}
