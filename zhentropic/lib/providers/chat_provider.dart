import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show Session, Supabase;
import 'package:uuid/uuid.dart';

import '../core/app_theme.dart';
import '../models/message_model.dart';
import '../services/deepseek_api_service.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());
final deepSeekProvider = Provider<DeepSeekApiService>((ref) => DeepSeekApiService());

final authStateProvider = StreamProvider<Session?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((e) => e.session);
});

class ChatState {
  const ChatState({
    this.messages = const [],
    this.conversationId,
    this.thinkMode = false,
    this.searchMode = false,
    this.speakReplies = false,
    this.isStreaming = false,
    this.attachment,
    this.elapsedSeconds = 0,
    this.conversations = const [],
  });

  final List<ChatMessage> messages;
  final String? conversationId;
  final bool thinkMode, searchMode, speakReplies, isStreaming;
  final PendingAttachment? attachment;
  final int elapsedSeconds; // live "Thinking for N seconds" counter
  final List<Map<String, dynamic>> conversations;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? conversationId,
    bool clearConversation = false,
    bool? thinkMode,
    bool? searchMode,
    bool? speakReplies,
    bool? isStreaming,
    PendingAttachment? attachment,
    bool clearAttachment = false,
    int? elapsedSeconds,
    List<Map<String, dynamic>>? conversations,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        conversationId: clearConversation ? null : (conversationId ?? this.conversationId),
        thinkMode: thinkMode ?? this.thinkMode,
        searchMode: searchMode ?? this.searchMode,
        speakReplies: speakReplies ?? this.speakReplies,
        isStreaming: isStreaming ?? this.isStreaming,
        attachment: clearAttachment ? null : (attachment ?? this.attachment),
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        conversations: conversations ?? this.conversations,
      );
}

