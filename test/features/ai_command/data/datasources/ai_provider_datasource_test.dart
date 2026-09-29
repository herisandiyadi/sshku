import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sshku/features/ai_command/data/datasources/ai_provider_datasource.dart';

AiProviderDatasource dsReturning(String body, {int status = 200}) {
  final client = MockClient((_) async => http.Response(body, status,
      headers: {'content-type': 'application/json'}));
  return AiProviderDatasource(client: client);
}

const _cmdJson = '{"commands":[{"cmd":"ls","desc":"list"}]}';

Future<List<String>> run(AiProviderDatasource ds) async {
  final cmds = await ds.generate(
    baseUrl: 'https://x/v1',
    apiKey: 'k',
    model: 'm',
    systemPrompt: 'sys',
    instruction: 'list files',
  );
  return cmds.map((c) => c.cmd).toList();
}

void main() {
  test('OpenAI: choices[0].message.content string', () async {
    final body = jsonEncode({
      'choices': [
        {'message': {'content': _cmdJson}}
      ]
    });
    expect(await run(dsReturning(body)), ['ls']);
  });

  test('OpenAI multimodal: content sebagai array of parts', () async {
    final body = jsonEncode({
      'choices': [
        {
          'message': {
            'content': [
              {'type': 'text', 'text': _cmdJson}
            ]
          }
        }
      ]
    });
    expect(await run(dsReturning(body)), ['ls']);
  });

  test('Anthropic native: content[].text', () async {
    final body = jsonEncode({
      'content': [
        {'type': 'text', 'text': _cmdJson}
      ]
    });
    expect(await run(dsReturning(body)), ['ls']);
  });

  test('Gemini native: candidates[0].content.parts[].text', () async {
    final body = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': _cmdJson}
            ]
          }
        }
      ]
    });
    expect(await run(dsReturning(body)), ['ls']);
  });

  test('SSE streaming: gabungkan choices[0].delta.content', () async {
    final body = 'data: {"choices":[{"delta":{"role":"assistant","content":"{\\"commands\\":["}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"{\\"cmd\\":\\"ls\\"}"}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"]}"}}]}\n\n'
        'data: [DONE]\n\n';
    expect(await run(dsReturning(body)), ['ls']);
  });

  test('format tak dikenal -> error menyertakan cuplikan body', () async {
    final body = jsonEncode({'unexpected': 'shape'});
    await expectLater(
      run(dsReturning(body)),
      throwsA(predicate((e) =>
          e.toString().contains('tidak memuat konten') &&
          e.toString().contains('unexpected'))),
    );
  });

  test('HTTP non-2xx -> error menyertakan status & body', () async {
    await expectLater(
      run(dsReturning('{"error":"bad key"}', status: 401)),
      throwsA(predicate((e) =>
          e.toString().contains('401') && e.toString().contains('bad key'))),
    );
  });
}
