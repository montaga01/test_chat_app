import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════
//  APP COLOR SCHEME
//  نفس متغيرات CSS من صفحة الويب بالضبط
// ═══════════════════════════════════════════════════
class AppColorScheme {
  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color border;
  final Color accent;
  final Color accent2;
  final Color accentGlow;
  final Color green;
  final Color greenGlow;
  final Color red;
  final Color text;
  final Color text2;
  final Color text3;
  final Color bubbleMe1;
  final Color bubbleMe2;
  final Color bubbleOther;
  final Color bubbleOtherText;
  final Color bubbleOtherBorder;

  const AppColorScheme({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.border,
    required this.accent,
    required this.accent2,
    required this.accentGlow,
    required this.green,
    required this.greenGlow,
    required this.red,
    required this.text,
    required this.text2,
    required this.text3,
    required this.bubbleMe1,
    required this.bubbleMe2,
    required this.bubbleOther,
    required this.bubbleOtherText,
    required this.bubbleOtherBorder,
  });
}

// ═══════════════════════════════════════════════════
//  COLORS
// ═══════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ── الوضع الليلي ──
  static const dark = AppColorScheme(
    bg:                Color(0xFF0d1117),
    bg2:               Color(0xFF161b22),
    bg3:               Color(0xFF21262d),
    border:            Color(0xFF30363d),
    accent:            Color(0xFF2f81f7),
    accent2:           Color(0xFF1f6feb),
    accentGlow:        Color(0x402f81f7),
    green:             Color(0xFF3fb950),
    greenGlow:         Color(0x4D3fb950),
    red:               Color(0xFFf85149),
    text:              Color(0xFFe6edf3),
    text2:             Color(0xFF8b949e),
    text3:             Color(0xFF484f58),
    bubbleMe1:         Color(0xFF2f81f7),
    bubbleMe2:         Color(0xFF1f6feb),
    bubbleOther:       Color(0xFF21262d),
    bubbleOtherText:   Color(0xFFe6edf3),
    bubbleOtherBorder: Color(0xFF30363d),
  );

  // ── الوضع النهاري ──
  static const light = AppColorScheme(
    bg:                Color(0xFFf6f8fa),
    bg2:               Color(0xFFffffff),
    bg3:               Color(0xFFf0f4ff),
    border:            Color(0xFFd0d7de),
    accent:            Color(0xFF2f81f7),
    accent2:           Color(0xFF1f6feb),
    accentGlow:        Color(0x402f81f7),
    green:             Color(0xFF1a7f37),
    greenGlow:         Color(0x4D1a7f37),
    red:               Color(0xFFcf222e),
    text:              Color(0xFF1a2340),
    text2:             Color(0xFF57606a),
    text3:             Color(0xFF8c959f),
    bubbleMe1:         Color(0xFF2f81f7),
    bubbleMe2:         Color(0xFF1f6feb),
    bubbleOther:       Color(0xFFffffff),
    bubbleOtherText:   Color(0xFF1a2340),
    bubbleOtherBorder: Color(0xFFd0d7de),
  );

  static AppColorScheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ═══════════════════════════════════════════════════
//  AVATAR COLORS — نفس منطق avColor() من JS
// ═══════════════════════════════════════════════════
class AvatarColors {
  AvatarColors._();

  static const _palette = [
    Color(0xFF2f81f7),
    Color(0xFF3fb950),
    Color(0xFFf78166),
    Color(0xFFd2a8ff),
    Color(0xFFffa657),
    Color(0xFF79c0ff),
  ];

  static Color forName(String name) {
    if (name.isEmpty) return _palette[0];
    return _palette[name.codeUnitAt(0) % _palette.length];
  }

  static String initial(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ═══════════════════════════════════════════════════
//  TEXT STYLES
// ═══════════════════════════════════════════════════
class AppTextStyles {
  AppTextStyles._();

  static TextStyle chatName(AppColorScheme c) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 14, fontWeight: FontWeight.w600, color: c.text,
      );

  static TextStyle chatPreview(AppColorScheme c) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.text2);

  static TextStyle chatTime(AppColorScheme c) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.text2);

  static TextStyle bubbleText({required bool isMe, required AppColorScheme c}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 14, height: 1.5,
        color: isMe ? Colors.white : c.bubbleOtherText,
      );

  static TextStyle bubbleTime({required bool isMe}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 10,
        color: isMe ? Colors.white60 : Colors.grey,
      );

  static TextStyle label(AppColorScheme c) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 12, fontWeight: FontWeight.w500, color: c.text2,
      );

  static TextStyle body(AppColorScheme c) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: c.text);

  static TextStyle heading(AppColorScheme c) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 18, fontWeight: FontWeight.w700, color: c.text,
      );

  static TextStyle appTitle(AppColorScheme c) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 20, fontWeight: FontWeight.w700, color: c.accent,
      );

  static TextStyle button() =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
      );
}

// ═══════════════════════════════════════════════════
//  DECORATIONS — عناصر UI متكررة
// ═══════════════════════════════════════════════════
class AppDecorations {
  AppDecorations._();

  static BoxDecoration card(AppColorScheme c) => BoxDecoration(
        color: c.bg2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      );

  static BoxDecoration inputField(AppColorScheme c) => BoxDecoration(
        color: c.bg3,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      );

  static BoxDecoration sendButton(AppColorScheme c) => BoxDecoration(
        gradient: LinearGradient(colors: [c.bubbleMe1, c.bubbleMe2]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: c.accentGlow, blurRadius: 14, offset: const Offset(0, 4)),
        ],
      );

  static BoxDecoration primaryButton(AppColorScheme c) => BoxDecoration(
        gradient: LinearGradient(colors: [c.bubbleMe1, c.bubbleMe2]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: c.accentGlow, blurRadius: 20, offset: const Offset(0, 6)),
        ],
      );

  static BoxDecoration bubbleMe(AppColorScheme c) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.bubbleMe1, c.bubbleMe2],
        ),
        borderRadius: const BorderRadius.only(
          topLeft:     Radius.circular(18),
          topRight:    Radius.circular(18),
          bottomRight: Radius.circular(4),
          bottomLeft:  Radius.circular(18),
        ),
      );

  static BoxDecoration bubbleOther(AppColorScheme c) => BoxDecoration(
        color: c.bubbleOther,
        border: Border.all(color: c.bubbleOtherBorder),
        borderRadius: const BorderRadius.only(
          topLeft:     Radius.circular(18),
          topRight:    Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft:  Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration errorBox(AppColorScheme c) => BoxDecoration(
        color: c.red.withOpacity(0.12),
        border: Border.all(color: c.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      );

  static BoxDecoration dateDivider(AppColorScheme c) => BoxDecoration(
        color: c.bg3,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(20),
      );
}