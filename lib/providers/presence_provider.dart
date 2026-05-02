import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/presence.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

// ═══════════════════════════════════════════════════
//  PRESENCE PROVIDER
//  نفس كائن presence{} + منطق typing من صفحة الويب
//  مركزي — يُنشأ مرة واحدة ويُمرر للشاشات
// ═══════════════════════════════════════════════════
class PresenceProvider extends ChangeNotifier {
  final WebSocketService _ws;

  final PresenceMap _presenceMap = PresenceMap();

  // typing: { userId: Timer }
  final Map<int, Timer> _typingTimers = {};
  final Set<int>        _typingUsers  = {};

  StreamSubscription? _presenceSub;
  StreamSubscription? _typingSub;

  PresenceProvider(this._ws) {
    _listenPresence();
    _listenTyping();
  }

  // ═══════════════════════════════════════════════════
  //  GETTERS
  // ═══════════════════════════════════════════════════
  bool isOnline(int userId)          => _presenceMap.isOnline(userId);
  UserPresence? getPresence(int uid) => _presenceMap.get(uid);
  String lastSeenText(int userId)    => _presenceMap.lastSeenText(userId);
  bool isTyping(int userId)          => _typingUsers.contains(userId);

  // ═══════════════════════════════════════════════════
  //  LISTEN — WebSocket streams
  // ═══════════════════════════════════════════════════
  void _listenPresence() {
    _presenceSub = _ws.presences.listen((event) {
      final json = event.raw;

      // ── online_users (قائمة) ──
      if (json['type'] == 'online_users') {
        final ids = (json['user_ids'] ?? json['users'] ?? []) as List;
        for (final uid in ids) {
          _presenceMap.setOnline(uid as int);
        }
        notifyListeners();
        return;
      }

      // ── presence فردي ──
      final uid = json['user_id'] as int?;
      if (uid == null) return;
      _presenceMap.updateFromWs(json);
      notifyListeners();
    });
  }

  void _listenTyping() {
    _typingSub = _ws.typings.listen((event) {
      final from =
          (event.raw['sender_id'] ?? event.raw['user_id']) as int?;
      if (from == null) return;
      _showTyping(from);
    });
  }

  // ═══════════════════════════════════════════════════
  //  TYPING — نفس handleTypingEvent() من صفحة الويب
  // ═══════════════════════════════════════════════════
  void _showTyping(int userId) {
    _typingUsers.add(userId);
    notifyListeners();

    // إخفاء بعد 3 ثوانٍ — نفس setTimeout(3000) في صفحة الويب
    _typingTimers[userId]?.cancel();
    _typingTimers[userId] = Timer(const Duration(seconds: 3), () {
      _hideTyping(userId);
    });
  }

  void _hideTyping(int userId) {
    _typingUsers.remove(userId);
    _typingTimers.remove(userId);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  //  REQUEST PRESENCE
  // ═══════════════════════════════════════════════════

  /// اطلب presence لمجموعة مستخدمين
  /// نفس requestPresenceBatch() + fetchPresenceHTTP() من صفحة الويب
  Future<void> refreshBatch(List<int> userIds) async {
    if (userIds.isEmpty) return;

    // 1. اطلب من WS
    _ws.requestPresenceBatch(userIds);

    // 2. HTTP fallback
    final results = await ApiService.fetchPresenceBatch(userIds);
    results.forEach((uid, p) => _presenceMap.update(uid, p));
    if (results.isNotEmpty) notifyListeners();
  }

  /// اطلب presence مستخدم واحد (عند فتح محادثة)
  Future<void> refreshUser(int userId) async {
    _ws.requestPresence(userId);

    final p = await ApiService.fetchPresence(userId);
    if (p != null) {
      _presenceMap.update(userId, p);
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════
  //  WS LIFECYCLE
  // ═══════════════════════════════════════════════════

  /// عند انقطاع WS — نفس ws.onclose في صفحة الويب
  void onWsDisconnected() {
    _presenceMap.setAllOffline();
    notifyListeners();
  }

  /// تحديث من رسالة واردة — المُرسل متصل بالتأكيد
  void markOnlineFromMessage(int userId, String? timestamp) {
    DateTime? lastSeen;
    if (timestamp != null) {
      final normalized = timestamp.contains('Z') || timestamp.contains('+')
          ? timestamp
          : '${timestamp}Z';
      lastSeen = DateTime.tryParse(normalized)?.toLocal();
    }
    _presenceMap.update(
      userId,
      UserPresence(online: true, lastSeen: lastSeen ?? DateTime.now()),
    );
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  //  DISPOSE
  // ═══════════════════════════════════════════════════
  @override
  void dispose() {
    _presenceSub?.cancel();
    _typingSub?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}