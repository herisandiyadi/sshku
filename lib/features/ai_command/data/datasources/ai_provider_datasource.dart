import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_command.dart';
import 'ai_response_parser.dart';

/// Memanggil endpoint OpenAI-compatible `POST {baseUrl}/chat/completions`.
/// Deep module: seluruh detail HTTP + parsing tersembunyi di balik [generate].
class AiProviderDatasource {
  final http.Client _client;
  final AiResponseParser _parser;

  AiProviderDatasource({http.Client? client, AiResponseParser? parser})
      : _client = client ?? http.Client(),
        _parser = parser ?? AiResponseParser();

  /// Kirim [systemPrompt] + [instruction], kembalikan daftar command mentah
  /// (belum diklasifikasi safety). Lempar [Exception] dengan pesan jelas bila
  /// jaringan/HTTP/parse gagal.
  Future<List<AiCommand>> generate({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String instruction,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/chat/completions');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
    };
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': instruction},
      ],
      'temperature': 0.2,
    });

    final http.Response res;
    try {
      res = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('Gagal menghubungi AI provider: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('AI provider error ${res.statusCode}: ${_briefBody(res.body)}');
    }

    final content = _extractContent(res.body);
    if (content == null) {
      throw Exception('Respons AI tidak memuat konten');
    }
    return _parser.parse(content);
  }

  String _trimSlash(String url) =>
      url.trim().endsWith('/') ? url.trim().substring(0, url.trim().length - 1) : url.trim();

  String? _extractContent(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final message = (choices.first as Map)['message'];
      final content = (message as Map)['content'];
      return content?.toString();
    } catch (_) {
      return null;
    }
  }

  String _briefBody(String body) =>
      body.length > 200 ? '${body.substring(0, 200)}…' : body;
}
