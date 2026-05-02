import 'package:flutter/foundation.dart';
import '../core/storage.dart';

// ═══════════════════════════════════════════════════
//  THEME PROVIDER
//  إدارة الوضع الليلي/النهاري مع حفظ التفضيل
// ═══════════════════════════════════════════════════
class ThemeProvider extends ChangeNotifier {
  bool _isDark = true; // افتراضي: ليلي — نفس صفحة الويب

  bool get isDark => _isDark;

  /// يُستدعى مرة واحدة في main() قبل runApp
  Future<void> init() async {
    _isDark = await AppStorage.getIsDark();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    await AppStorage.saveIsDark(_isDark);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    await AppStorage.saveIsDark(_isDark);
    notifyListeners();
  }
}