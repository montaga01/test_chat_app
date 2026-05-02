import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import 'avatar_widget.dart';

class ChatTile extends StatelessWidget {
  final String       name;
  final String       lastMessage;
  final String       timestamp;
  final int          unreadCount;
  final bool         isOnline;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.onTap,
    this.unreadCount = 0,
    this.isOnline    = false,
  });

  // ── نفس fmtTime() من صفحة الويب ──
  String _fmtTime(String ts) {
    if (ts.isEmpty) return '';
    final normalized =
        (ts.contains('Z') || ts.contains('+')) ? ts : '${ts}Z';
    final d = DateTime.tryParse(normalized)?.toLocal();
    if (d == null) return '';

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(d.year, d.month, d.day);
    final diff  = today.difference(day).inDays;

    if (diff == 0) return DateFormat('HH:mm').format(d);
    if (diff == 1) return 'أمس';
    if (diff < 7) {
      const days = [
        '', 'الاثنين', 'الثلاثاء', 'الأربعاء',
        'الخميس', 'الجمعة', 'السبت', 'الأحد',
      ];
      return days[d.weekday];
    }
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final c         = AppColors.of(context);
    final timeStr   = _fmtTime(timestamp);
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap:          onTap,
      splashColor:    c.accent.withOpacity(0.08),
      highlightColor: c.bg3.withOpacity(0.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // ── Avatar مع online dot ──
            AvatarWidget(name: name, size: 42, isOnline: isOnline),
            const SizedBox(width: 12),

            // ── معلومات المحادثة ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم + وقت
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize:   14,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize:   11,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: hasUnread ? c.accent : c.text2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // آخر رسالة + badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize:   12,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: c.text2,
                          ),
                        ),
                      ),
                      // ── Unread count badge ──
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        _UnreadBadge(count: unreadCount, c: c),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  UNREAD BADGE — رقم دائري بدل النقطة
// ═══════════════════════════════════════════════════
class _UnreadBadge extends StatelessWidget {
  final int            count;
  final AppColorScheme c;
  const _UnreadBadge({required this.count, required this.c});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color:         c.accent,
        borderRadius:  BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: c.accentGlow, blurRadius: 6),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize:   11,
          fontWeight: FontWeight.w700,
          color:      Colors.white,
          height:     1.2,
        ),
      ),
    );
  }
}