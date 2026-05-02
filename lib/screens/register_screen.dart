import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  const RegisterScreen({super.key, required this.themeProvider});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameFocus    = FocusNode();
  final _emailFocus   = FocusNode();
  final _passwordFocus= FocusNode();

  bool    _loading      = false;
  bool    _showPassword = false;
  String? _error;

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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════
  //  REGISTER
  // ═══════════════════════════════════════════════════
  Future<void> _register() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'يرجى ملء جميع الحقول');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.register(name: name, email: email, password: pass);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'تم إنشاء الحساب! سجّل دخولك الآن',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF3fb950),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );

      // انتقل لشاشة الدخول
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              LoginScreen(themeProvider: widget.themeProvider),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end:   Offset.zero,
            ).animate(a),
            child: child,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              gradient: LinearGradient(colors: [c.bubbleMe1, c.bubbleMe2]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: c.accentGlow, blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'الرفيق',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 24, fontWeight: FontWeight.w700, color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'منصة المحادثات الفورية',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.text2),
          ),
          const SizedBox(height: 28),

          // ── تبويبات ──
          _buildTabs(c),
          const SizedBox(height: 24),

          // ── الاسم ──
          _buildField(
            c: c, label: 'الاسم', hint: 'اسمك الكريم',
            icon: Icons.person_outline,
            controller: _nameCtrl, focusNode: _nameFocus,
            nextFocus: _emailFocus,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          // ── الإيميل ──
          _buildField(
            c: c, label: 'البريد الإلكتروني', hint: 'example@mail.com',
            icon: Icons.email_outlined,
            controller: _emailCtrl, focusNode: _emailFocus,
            nextFocus: _passwordFocus,
            action: TextInputAction.next,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          // ── كلمة المرور ──
          _buildPasswordField(c),
          const SizedBox(height: 12),

          // ── رسالة الخطأ ──
          if (_error != null) _buildError(c),

          const SizedBox(height: 20),

          // ── زر إنشاء الحساب ──
          _buildRegisterButton(c),

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
          // دخول — inactive
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, a, __) =>
                      LoginScreen(themeProvider: widget.themeProvider),
                  transitionsBuilder: (_, a, __, child) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1, 0),
                      end:   Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'دخول',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14, fontWeight: FontWeight.w500, color: c.text2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // تسجيل — active
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.bubbleMe1, c.bubbleMe2]),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [BoxShadow(color: c.accentGlow, blurRadius: 12)],
              ),
              child: Text(
                'تسجيل',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── حقل عام ──
  Widget _buildField({
    required AppColorScheme c,
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    TextInputAction action = TextInputAction.next,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(c)),
        const SizedBox(height: 6),
        TextField(
          controller:      controller,
          focusNode:       focusNode,
          keyboardType:    keyboard,
          textInputAction: action,
          textAlign:       TextAlign.right,
          style:           TextStyle(color: c.text),
          onSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
          decoration: _inputDecoration(c: c, hint: hint, icon: icon),
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
          onSubmitted: (_) { if (!_loading) _register(); },
          decoration: _inputDecoration(
            c:    c,
            hint: '6 أحرف على الأقل',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: c.text2, size: 20,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
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
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.red),
            ),
          ),
        ],
      ),
    );
  }

  // ── زر إنشاء الحساب ──
  Widget _buildRegisterButton(AppColorScheme c) {
    return GestureDetector(
      onTap: _loading ? null : _register,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:  double.infinity,
        height: 48,
        decoration: _loading
            ? BoxDecoration(color: c.bg3, borderRadius: BorderRadius.circular(10))
            : AppDecorations.primaryButton(c),
        child: Center(
          child: _loading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    color: c.text2, strokeWidth: 2,
                  ),
                )
              : Text('إنشاء حساب', style: AppTextStyles.button()),
        ),
      ),
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
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.text2),
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
      hintText:   hint,
      hintStyle:  TextStyle(color: c.text3, fontSize: 13),
      prefixIcon: Icon(icon, color: c.text2, size: 20),
      suffixIcon: suffix,
      filled:     true,
      fillColor:  c.bg3,
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