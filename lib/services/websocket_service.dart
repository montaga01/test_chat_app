import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';
import '../models/message.dart';
import '../models/presence.dart';

// ═══════════════════════════════════════════════════
//  WS EVENT TYPES — نفس أنواع الرسائل في صفحة الويب
// ═══════════════════════════════════════════════════
enum WsEventType { message, presence, onlineUsers, typing, error, unknown }

class WsEvent {
  final WsEventType type;
  final Map<String, dynamic> raw;

  const WsEvent({required this.type, required this.raw});

  static WsEventType _detect(Map<String, dynamic> json) {
    final t = json['type'];
    if (t == 'presence')     return WsEventType.presence;
    if (t == 'online_users') return WsEventType.onlineUsers;
    if (t == 'typing')       return WsEventType.typing;
    if (json['error'] != null) return WsEventType.error;
    if (json['status'] == 'sent') return WsEventType.unknown; // تأكيد الإرسال
    if (json['sender_id'] != null) return WsEventType.message;
    return WsEventType.unknown;
  }

  factory WsEvent.fromJson(Map<String, dynamic> json) =>
      WsEvent(type: _detect(json), raw: json);
}

// ═══════════════════════════════════════════════════
//  WEBSOCKET SERVICE
// ═══════════════════════════════════════════════════
class WebSocketService {
  WebSocketChannel?      _channel;
  StreamSubscription?    _sub;
  Timer?                 _pingTimer;
  Timer?                 _reconnectTimer;

  String  _token       = '';
  bool    _intentClose = false; // أغلقناه نحن بقصد
  int     _retryCount  = 0;

  // ── Streams ──
  final _messageCtrl  = StreamController<Message>.broadcast();
  final _presenceCtrl = StreamController<WsEvent>.broadcast();
  final _typingCtrl   = StreamController<WsEvent>.broadcast();
  final _connectedCtrl= StreamController<bool>.broadcast();

  Stream<Message>  get messages   => _messageCtrl.stream;
  Stream<WsEvent>  get presences  => _presenceCtrl.stream;
  Stream<WsEvent>  get typings    => _typingCtrl.stream;
  Stream<bool>     get connected  => _connectedCtrl.stream;

  bool get isConnected =>
      _channel != null &&
      _channel!.closeCode == null;

  // ═══════════════════════════════════════════════════
  //  CONNECT
  // ═══════════════════════════════════════════════════
  void connect(String token) {
    _token       = token;
    _intentClose = false;
    _doConnect();
  }

  void _doConnect() {
    _cleanup();

    try {
      final uri = Uri.parse('${AppConstants.wsUrl}/$_token');
      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone:  _onDone,
      );

      // أعلن online عند الاتصال
      _onConnected();

    } catch (e) {
      print('WebSocket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onConnected() {
    _retryCount = 0;
    _connectedCtrl.add(true);

    // أعلن حالة online — نفس ws.onopen في صفحة الويب
    _send({'type': 'presence', 'online': true});

    // ping كل 25 ثانية — نفس setInterval في صفحة الويب
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isConnected) _sendRaw('ping');
    });
  }

  // ═══════════════════════════════════════════════════
  //  DATA HANDLER
  // ═══════════════════════════════════════════════════
  void _onData(dynamic data) {
    if (data == 'pong') return; // رد على ping

    Map<String, dynamic> json;
    try {
      json = jsonDecode(data as String);
    } catch (_) {
      return;
    }

    final event = WsEvent.fromJson(json);

    switch (event.type) {
      case WsEventType.presence:
        _presenceCtrl.add(event);

      case WsEventType.onlineUsers:
        _presenceCtrl.add(event);

      case WsEventType.typing:
        _typingCtrl.add(event);

      case WsEventType.message:
        try {
          // أضف timestamp لو مش موجود — نفس صفحة الويب
          if (json['timestamp'] == null) {
            json['timestamp'] = DateTime.now().toUtc().toIso8601String();
          }
          _messageCtrl.add(Message.fromJson(json));
        } catch (e) {
          print('Message parse error: $e');
        }

      case WsEventType.error:
        print('WS error from server: ${json['error']}');

      case WsEventType.unknown:
        break;
    }
  }

  void _onError(Object e) {
    print('WebSocket error: $e');
    _connectedCtrl.add(false);
    _scheduleReconnect();
  }

  void _onDone() {
    _connectedCtrl.add(false);
    if (!_intentClose) {
      print('WebSocket closed unexpectedly, reconnecting...');
      _scheduleReconnect();
    }
  }

  // ═══════════════════════════════════════════════════
  //  RECONNECT — exponential backoff مثل صفحة الويب
  // ═══════════════════════════════════════════════════
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_intentClose || _token.isEmpty) return;

    // 3s, 6s, 12s, 24s ... max 60s
    final delay = Duration(
      seconds: (_retryCount < 5)
          ? 3 * (1 << _retryCount).clamp(1, 20)
          : 60,
    );
    _retryCount++;

    print('Reconnecting in ${delay.inSeconds}s (attempt $_retryCount)...');
    _reconnectTimer = Timer(delay, _doConnect);
  }

  // ═══════════════════════════════════════════════════
  //  SEND HELPERS
  // ═══════════════════════════════════════════════════
  void sendMessage({required int receiverId, required String content}) {
    _send({'receiver_id': receiverId, 'content': content});
  }

  /// أعلن presence — نفس ws.send({type:'presence'}) في صفحة الويب
  void sendPresence({required bool online}) {
    _send({'type': 'presence', 'online': online});
  }

  /// أرسل typing indicator — نفس sendTyping() في صفحة الويب
  void sendTyping({required int receiverId}) {
    _send({'type': 'typing', 'receiver_id': receiverId});
  }

  /// اطلب presence مستخدم واحد
  void requestPresence(int userId) {
    _send({'type': 'get_presence', 'user_ids': [userId]});
  }

  /// اطلب presence مجموعة مستخدمين — نفس requestPresenceBatch() من صفحة الويب
  void requestPresenceBatch(List<int> userIds) {
    if (userIds.isEmpty) return;
    _send({'type': 'get_presence', 'user_ids': userIds});
  }

  void _send(Map<String, dynamic> data) {
    if (!isConnected) return;
    _sendRaw(jsonEncode(data));
  }

  void _sendRaw(String text) {
    try {
      _channel?.sink.add(text);
    } catch (e) {
      print('WS send error: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  //  VISIBILITY CHANGE — نفس visibilitychange في صفحة الويب
  // ═══════════════════════════════════════════════════

  /// استدعيها عند رجوع التطبيق للأمام (AppLifecycleState.resumed)
  void onAppResumed() {
    if (isConnected) {
      sendPresence(online: true);
    } else {
      _doConnect();
    }
  }

  /// استدعيها عند ذهاب التطبيق للخلفية (AppLifecycleState.paused)
  void onAppPaused() {
    sendPresence(online: false);
  }

  // ═══════════════════════════════════════════════════
  //  DISCONNECT & DISPOSE
  // ═══════════════════════════════════════════════════
  void disconnect() {
    _intentClose = true;
    // أعلن offline قبل الإغلاق — نفس logout() في صفحة الويب
    sendPresence(online: false);
    _cleanup();
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub     = null;
  }

  void dispose() {
    disconnect();
    _messageCtrl.close();
    _presenceCtrl.close();
    _typingCtrl.close();
    _connectedCtrl.close();
  }
}