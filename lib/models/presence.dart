// ═══════════════════════════════════════════════════
//  PRESENCE MODEL
//  نفس منطق كائن presence{} من صفحة الويب
//  { userId: { online: bool, last_seen: string|null } }
// ═══════════════════════════════════════════════════

class UserPresence {
  final bool    online;
  final DateTime? lastSeen;

  const UserPresence({
    required this.online,
    this.lastSeen,
  });

  /// من رسالة WebSocket presence
  factory UserPresence.fromWsJson(Map<String, dynamic> json) {
    return UserPresence(
      online:   json['online'] == true,
      lastSeen: _parseDate(json['last_seen']),
    );
  }

  /// من HTTP response
  factory UserPresence.fromHttpJson(Map<String, dynamic> json) {
    final p = json['data'] ?? json;
    return UserPresence(
      online:   p['online'] == true,
      lastSeen: _parseDate(p['last_seen'] ?? p['lastSeen']),
    );
  }

  /// مستخدم متصل حالياً
  factory UserPresence.online() => UserPresence(
        online:   true,
        lastSeen: DateTime.now(),
      );

  /// مستخدم غير متصل
  factory UserPresence.offline({DateTime? lastSeen}) => UserPresence(
        online:   false,
        lastSeen: lastSeen ?? DateTime.now(),
      );

  UserPresence copyWith({bool? online, DateTime? lastSeen}) => UserPresence(
        online:   online   ?? this.online,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  // ═══════════════════════════════════════════════════
  //  LAST SEEN TEXT — نفس دالة fmtLastSeen() من JS
  // ═══════════════════════════════════════════════════
  String get lastSeenText {
    if (online) return 'متصل';
    if (lastSeen == null) return 'آخر ظهور مؤخراً';

    final now     = DateTime.now();
    final diff    = now.difference(lastSeen!);
    final minutes = diff.inMinutes;
    final hours   = diff.inHours;
    final days    = diff.inDays;

    if (minutes < 1)  return 'آخر ظهور الآن';
    if (minutes < 2)  return 'آخر ظهور منذ دقيقة';
    if (minutes < 60) return 'آخر ظهور منذ $minutes دقيقة';

    final timeStr = _fmtTime(lastSeen!);

    if (hours < 24)  return 'آخر ظهور الساعة $timeStr';
    if (days == 1)   return 'آخر ظهور أمس الساعة $timeStr';
    if (days < 7) {
      return 'آخر ظهور ${_weekdayAr(lastSeen!.weekday)}';
    }
    return 'آخر ظهور ${lastSeen!.day}/${lastSeen!.month}';
  }

  // ── helpers ──
  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    final s = val.toString();
    if (s.isEmpty) return null;
    // أضف Z لو مافيش timezone
    final normalized = (s.contains('Z') || s.contains('+')) ? s : '${s}Z';
    return DateTime.tryParse(normalized)?.toLocal();
  }

  static String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _weekdayAr(int weekday) {
    const days = ['', 'الاثنين', 'الثلاثاء', 'الأربعاء',
                  'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[weekday];
  }

  @override
  String toString() =>
      'UserPresence(online: $online, lastSeen: $lastSeen)';
}

// ═══════════════════════════════════════════════════
//  PRESENCE MAP — خريطة حالات الاتصال لكل المستخدمين
//  نفس كائن presence{} في صفحة الويب
// ═══════════════════════════════════════════════════
class PresenceMap {
  final Map<int, UserPresence> _map = {};

  bool isOnline(int userId) => _map[userId]?.online ?? false;

  UserPresence? get(int userId) => _map[userId];

  void setOnline(int userId) {
    _map[userId] = UserPresence.online();
  }

  void setOffline(int userId, {DateTime? lastSeen}) {
    _map[userId] = UserPresence.offline(lastSeen: lastSeen);
  }

  void update(int userId, UserPresence presence) {
    _map[userId] = presence;
  }

  void updateFromWs(Map<String, dynamic> json) {
    final uid = json['user_id'];
    if (uid == null) return;
    _map[uid as int] = UserPresence.fromWsJson(json);
  }

  /// عند إغلاق WebSocket — كل المتصلين يصبحون غير متصلين
  void setAllOffline() {
    for (final uid in _map.keys) {
      if (_map[uid]!.online) {
        _map[uid] = _map[uid]!.copyWith(
          online:   false,
          lastSeen: DateTime.now(),
        );
      }
    }
  }

  String lastSeenText(int userId) =>
      _map[userId]?.lastSeenText ?? 'آخر ظهور مؤخراً';

  List<int> get onlineUserIds =>
      _map.entries.where((e) => e.value.online).map((e) => e.key).toList();
}