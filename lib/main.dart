import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/storage.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlrafeegApp());
}

class AlrafeegApp extends StatelessWidget {
  const AlrafeegApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الرفيق',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1a56db),
        scaffoldBackgroundColor: const Color(0xFFf0f4ff),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a56db),
          primary: const Color(0xFF1a56db),
          secondary: const Color(0xFF1e429f),
          surface: const Color(0xFFffffff),
        ),
        textTheme: GoogleFonts.tajawalTextTheme(
          const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFffffff),
          foregroundColor: Color(0xFF1a2340),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const _Splash(),
    );
  }
}

/// شاشة البداية: تتحقق من التوكن وتوجّه للشاشة الصحيحة
class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await AppStorage.getToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => token != null ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1a56db),
              Color(0xFF1e429f),
              Color(0xFF0f2a6e),
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