final chatProvider = NotifierProvider.autoDispose<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends AutoDisposeNotifier<ChatState> {
  final _uuid = const Uuid();
  final _tts = FlutterTts();
  int _gen = 0; // bumped when the chat is replaced; old streams stop touching state
  bool _stop = false, _disposed = false;
  ({String name, String text})? _doc; // extracted PDF text for follow-up questions

  SupabaseService get _db => ref.read(supabaseServiceProvider);
  DeepSeekApiService get _api => ref.read(deepSeekProvider);

  @override
  ChatState build() {
    ref.onDispose(() {
      _disposed = true;
      _tts.stop();
    });
    Future.microtask(refreshConversations);
    return const ChatState();
  }

  // ---- UI toggles -----------------------------------------------------------
  void toggleThink() => state = state.copyWith(thinkMode: !state.thinkMode);
  void toggleSearch() => state = state.copyWith(searchMode: !state.searchMode);
  void toggleSpeak() {
    if (state.speakReplies) _tts.stop();
    state = state.copyWith(speakReplies: !state.speakReplies);
  }

  void setAttachment(PendingAttachment a) => state = state.copyWith(attachment: a);
  void clearAttachment() => state = state.copyWith(clearAttachment: true);
  void stop() => _stop = true;

  // ---- Conversations --------------------------------------------------------
  Future<void> refreshConversations() async {
    final rows = await _safe(_db.listConversations);
    if (rows != null && !_disposed) state = state.copyWith(conversations: rows);
  }

  void newChat() {
    _gen++;
    _stop = true;
    _doc = null;
    _tts.stop();
    state = state.copyWith(
      messages: [],
      clearConversation: true,
      clearAttachment: true,
      isStreaming: false,
      elapsedSeconds: 0,
    );
  }

  Future<void> openConversation(String id) async {
    newChat();
    final msgs = await _safe(() => _db.loadMessages(id));
    if (msgs != null && !_disposed) state = state.copyWith(messages: msgs, conversationId: id);
  }

  // ---- Sending --------------------------------------------------------------
  Future<void> send(String raw) async {
    final att = state.attachment;
    var prompt = raw.trim();
    if (state.isStreaming || (prompt.isEmpty && att == null)) return;
    if (prompt.isEmpty) {
      prompt = att!.type == AttachmentType.pdf ? 'Summarize this document.' : 'Describe this image.';
    }

    final gen = ++_gen;
    _stop = false;
    final think = state.thinkMode, search = state.searchMode;
    final history = [
      for (final m in state.messages)
        if (!m.isStreaming && m.content.isNotEmpty) m,
    ];
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: prompt,
      attachmentType: att?.type,
      attachmentName: att?.name,
      localFile: att?.file,
      createdAt: DateTime.now(),
    );
    var draft = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      usedThinking: think,
      isStreaming: true,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg, draft],
      isStreaming: true,
      elapsedSeconds: 0,
      clearAttachment: true,
    );

    // Live timer starts the moment the request is sent.
    final watch = Stopwatch()..start();
    final timer = think
        ? Timer.periodic(const Duration(seconds: 1), (t) {
            if (gen != _gen || _disposed) {
              t.cancel();
              return;
            }
            state = state.copyWith(elapsedSeconds: watch.elapsed.inSeconds);
          })
        : null;

    var reasoning = '', answer = '';
    int? thinkSecs;
    var failed = false;
    String? cid = state.conversationId;
    try {
      cid ??= await _safe(() => _db.createConversation(_title(prompt)));
      if (gen == _gen && cid != null) state = state.copyWith(conversationId: cid);

      String? url;
      if (att != null) {
        url = await _safe(() => _db.uploadAttachment(att.file, _db.userId!));
        if (att.type == AttachmentType.pdf) {
          _doc = (name: att.name, text: await _api.extractPdfText(att.file));
        }
      }
      final saved = userMsg.copyWith(attachmentUrl: url);
      _replace(saved);
      if (cid != null) await _safe(() => _db.saveMessage(cid!, saved));

      await for (final d in _api.streamChat(
        history: history,
        prompt: prompt,
        think: think,
        search: search,
        image: att?.type == AttachmentType.image ? att!.file : null,
        documentName: _doc?.name,
        documentText: _doc?.text,
      )) {
        if (_stop || gen != _gen) break;
        reasoning += d.reasoning;
        if (d.content.isNotEmpty) {
          if (think && thinkSecs == null) {
            thinkSecs = watch.elapsed.inSeconds; // freeze the duration
            timer?.cancel();
          }
          answer += d.content;
        }
        draft = draft.copyWith(
          content: answer,
          reasoning: reasoning.isEmpty ? null : reasoning,
          thinkingSeconds: thinkSecs,
        );
        _replace(draft);
      }
    } catch (e) {
      failed = true;
      answer += '${answer.isEmpty ? '' : '\n\n'}⚠️ ${_friendly(e)}';
    } finally {
      timer?.cancel();
    }

    final hasReasoning = reasoning.isNotEmpty;
    final done = draft.copyWith(
      content: answer,
      reasoning: hasReasoning ? reasoning : null,
      thinkingSeconds: think && hasReasoning ? (thinkSecs ?? watch.elapsed.inSeconds) : null,
      isStreaming: false,
    );
    _replace(done);
    if (gen == _gen && !_disposed) state = state.copyWith(isStreaming: false);
    if (!failed && answer.isNotEmpty && cid != null) {
      await _safe(() => _db.saveMessage(cid!, done));
    }
    if (gen == _gen && !_disposed) {
      refreshConversations();
      if (!failed && state.speakReplies) _speak(answer);
    }
  }

  // ---- Helpers --------------------------------------------------------------
  void _replace(ChatMessage m) {
    if (_disposed) return;
    state = state.copyWith(messages: [for (final x in state.messages) x.id == m.id ? m : x]);
  }

  Future<T?> _safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  String _title(String prompt) {
    final t = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }

  String _friendly(Object e) {
    if (e is DeepSeekException) {
      switch (e.status) {
        case 401:
          return 'DeepSeek rejected the API key. ${e.message}';
        case 402:
          return 'The DeepSeek account balance is insufficient.';
        case 429:
          return 'Too many requests. Please try again in a moment.';
        default:
          return e.message;
      }
    }
    if (e is TimeoutException || e is SocketException || e is http.ClientException) {
      return 'Network problem. Check your connection and try again.';
    }
    return e.toString();
  }

  Future<void> _speak(String text) async {
    final clean = text.replaceAll(RegExp(r'[*_#>`\[\]]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    await _safe(() async {
      await _tts.stop();
      await _tts.setLanguage(isRtl(clean) ? 'ur-PK' : 'en-US');
      await _tts.speak(clean);
    });
  }
}
