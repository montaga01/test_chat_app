import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  const LoginScreen({super.key, required this.themeProvider});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus   = FocusNode();
  final _passwordFocus= FocusNode();

  bool          _loading      = false;
  bool          _showPassword = false;
  String?       _error;
  List<String>  _emailHistory = [];
  bool          _showSuggestions = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    _loadEmailHistory();
  }

  Future<void> _loadEmailHistory() async {
    final h = await AppStorage.getEmailHistory();
    if (mounted) setState(() => _emailHistory = h);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════
  //  LOGIN
  // ═══════════════════════════════════════════════════
  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.login(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await AppStorage.saveSession(
        token:  data['token'],
        userId: data['user']['id'],
        name:   data['user']['name'],
        email:  data['user']['email'],
      );
      // حفظ الإيميل في التاريخ — نفس saveEmailHistory() من JS
      await AppStorage.saveEmailToHistory(_emailCtrl.text.trim());

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              HomeScreen(themeProvider: widget.themeProvider),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════
  //  EMAIL SUGGESTIONS
  // ═══════════════════════════════════════════════════
  List<String> get _filteredHistory {
    final q = _emailCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _emailHistory;
    return _emailHistory.where((e) => e.toLowerCase().contains(q)).toList();
  }

  void _pickEmail(String email) {
    _emailCtrl.text = email;
    setState(() => _showSuggestions = false);
    FocusScope.of(context).requestFocus(_passwordFocus);
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final c      = AppColors.of(context);
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide
                  ? MediaQuery.of(context).size.width * 0.3
                  : 20,
              vertical: 28,
            ),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildCard(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AppColorScheme c) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color:  c.bg2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 64,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── اللوغو ──
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.bubbleMe1, c.bubbleMe2],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: c.accentGlow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.chat_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'الرفيق',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'منصة المحادثات الفورية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 28),

          // ── تبويبات دخول / تسجيل ──
          _buildTabs(c),
          const SizedBox(height: 24),

          // ── حقل الإيميل ──
          _buildEmailField(c),
          const SizedBox(height: 14),

          // ── حقل كلمة المرور ──
          _buildPasswordField(c),
          const SizedBox(height: 12),

          // ── رسالة الخطأ ──
          if (_error != null) _buildError(c),

          const SizedBox(height: 20),

          // ── زر الدخول ──
          _buildLoginButton(c),

          const SizedBox(height: 16),

          // ── تبديل الثيم ──
          _buildThemeToggle(c),
        ],
      ),
    );
  }

  // ── تبويبات ──
  Widget _buildTabs(AppColorScheme c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // دخول — active
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.bubbleMe1, c.bubbleMe2]),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(color: c.accentGlow, blurRadius: 12),
                ],
              ),
              child: Text(
                'دخول',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // تسجيل — inactive
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, a, __) =>
                      RegisterScreen(themeProvider: widget.themeProvider),
                  transitionsBuilder: (_, a, __, child) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end:   Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'تسجيل',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.text2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── حقل الإيميل مع الاقتراحات ──
  Widget _buildEmailField(AppColorScheme c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('البريد الإلكتروني', style: AppTextStyles.label(c)),
        const SizedBox(height: 6),
        TextField(
          controller:    _emailCtrl,
          focusNode:     _emailFocus,
          keyboardType:  TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          textAlign:     TextAlign.right,
          style:         TextStyle(color: c.text, fontFamily: 'IBM Plex Sans Arabic'),
          onChanged: (_) => setState(() => _showSuggestions = true),
          onTap:    ()   => setState(() => _showSuggestions = true),
          onSubmitted: (_) {
            setState(() => _showSuggestions = false);
            FocusScope.of(context).requestFocus(_passwordFocus);
          },
          decoration: _inputDecoration(
            c: c,
            hint: 'example@mail.com',
            icon: Icons.email_outlined,
          ),
        ),
        // ── اقتراحات الإيميل ──
        if (_showSuggestions && _filteredHistory.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color:  c.bg2,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              children: _filteredHistory.map((email) {
                return InkWell(
                  onTap: () => _pickEmail(email),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: c.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            email,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13, color: c.text,
                            ),
                          ),
                        ),
                        // زر حذف من التاريخ
                        GestureDetector(
                          onTap: () async {
                            await AppStorage.removeEmailFromHistory(email);
                            await _loadEmailHistory();
                          },
                          child: Icon(Icons.close, size: 14, color: c.text3),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ── حقل كلمة المرور ──
  Widget _buildPasswordField(AppColorScheme c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('كلمة المرور', style: AppTextStyles.label(c)),
        const SizedBox(height: 6),
        TextField(
          controller:      _passwordCtrl,
          focusNode:       _passwordFocus,
          obscureText:     !_showPassword,
          textInputAction: TextInputAction.done,
          textAlign:       TextAlign.right,
          style:           TextStyle(color: c.text),
          onSubmitted: (_) {
            setState(() => _showSuggestions = false);
            if (!_loading) _login();
          },
          decoration: _inputDecoration(
            c:    c,
            hint: '••••••••',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: c.text2,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
      ],
    );
  }

  // ── رسالة الخطأ ──
  Widget _buildError(AppColorScheme c) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin:  const EdgeInsets.only(bottom: 4),
      decoration: AppDecorations.errorBox(c),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: c.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13, color: c.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── زر الدخول ──
  Widget _buildLoginButton(AppColorScheme c) {
    return GestureDetector(
      onTap: _loading ? null : () {
        setState(() => _showSuggestions = false);
        _login();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 48,
        decoration: _loading
            ? BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(10),
              )
            : AppDecorations.primaryButton(c),
        child: Center(
          child: _loading
              ? _buildLoadingDots(c)
              : Text('دخول', style: AppTextStyles.button()),
        ),
      ),
    );
  }

  // ── مؤشر التحميل (نقاط ترتد) — نفس ripple-dot من صفحة الويب ──
  Widget _buildLoadingDots(AppColorScheme c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + i * 150),
          builder: (_, v, child) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: c.text2.withOpacity(0.5 + v * 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  // ── تبديل الثيم ──
  Widget _buildThemeToggle(AppColorScheme c) {
    final isDark = widget.themeProvider.isDark;
    return GestureDetector(
      onTap: () => widget.themeProvider.toggle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 16, color: c.text2,
          ),
          const SizedBox(width: 6),
          Text(
            isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13, color: c.text2,
            ),
          ),
        ],
      ),
    );
  }

  // ── decoration مشترك للحقول ──
  InputDecoration _inputDecoration({
    required AppColorScheme c,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText:    hint,
      hintStyle:   TextStyle(color: c.text3, fontSize: 13),
      prefixIcon:  Icon(icon, color: c.text2, size: 20),
      suffixIcon:  suffix,
      filled:      true,
      fillColor:   c.bg3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
    );
  }
}