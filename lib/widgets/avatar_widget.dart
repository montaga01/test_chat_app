import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

// ═══════════════════════════════════════════════════
//  AVATAR WIDGET
//  نفس دالة makeAvatar() + online dot من صفحة الويب
//  يُستخدم في: ChatTile، ChatScreen، HomeScreen
// ═══════════════════════════════════════════════════
class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final bool   isOnline;

  /// إخفاء نقطة الاتصال حتى عند isOnline=true
  final bool   showOnlineDot;

  const AvatarWidget({
    super.key,
    required this.name,
    this.size         = 42,
    this.isOnline     = false,
    this.showOnlineDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final c       = AppColors.of(context);
    final color   = AvatarColors.forName(name);
    final initial = AvatarColors.initial(name);

    return SizedBox(
      width:  size,
      height: size,
      child: Stack(
        children: [
          // ── الدائرة الرئيسية ──
          Container(
            width:  size,
            height: size,
            decoration: BoxDecoration(
              color:  color.withOpacity(0.18),
              shape:  BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize:   size * 0.4,
                  fontWeight: FontWeight.w700,
                  color:      color,
                ),
              ),
            ),
          ),

          // ── نقطة الاتصال ──
          if (showOnlineDot)
            Positioned(
              right:  0,
              bottom: 0,
              child: _OnlineDot(isOnline: isOnline, c: c),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  ONLINE DOT — نفس .online-dot من CSS
// ═══════════════════════════════════════════════════
class _OnlineDot extends StatelessWidget {
  final bool           isOnline;
  final AppColorScheme c;

  const _OnlineDot({required this.isOnline, required this.c});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width:  11,
      height: 11,
      decoration: BoxDecoration(
        color: isOnline ? c.green : c.text3,
        shape: BoxShape.circle,
        border: Border.all(color: c.bg2, width: 2),
        boxShadow: isOnline
            ? [BoxShadow(color: c.greenGlow, blurRadius: 6)]
            : null,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  AVATAR HERO — نفس AvatarWidget لكن مع Hero animation
//  مفيد عند الانتقال من HomeScreen → ChatScreen
// ═══════════════════════════════════════════════════
class AvatarHero extends StatelessWidget {
  final String name;
  final int    userId;
  final double size;
  final bool   isOnline;

  const AvatarHero({
    super.key,
    required this.name,
    required this.userId,
    this.size     = 42,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'avatar_$userId',
      child: AvatarWidget(
        name:     name,
        size:     size,
        isOnline: isOnline,
      ),
    );
  }
}