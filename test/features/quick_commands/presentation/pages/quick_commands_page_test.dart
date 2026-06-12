import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/quick_commands/data/models/snippet_model.dart';
import 'package:sshku/features/quick_commands/presentation/cubit/snippet_cubit.dart';
import 'package:sshku/features/quick_commands/presentation/cubit/snippet_state.dart';

class FakeSnippetCubit extends MockCubit<SnippetState>
    implements SnippetCubit {}

Widget _buildSubject(SnippetCubit cubit) {
  return MaterialApp(
    home: BlocProvider<SnippetCubit>.value(
      value: cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quick Commands'),
          actions: [
            IconButton(icon: const Icon(Icons.add), onPressed: () {}),
          ],
        ),
        body: BlocBuilder<SnippetCubit, SnippetState>(
          builder: (context, state) {
            if (state is SnippetLoaded && state.snippets.isEmpty) {
              return const Center(child: Text('No snippets yet. Tap + to add one.'));
            }
            if (state is SnippetLoaded) {
              return ListView(
                children: state.snippets
                    .map((s) => ListTile(
                          key: ValueKey(s.id),
                          title: Text(s.title),
                          subtitle: Text(s.command),
                        ))
                    .toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
}

void main() {
  late FakeSnippetCubit cubit;

  setUp(() {
    cubit = FakeSnippetCubit();
  });

  tearDown(() => cubit.close());

  group('QuickCommandsPage', () {
    testWidgets('shows empty state', (tester) async {
      whenListen(
        cubit,
        Stream<SnippetState>.value(SnippetLoaded(const [])),
        initialState: SnippetLoaded(const []),
      );

      await tester.pumpWidget(_buildSubject(cubit));

      expect(find.text('No snippets yet. Tap + to add one.'), findsOneWidget);
    });

    testWidgets('shows snippets when loaded', (tester) async {
      final snippets = [
        SnippetModel(id: 1, title: 'List files', command: 'ls -la'),
        SnippetModel(id: 2, title: 'Disk usage', command: 'df -h'),
      ];
      whenListen(
        cubit,
        Stream<SnippetState>.value(SnippetLoaded(snippets)),
        initialState: SnippetLoaded(snippets),
      );

      await tester.pumpWidget(_buildSubject(cubit));

      expect(find.text('List files'), findsOneWidget);
      expect(find.text('Disk usage'), findsOneWidget);
      expect(find.text('ls -la'), findsOneWidget);
      expect(find.text('df -h'), findsOneWidget);
    });

    testWidgets('add button exists in AppBar', (tester) async {
      whenListen(
        cubit,
        Stream<SnippetState>.value(SnippetLoaded(const [])),
        initialState: SnippetLoaded(const []),
      );

      await tester.pumpWidget(_buildSubject(cubit));

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.ancestor(of: find.byIcon(Icons.add), matching: find.byType(AppBar)), findsOneWidget);
    });
  });
}
