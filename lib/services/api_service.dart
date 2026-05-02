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
    // ✅ إصلاح: تحقق من 200 و 201 معاً (بعض السيرفرات ترجع 201 عند الإنشاء)
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw data['detail'] ?? 'خطأ في التسجيل';
    }
    // ✅ إصلاح: أرجع data['data'] بدلاً من data الكاملة — بنية موحدة مع login
    return data['data'] as Map<String, dynamic>;
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

  // ✅ إضافة: markRead كانت مستدعاة في chat_screen لكن مش موجودة
  static Future<void> markRead(int peerId) async {
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/chats/$peerId/read'),
        headers: await _headers(),
      );
    } catch (_) {
      // صامت — عدم تحديث القراءة لا يكسر التطبيق
    }
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
  //  PRESENCE
  //  ✅ إصلاح: الـ endpoints الصحيحة اللي موجودة فعلاً في الباك اند
  // ═══════════════════════════════════════════════════
  static Future<UserPresence?> fetchPresence(int userId) async {
    final headers = await _headers();
    try {
      final res = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/api/users/$userId/presence'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return UserPresence.fromHttpJson(data);
      }
    } catch (_) {
      // السيرفر مش متاح أو timeout
    }
    return null;
  }

  /// جلب presence لعدة مستخدمين دفعة واحدة
  /// ✅ إصلاح: endpoint صحيح /api/presence/batch موجود في الباك اند
  static Future<Map<int, UserPresence>> fetchPresenceBatch(
      List<int> userIds) async {
    final result = <int, UserPresence>{};
    if (userIds.isEmpty) return result;

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

    // fallback: كل مستخدم على حدة
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