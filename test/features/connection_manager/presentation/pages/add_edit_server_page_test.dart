import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/connection_manager/presentation/pages/add_edit_server_page.dart';

Widget _buildSubject() {
  return const MaterialApp(home: AddEditServerPage());
}

void main() {
  group('AddEditServerPage', () {
    testWidgets('renders all form fields', (tester) async {
      await tester.pumpWidget(_buildSubject());

      expect(find.widgetWithText(TextFormField, 'Name (optional)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Host'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Port'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    });

    testWidgets('validates empty host shows error', (tester) async {
      await tester.pumpWidget(_buildSubject());

      // Clear the host field and trigger validation via save
      final hostField = find.widgetWithText(TextFormField, 'Host');
      await tester.enterText(hostField, '');

      // Tap save icon
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('Host is required'), findsOneWidget);
    });

    testWidgets('validates empty username shows error', (tester) async {
      await tester.pumpWidget(_buildSubject());

      // Fill host to pass its validation, leave username empty
      await tester.enterText(find.widgetWithText(TextFormField, 'Host'), 'example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), '');

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('Username is required'), findsOneWidget);
    });

    testWidgets('save button exists in AppBar', (tester) async {
      await tester.pumpWidget(_buildSubject());

      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.ancestor(of: find.byIcon(Icons.save), matching: find.byType(AppBar)), findsOneWidget);
    });
  });
}
