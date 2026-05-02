import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/storage.dart';
import '../models/user.dart';
import '../models/message.dart';

class ApiService {
  // ========== Auth Headers ==========
  static Future<Map<String, String>> _headers() async {
    final token = await AppStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ========== تسجيل دخول ==========
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

  // ========== تسجيل حساب ==========
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

  // ========== البحث عن مستخدمين ==========
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

  // ========== قائمة المحادثات ==========
  static Future<List<Map<String, dynamic>>> getChats() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/chats'),
      headers: await _headers(),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ';
    return List<Map<String, dynamic>>.from(data['data']);
  }

  // ========== رسائل محادثة ==========
  static Future<List<Message>> getMessages(int withUserId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/messages/$withUserId'),
      headers: await _headers(),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw data['detail'] ?? 'خطأ';
    return (data['data'] as List).map((m) => Message.fromJson(m)).toList();
  }

  // ========== إرسال رسالة (HTTP fallback) ==========
  static Future<Message> sendMessage({
    required int receiverId,
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
}
