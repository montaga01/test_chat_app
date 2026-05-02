import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/storage.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../widgets/chat_tile.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String _myName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _myName = await AppStorage.getUserName() ?? '';
    try {
      final chats = await ApiService.getChats();
      if (mounted) {
        setState(() { _chats = chats; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSearch() async {
    final user = await showSearch<ChatUser?>(
      context: context,
      delegate: _UserSearchDelegate(),
    );
    if (user != null && mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(otherUser: user)))
          .then((_) => _load());
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسجيل الخروج', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من تسجيل الخروج؟', style: GoogleFonts.tajawal()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.tajawal()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('خروج', style: GoogleFonts.tajawal(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AppStorage.clear();
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('الرفيق',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1a2340),
                )),
            Text('مرحباً، $_myName',
                style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1a56db)),
            onPressed: _openSearch,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a56db).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_outline,
                            size: 50, color: Color(0xFF1a56db)),
                      ),
                      const SizedBox(height: 16),
                      Text('لا توجد محادثات بعد',
                          style: GoogleFonts.tajawal(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          )),
                      const SizedBox(height: 8),
                      Text('ابحث عن مستخدم لبدء محادثة',
                          style: GoogleFonts.tajawal(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _chats.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: Color(0xFFe2e8f8)),
                    itemBuilder: (_, i) {
                      final chat = _chats[i];
                      return ChatTile(
                        name: chat['name'] ?? 'مستخدم',
                        lastMessage: chat['content'] ?? '',
                        timestamp: chat['timestamp'] ?? '',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              otherUser: ChatUser(
                                id: chat['user_id'],
                                name: chat['name'],
                                email: '',
                              ),
                            ),
                          ),
                        ).then((_) => _load()),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSearch,
        backgroundColor: const Color(0xFF1a56db),
        elevation: 6,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

// ========== Search Delegate ==========
class _UserSearchDelegate extends SearchDelegate<ChatUser?> {
  List<ChatUser> _results = [];
  String _lastQuery = '';

  @override
  String get searchFieldLabel => 'ابحث باسم أو ID...';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearch(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('ابحث باسم المستخدم أو رقم الـ ID',
                style: GoogleFonts.tajawal(color: Colors.grey)),
          ],
        ),
      );
    }
    return _buildSearch(context);
  }

  Widget _buildSearch(BuildContext context) {
    if (query.length < 1) {
      return Center(child: Text('اكتب حرفاً واحداً على الأقل', style: GoogleFonts.tajawal()));
    }

    return FutureBuilder<List<ChatUser>>(
      future: query != _lastQuery
          ? ApiService.searchUsers(query).then((r) { _lastQuery = query; _results = r; return r; })
          : Future.value(_results),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('خطأ: ${snap.error}', style: GoogleFonts.tajawal()));
        }
        final users = snap.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 50, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('لا توجد نتائج', style: GoogleFonts.tajawal(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF1a56db).withOpacity(0.15),
                child: Text(u.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF1a56db), fontWeight: FontWeight.bold)),
              ),
              title: Text(u.name,
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w500)),
              subtitle: Text('ID: ${u.id}  -  ${u.email}',
                  style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey)),
              onTap: () => close(context, u),
            );
          },
        );
      },
    );
  }
}
