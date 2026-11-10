import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Replace with your real contact and legal links.
const kSupportEmail = 'support@zhentropic.com';
const kTermsUrl = 'https://zhentropic.com/terms';
const kPrivacyUrl = 'https://zhentropic.com/privacy';

class Z {
  Z._();
  static const logo = Color(0xFF1A3F94);
  static const deepBlue = Color(0xFF2B5B84);
  static const blue = Color(0xFF1D4ED8);
  static const lightBlue = Color(0xFFEBF5FF);
  static const accent = Color(0xFF3B82F6);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const hint = Color(0xFF8E8E93);
  static const surface = Color(0xFFF9FAFB);
  static const line = Color(0xFFE5E7EB);
  static const softLine = Color(0xFFF3F4F6);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Z.blue),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

final _arabicScript = RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');
final _latin = RegExp(r'[A-Za-z]');

/// True when Arabic-script (Urdu) letters are at least as common as Latin ones,
/// so Urdu paragraphs with a few English acronyms still render right-to-left.
bool isRtl(String text) {
  final rtl = _arabicScript.allMatches(text).length;
  if (rtl == 0) return false;
  return rtl >= _latin.allMatches(text).length;
}

/// Clean Inter for English; Noto Naskh with a tall line-height for Urdu so
/// diacritics never clip against inline English words or bullets.
TextStyle zText({double size = 15, Color color = Z.ink, FontWeight weight = FontWeight.w400, bool rtl = false}) {
  if (rtl) {
    return GoogleFonts.notoNaskhArabic(fontSize: size + 1, color: color, fontWeight: weight, height: 1.8)
        .copyWith(fontFamilyFallback: [GoogleFonts.inter().fontFamily!]);
  }
  return GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, height: 1.5);
}

class ZLogo extends StatelessWidget {
  const ZLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/zhentropic_mark.png',
        width: size,
        height: size * 0.94,
        fit: BoxFit.contain,
        color: Z.logo,
        colorBlendMode: BlendMode.srcIn,
      );
}
