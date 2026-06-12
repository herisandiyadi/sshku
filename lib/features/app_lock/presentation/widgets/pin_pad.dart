import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class PinPad extends StatefulWidget {
  final int maxLength;
  final ValueChanged<String> onSubmit;
  final String? error;

  const PinPad({
    super.key,
    this.maxLength = 6,
    required this.onSubmit,
    this.error,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _onDigit(String digit) {
    if (_pin.length >= widget.maxLength) return;
    setState(() => _pin += digit);
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onSubmit() {
    if (_pin.length >= 4) widget.onSubmit(_pin);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.maxLength, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length
                    ? AppColors.primary
                    : AppColors.surface,
                border: Border.all(color: AppColors.primary),
              ),
            );
          }),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(widget.error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        // Keypad
        ...List.generate(3, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (col) {
                final digit = '${row * 3 + col + 1}';
                return _key(digit, () => _onDigit(digit));
              }),
            ),
          );
        }),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _key('⌫', _onBackspace),
            _key('0', () => _onDigit('0')),
            _key('✓', _onSubmit, highlight: _pin.length >= 4),
          ],
        ),
      ],
    );
  }

  Widget _key(String label, VoidCallback onTap, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.lg,
        child: Container(
          width: 72,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlight ? AppColors.primary : AppColors.surface,
            borderRadius: AppBorderRadius.lg,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              color: highlight ? AppColors.onPrimary : AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
