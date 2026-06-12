import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'ctrl_modifier.dart';

class TerminalKeyboardBar extends StatefulWidget {
  final ValueChanged<String> onKeyPress;

  const TerminalKeyboardBar({super.key, required this.onKeyPress});

  @override
  TerminalKeyboardBarState createState() => TerminalKeyboardBarState();
}

class TerminalKeyboardBarState extends State<TerminalKeyboardBar>
    with CtrlModifier {
  void deactivateCtrl() {
    if (isCtrlActive) setState(() => isCtrlActive = false);
  }

  void _handleKeyPress(String sequence) {
    widget.onKeyPress(applyCtrlModifier(sequence));
  }

  static const _keys = <String, String>{
    'Esc': '\x1B',
    'Tab': '\t',
    '↑': '\x1B[A',
    '↓': '\x1B[B',
    '←': '\x1B[D',
    '→': '\x1B[C',
    '|': '|',
    '/': '/',
    '-': '-',
    '~': '~',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCtrlKey(),
            ..._keys.entries.map((e) => _buildKey(e.key, () {
              _handleKeyPress(e.value);
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCtrlKey() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: toggleCtrl,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isCtrlActive ? AppColors.primary : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Ctrl',
            style: TextStyle(
              color: isCtrlActive ? AppColors.onPrimary : AppColors.primary,
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: isCtrlActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
