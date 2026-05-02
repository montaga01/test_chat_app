import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../providers/theme_provider.dart';
import '../providers/presence_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/chat_tile.dart';
import '../widgets/avatar_widget.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  const HomeScreen({super.key, required this.themeProvider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ── services ──
  final _ws              = WebSocketService();
  late  PresenceProvider _presenceProvider;

  // ── state ──
  List<Map<String, dynamic>> _chats    = [];
  final Map<int, int>        _unread   = {}; // userId → unread count
  bool                       _loading  = true;
  bool                       _wsConnected = false;
  String                     _myName   = '';
  int                        _myId     = 0;

  StreamSubscription? _msgSub;
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _presenceProvider = PresenceProvider(_ws);
    _init();
  }

  Future<void> _init() async {
    _myName = await AppStorage.getUserName() ?? '';
    _myId   = await AppStorage.getUserId()   ?? 0;
    final token = await AppStorage.getToken() ?? '';

    // اتصل بـ WebSocket
    _ws.connect(token);

    // استمع لحالة الاتصال
    _connSub = _ws.connected.listen((connected) {
      if (mounted) setState(() => _wsConnected = connected);
      if (!connected) _presenceProvider.onWsDisconnected();
    });

    // استمع للرسائل الواردة — نفس ws.onmessage في صفحة الويب
    _msgSub = _ws.messages.listen(_onNewMessage);

    await _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final chats = await ApiService.getChats();
      if (!mounted) return;
      setState(() { _chats = chats; _loading = false; });

      // اطلب presence لكل المستخدمين — نفس requestPresenceBatch() من JS
      final ids = chats.map<int>((c) => c['user_id'] as int).toList();
      await _presenceProvider.refreshBatch(ids);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onNewMessage(Message msg) {
    if (!mounted) return;
    final peerId = msg.senderId == _myId ? msg.receiverId : msg.senderId;

    // تحديث قائمة المحادثات
    final idx = _chats.indexWhere((c) => c['user_id'] == peerId);
    final entry = {
      'user_id':   peerId,
      'name':      idx >= 0 ? _chats[idx]['name'] : '...',
      'content':   msg.content,
      'timestamp': msg.timestamp.toUtc().toIso8601String(),
    };
    if (idx >= 0) _chats.removeAt(idx);
    _chats.insert(0, entry);

    // زيادة عداد الرسائل غير المقروءة — نفس unread.add() من JS
    if (msg.senderId != _myId) {
      _unread[peerId] = (_unread[peerId] ?? 0) + 1;
    }

    // تحديث presence المُرسل
    _presenceProvider.markOnlineFromMessage(
      msg.senderId,
      msg.timestamp.toUtc().toIso8601String(),
    );

    setState(() {});
  }

  void _clearUnread(int userId) {
    if (_unread.containsKey(userId)) {
      setState(() => _unread.remove(userId));
    }
  }

  // ── فتح محادثة ──
  void _openChat(int userId, String name) {
    _clearUnread(userId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUser:        ChatUser(id: userId, name: name, email: ''),
          themeProvider:    widget.themeProvider,
          presenceProvider: _presenceProvider,
          wsService:        _ws,
          myId:             _myId,
        ),
      ),
    ).then((_) => _loadChats());
  }

  // ── بحث ──
  void _openSearch() async {
    final user = await showSearch<ChatUser?>(
      context: context,
      delegate: _UserSearchDelegate(
        colors:           AppColors.of(context),
        presenceProvider: _presenceProvider,
      ),
    );
    if (user != null && mounted) {
      _clearUnread(user.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUser:        user,
            themeProvider:    widget.themeProvider,
            presenceProvider: _presenceProvider,
            wsService:        _ws,
            myId:             _myId,
          ),
        ),
      ).then((_) => _loadChats());
    }
  }

  // ── تسجيل الخروج ──
  void _logout() async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.bold, color: c.text,
          ),
        ),
        content: Text(
          'هل أنت متأكد من تسجيل الخروج؟',
          style: GoogleFonts.ibmPlexSansArabic(color: c.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(color: c.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('خروج',
                style: GoogleFonts.ibmPlexSansArabic(color: c.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _ws.disconnect();
      await AppStorage.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(themeProvider: widget.themeProvider),
        ),
      );
    }
  }

  // ── AppLifecycle — نفس visibilitychange في صفحة الويب ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ws.onAppResumed();
      if (_myId > 0) _presenceProvider.refreshBatch(
        _chats.map<int>((c) => c['user_id'] as int).toList(),
      );
    } else if (state == AppLifecycleState.paused) {
      _ws.onAppPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgSub?.cancel();
    _connSub?.cancel();
    _presenceProvider.dispose();
    _ws.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ListenableBuilder(
      listenable: _presenceProvider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: c.bg,
          appBar: _buildAppBar(c),
          body: _loading
              ? _buildSkeleton(c)
              : _chats.isEmpty
                  ? _buildEmpty(c)
                  : _buildChatList(c),
          floatingActionButton: FloatingActionButton(
            onPressed: _openSearch,
            backgroundColor: c.accent,
            elevation: 6,
            child: const Icon(Icons.edit_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  // ── AppBar ──
  PreferredSizeWidget _buildAppBar(AppColorScheme c) {
    return AppBar(
      backgroundColor: c.bg2,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: c.border, height: 1),
      ),
      title: Row(
        children: [
          // اسم التطبيق + نقطة الاتصال — نفس topbar من صفحة الويب
          Text('الرفيق ', style: AppTextStyles.appTitle(c)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _wsConnected ? c.green : c.text3,
              boxShadow: _wsConnected
                  ? [BoxShadow(color: c.greenGlow, blurRadius: 6)]
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        // اسم المستخدم
        Center(
          child: Text(
            _myName,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13, color: c.text2,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // زر البحث
        _iconBtn(
          icon: Icons.search_rounded,
          color: c,
          onTap: _openSearch,
        ),

        // زر تبديل الثيم
        _iconBtn(
          icon: widget.themeProvider.isDark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          color: c,
          onTap: () => widget.themeProvider.toggle(),
        ),

        // زر تسجيل الخروج — أيقونة واضحة (power_settings_new)
        _iconBtn(
          icon: Icons.power_settings_new_rounded,
          color: c,
          onTap: _logout,
          iconColor: c.red,
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required AppColorScheme color,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.bg3,
          border: Border.all(color: color.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? color.text2),
      ),
    );
  }

  // ── قائمة المحادثات ──
  Widget _buildChatList(AppColorScheme c) {
    return RefreshIndicator(
      onRefresh: _loadChats,
      color: c.accent,
      backgroundColor: c.bg2,
      child: ListView.separated(
        itemCount: _chats.length,
        separatorBuilder: (_, __) => Container(
          color: c.border, height: 1,
          margin: const EdgeInsets.only(right: 72),
        ),
        itemBuilder: (_, i) {
          final chat   = _chats[i];
          final userId = chat['user_id'] as int;
          final name   = chat['name']    as String? ?? 'مستخدم';
          final unread = _unread[userId] ?? 0;
          final online = _presenceProvider.isOnline(userId);

          return ChatTile(
            name:        name,
            lastMessage: chat['content']   as String? ?? '',
            timestamp:   chat['timestamp'] as String? ?? '',
            unreadCount: unread,
            isOnline:    online,
            onTap: () => _openChat(userId, name),
          );
        },
      ),
    );
  }

  // ── شاشة فارغة ──
  Widget _buildEmpty(AppColorScheme c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: c.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 40, color: c.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد محادثات بعد',
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.text2, fontSize: 16, fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابحث عن شخص لبدء المحادثة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.text3, fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── skeleton loading — نفس .skel من صفحة الويب ──
  Widget _buildSkeleton(AppColorScheme c) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SkeletonTile(c: c),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  SKELETON TILE
// ═══════════════════════════════════════════════════
class _SkeletonTile extends StatefulWidget {
  final AppColorScheme c;
  const _SkeletonTile({required this.c});

  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = LinearGradient(
          begin: Alignment.centerRight,
          end:   Alignment.centerLeft,
          colors: [c.bg3, c.border, c.bg3],
          stops: [
            (_anim.value - 0.3).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.3).clamp(0.0, 1.0),
          ],
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              // avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: shimmer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: shimmer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11,
                      width: 140,
                      decoration: BoxDecoration(
                        gradient: shimmer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
//  SEARCH DELEGATE — نفس _UserSearchDelegate من صفحة الويب
// ═══════════════════════════════════════════════════
class _UserSearchDelegate extends SearchDelegate<ChatUser?> {
  final AppColorScheme   colors;
  final PresenceProvider presenceProvider;

  List<ChatUser> _results  = [];
  String         _lastQuery = '';

  _UserSearchDelegate({
    required this.colors,
    required this.presenceProvider,
  });

  @override
  String get searchFieldLabel => 'ابحث باسم أو ID...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final c = colors;
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(backgroundColor: c.bg2, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: c.text2),
        border: InputBorder.none,
      ),
      textTheme: TextTheme(
        titleLarge: GoogleFonts.ibmPlexSansArabic(
          color: c.text, fontSize: 16,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: Icon(Icons.clear, color: colors.text2),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: Icon(Icons.arrow_back, color: colors.text2),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearch(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Container(
        color: colors.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded, size: 56, color: colors.text3),
              const SizedBox(height: 12),
              Text(
                'ابحث باسم المستخدم أو رقم الـ ID',
                style: GoogleFonts.ibmPlexSansArabic(color: colors.text2),
              ),
            ],
          ),
        ),
      );
    }
    return _buildSearch(context);
  }

  Widget _buildSearch(BuildContext context) {
    final c = colors;
    return Container(
      color: c.bg,
      child: FutureBuilder<List<ChatUser>>(
        future: query != _lastQuery
            ? ApiService.searchUsers(query).then((r) {
                _lastQuery = query;
                _results   = r;
                return r;
              })
            : Future.value(_results),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text('خطأ: ${snap.error}',
                  style: GoogleFonts.ibmPlexSansArabic(color: c.red)),
            );
          }
          final users = snap.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 48, color: c.text3),
                  const SizedBox(height: 12),
                  Text('لا توجد نتائج',
                      style: GoogleFonts.ibmPlexSansArabic(color: c.text2)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u      = users[i];
              final online = presenceProvider.isOnline(u.id);
              return ListTile(
                tileColor: c.bg,
                leading: AvatarWidget(
                  name:     u.name,
                  size:     40,
                  isOnline: online,
                ),
                title: Text(
                  u.name,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w600, color: c.text,
                  ),
                ),
                subtitle: Text(
                  'ID: ${u.id}${online ? '  ●  متصل' : ''}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: online ? c.green : c.text2,
                  ),
                ),
                onTap: () => close(context, u),
              );
            },
          );
        },
      ),
    );
  }
}