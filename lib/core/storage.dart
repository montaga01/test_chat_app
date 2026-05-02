import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const _tokenKey        = 'auth_token';
  static const _userIdKey       = 'user_id';
  static const _userNameKey     = 'user_name';
  static const _userEmailKey    = 'user_email';
  static const _themeKey        = 'is_dark_theme';
  static const _emailHistoryKey = 'email_history';

  // ═══════════════════════════════════════════════════
  //  SESSION
  // ═══════════════════════════════════════════════════
  static Future<void> saveSession({
    required String token,
    required int    userId,
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey,     token);
    await prefs.setInt   (_userIdKey,    userId);
    await prefs.setString(_userNameKey,  name);
    await prefs.setString(_userEmailKey, email);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// تمسح بيانات الجلسة فقط وتحتفظ بالثيم + تاريخ الإيميلات
  static Future<void> clear() async {
    final prefs        = await SharedPreferences.getInstance();
    final isDark       = prefs.getBool(_themeKey);
    final emailHistory = prefs.getStringList(_emailHistoryKey);
    await prefs.clear();
    if (isDark != null)       await prefs.setBool(_themeKey, isDark);
    if (emailHistory != null) await prefs.setStringList(_emailHistoryKey, emailHistory);
  }

  // ═══════════════════════════════════════════════════
  //  THEME
  // ═══════════════════════════════════════════════════

  /// افتراضي: وضع ليلي — نفس صفحة الويب
  static Future<bool> getIsDark() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true;
  }

  static Future<void> saveIsDark(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  // ═══════════════════════════════════════════════════
  //  EMAIL HISTORY — نفس منطق localStorage في صفحة الويب
  // ═══════════════════════════════════════════════════

  static Future<List<String>> getEmailHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_emailHistoryKey) ?? [];
  }

  static Future<void> saveEmailToHistory(String email) async {
    if (email.isEmpty) return;
    final prefs   = await SharedPreferences.getInstance();
    var   history = prefs.getStringList(_emailHistoryKey) ?? [];
    history
      ..removeWhere((e) => e == email)
      ..insert(0, email);
    if (history.length > 5) history = history.sublist(0, 5);
    await prefs.setStringList(_emailHistoryKey, history);
  }

  static Future<void> removeEmailFromHistory(String email) async {
    final prefs   = await SharedPreferences.getInstance();
    final history = (prefs.getStringList(_emailHistoryKey) ?? [])
        ..removeWhere((e) => e == email);
    await prefs.setStringList(_emailHistoryKey, history);
  }
}