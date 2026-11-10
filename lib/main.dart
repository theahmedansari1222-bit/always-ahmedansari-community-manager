import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'providers/chat_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';

/// Run with:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=DEEPSEEK_API_KEY=...
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: ZhentropicApp()));
}

class ZhentropicApp extends ConsumerWidget {
  const ZhentropicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).valueOrNull;
    return MaterialApp(
      title: 'Zhentropic',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: session == null ? const AuthScreen() : const ChatScreen(),
    );
  }
}
