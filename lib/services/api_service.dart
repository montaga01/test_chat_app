import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/storage.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/presence.dart';

class ApiService {

  // ═══════════════════════════════════════════════════
  //  AUTH HEADERS
  // ═══════════════════════════════════════════════════
  static Future<Map<String, String>> _headers() async {
    final token = await AppStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> _headersWithToken(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ═══════════════════════════════════════════════════
  //  AUTH
  // ═══════════════════════════════════════════════════
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ في تسجيل الدخول';
    return data['data'];
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ في التسجيل';
    return data;
  }

  // ═══════════════════════════════════════════════════
  //  USERS
  // ═══════════════════════════════════════════════════
  static Future<List<ChatUser>> searchUsers(String query) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/users/search'),
      headers: await _headers(),
      body: jsonEncode({'query': query}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ في البحث';
    return (data['data'] as List).map((u) => ChatUser.fromJson(u)).toList();
  }

  // ═══════════════════════════════════════════════════
  //  CHATS
  // ═══════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getChats() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/chats'),
      headers: await _headers(),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ';
    return List<Map<String, dynamic>>.from(data['data']);
  }

  // ═══════════════════════════════════════════════════
  //  MESSAGES
  // ═══════════════════════════════════════════════════
  static Future<List<Message>> getMessages(int withUserId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/messages/$withUserId'),
      headers: await _headers(),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ';
    return (data['data'] as List).map((m) => Message.fromJson(m)).toList();
  }

  static Future<Message> sendMessage({
    required int    receiverId,
    required String content,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/messages/send'),
      headers: await _headers(),
      body: jsonEncode({'receiver_id': receiverId, 'content': content}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ في الإرسال';
    return Message.fromJson(data['data']);
  }

  // ═══════════════════════════════════════════════════
  //  PRESENCE — نفس منطق fetchPresenceHTTP() من صفحة الويب
  //  يجرب عدة endpoints لأن الباك اند قد يختلف
  // ═══════════════════════════════════════════════════
  static Future<UserPresence?> fetchPresence(int userId) async {
    final headers = await _headers();

    // نفس قائمة الـ endpoints في صفحة الويب
    final endpoints = [
      '${AppConstants.baseUrl}/api/users/$userId/presence',
      '${AppConstants.baseUrl}/api/presence/$userId',
      '${AppConstants.baseUrl}/api/users/presence?user_id=$userId',
    ];

    for (final url in endpoints) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return UserPresence.fromHttpJson(data);
        }
      } catch (_) {
        // جرب الـ endpoint التالي
      }
    }
    return null;
  }

  /// جلب presence لعدة مستخدمين دفعة واحدة
  static Future<Map<int, UserPresence>> fetchPresenceBatch(
      List<int> userIds) async {
    final result = <int, UserPresence>{};
    if (userIds.isEmpty) return result;

    // نحاول endpoint جماعي أول
    try {
      final headers = await _headers();
      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/presence/batch'),
            headers: headers,
            body: jsonEncode({'user_ids': userIds}),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List? ?? [];
        for (final item in list) {
          final uid = item['user_id'] as int?;
          if (uid != null) {
            result[uid] = UserPresence.fromHttpJson(item);
          }
        }
        return result;
      }
    } catch (_) {}

    // fallback: نجيب كل واحد على حدة
    await Future.wait(
      userIds.map((uid) async {
        final p = await fetchPresence(uid);
        if (p != null) result[uid] = p;
      }),
    );
    return result;
  }

  // ═══════════════════════════════════════════════════
  //  FCM TOKEN
  // ═══════════════════════════════════════════════════
  static Future<void> updateFcmToken(String fcmToken) async {
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/update-fcm-token'),
        headers: await _headers(),
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (_) {}
  }
}