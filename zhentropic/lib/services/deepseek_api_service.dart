import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/message_model.dart';

/// Everything is overridable with --dart-define so model names can follow
/// DeepSeek's current docs without code changes.
class DeepSeekConfig {
  DeepSeekConfig._();
  static const apiKey = String.fromEnvironment('DEEPSEEK_API_KEY');
  static const endpoint =
      String.fromEnvironment('DEEPSEEK_ENDPOINT', defaultValue: 'https://api.deepseek.com/chat/completions');
  static const chatModel = String.fromEnvironment('DEEPSEEK_CHAT_MODEL', defaultValue: 'deepseek-v4-flash');
  static const thinkModel = String.fromEnvironment('DEEPSEEK_THINK_MODEL', defaultValue: 'deepseek-v4-flash');

  /// V4 models switch reasoning with `reasoning_effort`. For the legacy
  /// `deepseek-reasoner` model run with --dart-define=DEEPSEEK_REASONING_EFFORT=false
  static const useReasoningEffort = bool.fromEnvironment('DEEPSEEK_REASONING_EFFORT', defaultValue: true);
  static const maxPdfChars = 60000;
}

class DeepSeekException implements Exception {
  DeepSeekException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'DeepSeek error $status: $message';
}

class StreamDelta {
  const StreamDelta({this.reasoning = '', this.content = ''});
  final String reasoning; // delta.reasoning_content
  final String content; // delta.content
}

class DeepSeekApiService {
  static const _system =
      'You are Zhentropic ("Clarity in Complexity"), Pakistan\'s premier AI assistant. '
      'Be clear, accurate and helpful. Reply in the language the user writes in (Urdu or English); '
      'when writing Urdu keep English acronyms such as FBR or ONS in Latin script. Use Markdown for structure.';

  /// Extracts the text of every page locally (nothing is sent anywhere here).
  Future<String> extractPdfText(File file) async {
    final doc = PdfDocument(inputBytes: await file.readAsBytes());
    try {
      final text = PdfTextExtractor(doc).extractText().trim();
      return text.length > DeepSeekConfig.maxPdfChars ? text.substring(0, DeepSeekConfig.maxPdfChars) : text;
    } finally {
      doc.dispose();
    }
  }

  Future<Map<String, dynamic>> _imagePart(File f) async {
    final path = f.path.toLowerCase();
    final mime = path.endsWith('.png') ? 'image/png' : (path.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    return {
      'type': 'image_url',
      'image_url': {'url': 'data:$mime;base64,${base64Encode(await f.readAsBytes())}'},
    };
  }

  Future<http.StreamedResponse> _open(http.Client client, Map<String, dynamic> body) async {
    final req = http.Request('POST', Uri.parse(DeepSeekConfig.endpoint))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': 'Bearer ${DeepSeekConfig.apiKey}',
      })
      ..body = jsonEncode(body);
    final res = await client.send(req).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      final raw = await res.stream.bytesToString();
      var msg = raw;
      try {
        msg = (jsonDecode(raw)['error']['message'] as String?) ?? raw;
      } catch (_) {}
      throw DeepSeekException(res.statusCode, msg);
    }
    return res;
  }

  /// Streams reasoning and answer deltas separately (Server-Sent Events).
  Stream<StreamDelta> streamChat({
    required List<ChatMessage> history,
    required String prompt,
    required bool think,
    required bool search,
    File? image,
    String? documentName,
    String? documentText,
  }) async* {
    if (DeepSeekConfig.apiKey.isEmpty) {
      throw DeepSeekException(401, 'DEEPSEEK_API_KEY is missing. Pass it with --dart-define.');
    }
    final Object userContent = image == null
        ? prompt
        : [
            {'type': 'text', 'text': prompt},
            await _imagePart(image),
          ];

    Map<String, dynamic> body({required bool tools, required bool searchNote}) {
      final sys = StringBuffer(_system);
      if (documentText != null) {
        sys.write('\n\nThe user attached a PDF named "$documentName". '
            'Use its extracted text below to answer questions about it.\n"""\n$documentText\n"""');
      }
      if (searchNote) {
        sys.write('\n\nLive web search is unavailable right now. If the question needs current information, say so.');
      }
      return {
        'model': think ? DeepSeekConfig.thinkModel : DeepSeekConfig.chatModel,
        'stream': true,
        if (DeepSeekConfig.useReasoningEffort) 'reasoning_effort': think ? 'high' : 'none',
        if (tools) 'tools': [
          {'type': 'web_search'}
        ],
        'messages': [
          {'role': 'system', 'content': sys.toString()},
          for (final m in history) {'role': m.role, 'content': m.content},
          {'role': 'user', 'content': userContent},
        ],
      };
    }

    final client = http.Client();
    try {
      http.StreamedResponse res;
      try {
        res = await _open(client, body(tools: search, searchNote: false));
      } on DeepSeekException catch (e) {
        // If the API rejects the web_search tool, retry once as a normal chat.
        if (!search || e.status != 400) rethrow;
        res = await _open(client, body(tools: false, searchNote: true));
      }
      final lines = res.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map)['delta'] as Map?;
        if (delta == null) continue;
        final r = (delta['reasoning_content'] as String?) ?? '';
        final c = (delta['content'] as String?) ?? '';
        if (r.isNotEmpty || c.isNotEmpty) yield StreamDelta(reasoning: r, content: c);
      }
    } finally {
      client.close();
    }
  }
}
