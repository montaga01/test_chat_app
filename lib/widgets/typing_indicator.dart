import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

// ═══════════════════════════════════════════════════
//  TYPING INDICATOR
//  نفس مؤشر الكتابة (.typing-indicator) من صفحة الويب
//  ثلاث نقاط تتحرك بالتسلسل
// ═══════════════════════════════════════════════════
class TypingIndicator extends StatefulWidget {
  /// اسم المُستخدم الذي يكتب (اختياري — يُعرض بجانب النقاط)
  final String? userName;

  const TypingIndicator({super.key, this.userName});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>>   _anims;

  static const _dotCount = 3;
  static const _dotSize  = 7.0;

  @override
  void initState() {
    super.initState();

    // نفس delay من CSS (nth-child animation-delay)
    _controllers = List.generate(_dotCount, (i) {
      return AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _anims = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    _startLoop();
  }

  void _startLoop() async {
    while (mounted) {
      for (int i = 0; i < _dotCount; i++) {
        if (!mounted) return;
        _controllers[i].forward(from: 0).then((_) {
          if (mounted) _controllers[i].reverse();
        });
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 60, top: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── فقاعة النقاط ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        c.bubbleOther,
              border:       Border.all(color: c.bubbleOtherBorder),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(18),
                topRight:    Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft:  Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color:     Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset:    const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dotCount, (i) {
                return AnimatedBuilder(
                  animation: _anims[i],
                  builder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Transform.translate(
                      offset: Offset(0, _anims[i].value),
                      child: Container(
                        width:  _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          color:  c.text2,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── "يكتب..." نص (اختياري) ──
          if (widget.userName != null) ...[
            const SizedBox(width: 8),
            Text(
              '${widget.userName} يكتب...',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                color:    c.text2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TYPING INDICATOR WRAPPER — مع AnimatedVisibility
//  يظهر/يختفي بسلاسة مثل صفحة الويب
// ═══════════════════════════════════════════════════
class TypingIndicatorAnimated extends StatelessWidget {
  final bool   isVisible;
  final String? userName;

  const TypingIndicatorAnimated({
    super.key,
    required this.isVisible,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve:    Curves.easeOut,
      child: AnimatedOpacity(
        opacity:  isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: isVisible
            ? TypingIndicator(userName: userName)
            : const SizedBox.shrink(),
      ),
    );
  }
}