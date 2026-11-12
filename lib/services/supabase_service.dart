// ---------------------------------------------------------------------------
// SUPABASE SETUP (full script: sql_schema.sql in the project root)
//
//   conversations(id uuid PK, user_id uuid FK -> auth.users, title text,
//                 created_at timestamptz)
//   messages(id uuid PK, conversation_id uuid FK -> conversations, role text
//            ('user'|'assistant'), content text, reasoning_content text null,
//            thinking_duration int null, attachment_url text null,
//            attachment_type text ('image'|'pdf'|null), created_at timestamptz)
//   Storage bucket: zhentropic-files (private, files under <user_id>/...)
//   Row Level Security: every table/bucket is limited to auth.uid().
//
// Configuration:
//   The Supabase URL and publishable key are supplied via environment
//   variables (SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY) through
//   lib/constants.dart. They are validated before the app starts.
//
// Google sign-in: enable the Google provider in your Supabase project > Authentication
// and add the redirect URL  io.supabase.zhentropic://login-callback/
// ---------------------------------------------------------------------------
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';

class SupabaseService {
  static const bucket = 'zhentropic-files';
  static const authRedirect = 'io.supabase.zhentropic://login-callback/';

  SupabaseClient get _c => Supabase.instance.client;
  String? get userId => _c.auth.currentUser?.id;

  // ---- Auth ---------------------------------------------------------------
  Future<void> signInWithGoogle() async {
    await _c.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : authRedirect,
    );
  }

  Future<void> signInWithPassword(String email, String password) async {
    await _c.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<AuthResponse> signUp(String email, String password) =>
      _c.auth.signUp(email: email.trim(), password: password);

  Future<void> signOut() => _c.auth.signOut();

  // ---- Storage ------------------------------------------------------------
  /// Uploads a PDF or image and returns a signed URL valid for one year.
  Future<String> uploadAttachment(File file, String userId) async {
    final path = '$userId/${const Uuid().v4()}${p.extension(file.path).toLowerCase()}';
    await _c.storage.from(bucket).upload(path, file);
    return _c.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24 * 365);
  }

  // ---- Conversations & messages ---------------------------------------------
  Future<String> createConversation(String title) async {
    final row = await _c
        .from('conversations')
        .insert({'user_id': userId, 'title': title})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final rows = await _c
        .from('conversations')
        .select('id,title,created_at')
        .order('created_at', ascending: false)
        .limit(60);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveMessage(String conversationId, ChatMessage m) async {
    await _c.from('messages').insert(m.toRow(conversationId));
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final rows = await _c
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return [for (final r in rows) ChatMessage.fromRow(Map<String, dynamic>.from(r))];
  }
}
