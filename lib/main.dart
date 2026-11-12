import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';
import 'core/app_theme.dart';
import 'providers/chat_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';

/// Run with:
/// flutter run \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
///   --dart-define=DEEPSEEK_API_KEY=your-deepseek-key
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast if required configuration is missing. This prevents the app
  // from silently connecting to an unknown or legacy backend.
  assertValidConfig();

  await Supabase.initialize(
    url: kSupabaseUrl,
    // The currently installed supabase_flutter SDK uses the `anonKey`
    // parameter. Our publishable key is supplied through the same public
    // credential slot.
    anonKey: kSupabasePublishableKey,
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
