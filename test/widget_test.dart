import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/core/theme/app_theme.dart';
import 'package:sshku/features/app_lock/presentation/widgets/pin_pad.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App theme is dark', (WidgetTester tester) async {
    final theme = AppTheme.darkTheme();
    expect(theme.brightness, Brightness.dark);
  });

  testWidgets('PinPad renders digits', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PinPad(onSubmit: (_) {})),
    ));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });
}
