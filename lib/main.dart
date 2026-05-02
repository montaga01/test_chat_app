import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/storage.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  runApp(AlrafeegApp(themeProvider: themeProvider));
}

class AlrafeegApp extends StatefulWidget {
  final ThemeProvider themeProvider;
  const AlrafeegApp({super.key, required this.themeProvider});

  @override
  State<AlrafeegApp> createState() => _AlrafeegAppState();
}

class _AlrafeegAppState extends State<AlrafeegApp> {
  @override
  void initState() {
    super.initState();
    widget.themeProvider.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    widget.themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeProvider.isDark;

    // ضبط شريط الحالة حسب الثيم
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark
          ? AppColors.dark.bg2
          : AppColors.light.bg2,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp(
      title: 'الرفيق',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: _Splash(themeProvider: widget.themeProvider),
    );
  }

  ThemeData _buildLightTheme() {
    final colors = AppColors.light;
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF2f81f7),
      scaffoldBackgroundColor: colors.bg,
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF2f81f7),
        secondary: const Color(0xFF1f6feb),
        surface: colors.bg2,
        onSurface: colors.text,
      ),
      textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
        TextTheme(
          displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: colors.text),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: colors.text),
          headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.text),
          titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text),
          bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: colors.text),
          bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: colors.text),
          bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: colors.text2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg2,
        foregroundColor: colors.text,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerColor: colors.border,
      cardColor: colors.bg2,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.bg3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2f81f7), width: 1.5),
        ),
        labelStyle: TextStyle(color: colors.text2),
        hintStyle: TextStyle(color: colors.text2),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colors = AppColors.dark;
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF2f81f7),
      scaffoldBackgroundColor: colors.bg,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF2f81f7),
        secondary: const Color(0xFF1f6feb),
        surface: colors.bg2,
        onSurface: colors.text,
      ),
      textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
        TextTheme(
          displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: colors.text),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: colors.text),
          headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.text),
          titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text),
          bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: colors.text),
          bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: colors.text),
          bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: colors.text2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg2,
        foregroundColor: colors.text,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dividerColor: colors.border,
      cardColor: colors.bg2,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.bg3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2f81f7), width: 1.5),
        ),
        labelStyle: TextStyle(color: colors.text2),
        hintStyle: TextStyle(color: colors.text2),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  SPLASH — يتحقق من التوكن ويوجّه للشاشة الصحيحة
// ═══════════════════════════════════════════════════
class _Splash extends StatefulWidget {
  final ThemeProvider themeProvider;
  const _Splash({required this.themeProvider});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _check();
  }

  Future<void> _check() async {
    // انتظر الأنيميشن يكمل + تحقق من التوكن
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 800)),
      Future.value(AppStorage.getToken()),
    ]);
    final token = await AppStorage.getToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => token != null
            ? HomeScreen(themeProvider: widget.themeProvider)
            : LoginScreen(themeProvider: widget.themeProvider),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      body: FadeTransition(
        opacity: _fade,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF2f81f7),
                Color(0xFF1f6feb),
                Color(0xFF0d1117),
              ],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // اللوغو
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2f81f7), Color(0xFF1f6feb)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2f81f7).withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'الرفيق',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'منصة المحادثات الفورية',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.7),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

