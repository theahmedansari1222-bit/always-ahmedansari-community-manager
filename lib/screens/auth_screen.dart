import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../providers/chat_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _agreed = false, _busy = false;
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => _open(kTermsUrl);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()..onTap = () => _open(kPrivacyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(supabaseServiceProvider).signInWithGoogle();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _password(bool signUp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _PasswordSheet(signUp: signUp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _agreed && !_busy;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _open('mailto:$kSupportEmail'),
              child: Text('Contact us', style: GoogleFonts.inter(color: Z.hint, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const ZLogo(size: 120),
                const SizedBox(height: 18),
                Text('Zhentropic',
                    style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, color: Z.deepBlue, letterSpacing: -0.8)),
                const SizedBox(height: 4),
                Text('Clarity in Complexity', style: GoogleFonts.inter(fontSize: 14, color: Z.muted)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              _PillButton(label: 'Continue with Google', icon: const _GoogleG(), onTap: enabled ? _google : null),
              const SizedBox(height: 12),
              _PillButton(
                label: 'Continue with Password',
                icon: const Icon(Icons.lock, size: 20, color: Colors.black),
                onTap: enabled ? () => _password(false) : null,
              ),
              const SizedBox(height: 12),
              _PillButton(label: 'Sign up', onTap: enabled ? () => _password(true) : null),
            ]),
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(top: 1),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _agreed ? Colors.black : Colors.white,
                    border: Border.all(color: _agreed ? Colors.black : const Color(0xFFC7C7CC), width: 1.5),
                  ),
                  child: _agreed ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.inter(fontSize: 12.5, color: Z.hint, height: 1.45),
                    children: [
                      const TextSpan(text: "I confirm that I have read and agree to Zhentropic's "),
                      TextSpan(text: 'Terms of Use', recognizer: _terms, style: const TextStyle(color: Color(0xFF3C3C43), fontWeight: FontWeight.w600)),
                      const TextSpan(text: ' and '),
                      TextSpan(text: 'Privacy Policy', recognizer: _privacy, style: const TextStyle(color: Color(0xFF3C3C43), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap, this.icon});
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(side: BorderSide(color: Z.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: Stack(alignment: Alignment.center, children: [
                if (icon != null) Positioned(left: 22, child: icon!),
                Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
              ]),
            ),
          ),
        ),
      );
}

/// Multicolour "G". For strict brand compliance swap in Google's official asset.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const SweepGradient(
          colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335), Color(0xFF4285F4)],
          stops: [0, 0.25, 0.5, 0.75, 1],
        ).createShader(r),
        child: Text('G', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet({required this.signUp});
  final bool signUp;

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  late bool _signUp = widget.signUp;
  bool _busy = false, _obscure = true;
  String? _error, _notice;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim(), pass = _pass.text;
    if (!email.contains('@') || pass.length < 6) {
      setState(() => _error = 'Enter a valid email and a password of at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final svc = ref.read(supabaseServiceProvider);
    try {
      if (_signUp) {
        final res = await svc.signUp(email, pass);
        if (res.session == null) {
          if (mounted) setState(() => _notice = 'Check your email to confirm your account, then sign in.');
          return;
        }
      } else {
        await svc.signInWithPassword(email, pass);
      }
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: Z.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Z.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Z.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Z.blue)),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_signUp ? 'Create your account' : 'Welcome back',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Z.ink)),
          const SizedBox(height: 18),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: _dec('Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: _dec('Password',
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Z.muted),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          if (_notice != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_notice!, style: const TextStyle(color: Z.blue, fontSize: 13))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_signUp ? 'Sign up' : 'Continue', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => setState(() {
              _signUp = !_signUp;
              _error = _notice = null;
            }),
            child: Text(_signUp ? 'Already have an account? Sign in' : "New here? Create an account",
                style: GoogleFonts.inter(color: Z.muted, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
