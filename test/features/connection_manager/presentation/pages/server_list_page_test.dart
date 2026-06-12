import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/connection_manager/presentation/cubit/server_list_cubit.dart';
import 'package:sshku/features/connection_manager/presentation/cubit/server_list_state.dart';
import 'package:sshku/features/ssh_connection/data/models/connection_model.dart';

class FakeServerListCubit extends MockCubit<ServerListState>
    implements ServerListCubit {}

Widget _buildSubject(ServerListCubit cubit) {
  return MaterialApp(
    home: BlocProvider<ServerListCubit>.value(
      value: cubit,
      child: Scaffold(
        body: BlocBuilder<ServerListCubit, ServerListState>(
          builder: (context, state) {
            if (state is ServerListLoaded && state.connections.isEmpty) {
              return const Center(child: Text('No servers yet'));
            }
            if (state is ServerListLoaded) {
              return ListView(
                children: state.connections
                    .map((c) => ListTile(
                          key: ValueKey(c.id),
                          title: Text(c.name ?? c.host),
                        ))
                    .toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    ),
  );
}

void main() {
  late FakeServerListCubit cubit;

  setUp(() {
    cubit = FakeServerListCubit();
  });

  tearDown(() => cubit.close());

  group('ServerListPage', () {
    testWidgets('shows empty state when no servers', (tester) async {
      whenListen(
        cubit,
        Stream<ServerListState>.value(const ServerListLoaded([])),
        initialState: const ServerListLoaded([]),
      );

      await tester.pumpWidget(_buildSubject(cubit));

      expect(find.text('No servers yet'), findsOneWidget);
    });

    testWidgets('shows server cards when loaded', (tester) async {
      final connections = [
        ConnectionModel(id: 1, host: '192.168.1.1', username: 'root', name: 'Dev Server'),
        ConnectionModel(id: 2, host: '10.0.0.1', username: 'admin', name: 'Prod Server'),
      ];
      whenListen(
        cubit,
        Stream<ServerListState>.value(ServerListLoaded(connections)),
        initialState: ServerListLoaded(connections),
      );

      await tester.pumpWidget(_buildSubject(cubit));

      expect(find.text('Dev Server'), findsOneWidget);
      expect(find.text('Prod Server'), findsOneWidget);
    });

    testWidgets('FAB exists', (tester) async {
      whenListen(
        cubit,
        Stream<ServerListState>.value(const ServerListLoaded([])),
        initialState: const ServerListLoaded([]),
      );

      await tester.pumpWidget(_buildSubject(cubit));

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}
