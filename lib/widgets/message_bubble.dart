import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/message.dart';

// ═══════════════════════════════════════════════════
//  MESSAGE BUBBLE
//  نفس منطق renderMessage() من صفحة الويب
//  مستخرج من chat_screen لإعادة الاستخدام
// ═══════════════════════════════════════════════════
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool    isMe;

  /// هل هذه أول رسالة في مجموعة من نفس المُرسل
  final bool    isFirstInGroup;

  /// هل هذه آخر رسالة في مجموعة من نفس المُرسل
  final bool    isLastInGroup;

  /// هل هذه رسالة معلّقة (pending) لم يصلها تأكيد بعد
  final bool    isPending;

  /// هل فشل إرسال الرسالة
  final bool    hasFailed;

  /// callback عند الضغط على إعادة الإرسال
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isFirstInGroup = true,
    this.isLastInGroup  = true,
    this.isPending      = false,
    this.hasFailed      = false,
    this.onRetry,
  });

  // ── نفس fmtTime() من صفحة الويب لكن للرسائل ──
  String _fmtTime(String ts) {
    if (ts.isEmpty) return '';
    final normalized =
        (ts.contains('Z') || ts.contains('+')) ? ts : '${ts}Z';
    final d = DateTime.tryParse(normalized)?.toLocal();
    if (d == null) return '';
    return DateFormat('HH:mm').format(d);
  }

  // ── نفس منطق radius في صفحة الويب ──
  BorderRadius _radius() {
    const r  = Radius.circular(18);
    const r4 = Radius.circular(4);

    if (isMe) {
      return BorderRadius.only(
        topLeft:     r,
        topRight:    isFirstInGroup ? r : r4,
        bottomLeft:  r,
        bottomRight: isLastInGroup  ? r4 : r4,
      );
    } else {
      return BorderRadius.only(
        topLeft:     isFirstInGroup ? r : r4,
        topRight:    r,
        bottomLeft:  isLastInGroup  ? r4 : r4,
        bottomRight: r,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c       = AppColors.of(context);
    final timeStr = _fmtTime(message.timestamp);

    return Padding(
      padding: EdgeInsets.only(
        top:    isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup  ? 2 : 0,
        left:   isMe  ? 60 : 14,
        right:  isMe  ? 14 : 60,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ── الـ bubble نفسه ──
          GestureDetector(
            onLongPress: () => _onLongPress(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: isMe
                  ? AppDecorations.bubbleMe(c).copyWith(
                      borderRadius: _radius(),
                    )
                  : AppDecorations.bubbleOther(c).copyWith(
                      borderRadius: _radius(),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // نص الرسالة
                  Text(
                    message.content,
                    style: AppTextStyles.bubbleText(isMe: isMe, c: c),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),

                  // وقت + حالة الإرسال
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: AppTextStyles.bubbleTime(isMe: isMe),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _StatusIcon(
                          isPending: isPending,
                          hasFailed: hasFailed,
                          c:         c,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── زر إعادة الإرسال عند الفشل ──
          if (hasFailed && onRetry != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onRetry,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 13, color: c.red),
                  const SizedBox(width: 3),
                  Text(
                    'إعادة الإرسال',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color:    c.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Long-press: نسخ النص ──
  void _onLongPress(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الرسالة',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
        ),
        duration:        const Duration(seconds: 2),
        backgroundColor: AppColors.of(context).bg3,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  STATUS ICON — أيقونة حالة الإرسال
//  نفس المنطق من صفحة الويب (✓ / ✓✓ / ساعة)
// ═══════════════════════════════════════════════════
class _StatusIcon extends StatelessWidget {
  final bool           isPending;
  final bool           hasFailed;
  final AppColorScheme c;

  const _StatusIcon({
    required this.isPending,
    required this.hasFailed,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    if (hasFailed) {
      return Icon(Icons.error_outline_rounded, size: 13, color: c.red);
    }
    if (isPending) {
      return Icon(Icons.access_time_rounded, size: 13,
          color: Colors.white54);
    }
    // مُرسل ومؤكد
    return Icon(Icons.done_all_rounded, size: 13, color: Colors.white70);
  }
}

// ═══════════════════════════════════════════════════
//  EXTENSION — للـ BoxDecoration.copyWith مع borderRadius
//  تساعد في تطبيق radius متغير على decorations جاهزة
// ═══════════════════════════════════════════════════
extension BoxDecorationX on BoxDecoration {
  BoxDecoration copyWith({
    Color?             color,
    DecorationImage?   image,
    BoxBorder?         border,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>?   boxShadow,
    Gradient?          gradient,
    BlendMode?         backgroundBlendMode,
    BoxShape?          shape,
  }) {
    return BoxDecoration(
      color:                color             ?? this.color,
      image:                image             ?? this.image,
      border:               border            ?? this.border,
      borderRadius:         borderRadius      ?? this.borderRadius,
      boxShadow:            boxShadow         ?? this.boxShadow,
      gradient:             gradient          ?? this.gradient,
      backgroundBlendMode:  backgroundBlendMode ?? this.backgroundBlendMode,
      shape:                shape             ?? this.shape,
    );
  }
}