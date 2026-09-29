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
      'stream': false,
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
    if (content == null || content.trim().isEmpty) {
      throw Exception(
          'Respons AI tidak memuat konten. Body: ${_briefBody(res.body)}');
    }
    return _parser.parse(content);
  }

  /// Uji konektivitas & autentikasi ringan: kirim request minimal dan pastikan
  /// endpoint membalas HTTP 2xx. TIDAK mewajibkan respons ter-parse jadi command,
  /// sehingga tidak false-negative saat koneksi sebenarnya sehat.
  Future<void> testConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/chat/completions');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
    };
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': 'ping'},
      ],
      'max_tokens': 1,
      'stream': false,
    });

    final http.Response res;
    try {
      res = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw Exception('Gagal menghubungi AI provider: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('AI provider error ${res.statusCode}: ${_briefBody(res.body)}');
    }
  }

  String _trimSlash(String url) =>
      url.trim().endsWith('/') ? url.trim().substring(0, url.trim().length - 1) : url.trim();

  String? _extractContent(String responseBody) {
    // Format streaming SSE: baris-baris "data: {chunk}". Gabungkan delta.content.
    final trimmed = responseBody.trimLeft();
    if (trimmed.startsWith('data:')) {
      return _extractSse(responseBody);
    }
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      // 1) OpenAI-compatible: choices[0].message.content
      final choices = json['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first as Map;
        final message = first['message'];
        if (message is Map) {
          final c = _stringifyContent(message['content']);
          if (c != null && c.isNotEmpty) return c;
          // Sebagian model taruh teks di reasoning_content.
          final r = _stringifyContent(message['reasoning_content']);
          if (r != null && r.isNotEmpty) return r;
        }
        // Legacy completions: choices[0].text
        final text = first['text'];
        if (text is String && text.isNotEmpty) return text;
      }

      // 2) Anthropic native: content[].text
      final anthropic = _stringifyContent(json['content']);
      if (anthropic != null && anthropic.isNotEmpty) return anthropic;

      // 3) Gemini native: candidates[0].content.parts[].text
      final candidates = json['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final content = (candidates.first as Map)['content'];
        if (content is Map) {
          final parts = content['parts'];
          if (parts is List) {
            final joined = parts
                .whereType<Map>()
                .map((p) => p['text']?.toString() ?? '')
                .join();
            if (joined.isNotEmpty) return joined;
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ubah field "content" menjadi string. Mendukung:
  /// - String biasa (OpenAI)
  /// - Array of parts [{type:text, text:"..."}] (Anthropic / OpenAI multimodal)
  /// Gabungkan `choices[0].delta.content` dari semua chunk SSE
  /// ("data: {...}" per baris, diakhiri "data: [DONE]").
  String? _extractSse(String body) {
    final buffer = StringBuffer();
    for (final rawLine in const LineSplitter().convert(body)) {
      final line = rawLine.trim();
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first as Map;
        // Streaming pakai "delta"; sebagian gabungan pakai "message".
        final node = choice['delta'] ?? choice['message'];
        if (node is Map) {
          final c = _stringifyContent(node['content']);
          if (c != null) buffer.write(c);
        }
      } catch (_) {
        // abaikan chunk yang tak valid
      }
    }
    final result = buffer.toString();
    return result.isEmpty ? null : result;
  }

  String? _stringifyContent(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((p) => (p['text'] ?? p['content'] ?? '').toString())
          .join();
    }
    return null;
  }

  String _briefBody(String body) =>
      body.length > 200 ? '${body.substring(0, 200)}…' : body;

  /// Tutup HTTP client. Panggil saat pemilik selesai.
  void dispose() => _client.close();
}
