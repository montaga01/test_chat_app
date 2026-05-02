import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../providers/theme_provider.dart';
import '../providers/presence_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/message_bubble.dart';

// ── حالة الرسالة ──
enum _MsgStatus { sending, sent, failed }

class _LocalMessage {
  final Message    msg;
  _MsgStatus       status;
  _LocalMessage({required this.msg, this.status = _MsgStatus.sent});
}

class ChatScreen extends StatefulWidget {
  final ChatUser         otherUser;
  final ThemeProvider    themeProvider;
  final PresenceProvider presenceProvider;
  final WebSocketService wsService;
  final int              myId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.themeProvider,
    required this.presenceProvider,
    required this.wsService,
    required this.myId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<_LocalMessage> _messages = [];
  bool                _loading  = true;

  StreamSubscription? _msgSub;

  // typing debounce
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  // ✅ إصلاح: جمع كل كود _init في دالة واحدة متسلسلة بدون async gap
  Future<void> _init() async {
    try {
      final msgs = await ApiService.getMessages(widget.otherUser.id);
      if (!mounted) return;
      setState(() {
        _messages = msgs.map((m) => _LocalMessage(msg: m)).toList();
        _loading  = false;
      });
      _scrollToBottom(jump: true);
      // علّم المحادثة كمقروءة
      ApiService.markRead(widget.otherUser.id);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;

    // اطلب presence — نفس requestPresence() + fetchPresenceHTTP() من JS
    widget.presenceProvider.refreshUser(widget.otherUser.id);

    // استمع للرسائل الواردة
    _msgSub = widget.wsService.messages.listen(_onIncoming);
  }

  // ── رسالة واردة ──
  void _onIncoming(Message msg) {
    final peer = widget.otherUser.id;
    if (msg.senderId != peer && msg.receiverId != peer) return;
    if (!mounted) return;

    // تحديث presence المُرسل
    widget.presenceProvider.markOnlineFromMessage(
      msg.senderId,
      msg.timestamp.toUtc().toIso8601String(),
    );

    setState(() {
      _messages.add(_LocalMessage(msg: msg));
    });
    _scrollToBottom();

    // علّم المحادثة كمقروءة تلقائياً عند وصول رسالة والشاشة مفتوحة
    ApiService.markRead(widget.otherUser.id);
  }

  // ─────────────────────────────────────────────────
  //  SEND
  // ─────────────────────────────────────────────────
  void _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    _typingTimer?.cancel();

    // أضف الرسالة محلياً فوراً بحالة "جاري الإرسال"
    final tempMsg = Message(
      id:         -DateTime.now().millisecondsSinceEpoch,
      senderId:   widget.myId,
      receiverId: widget.otherUser.id,
      content:    text,
      timestamp:  DateTime.now(),
    );
    final local = _LocalMessage(msg: tempMsg, status: _MsgStatus.sending);
    setState(() => _messages.add(local));
    _scrollToBottom();

    // حاول الإرسال عبر WS
    if (widget.wsService.isConnected) {
      widget.wsService.sendMessage(
        receiverId: widget.otherUser.id,
        content:    text,
      );
      // نفترض النجاح — WS لا يرجع confirm موثوق
      setState(() => local.status = _MsgStatus.sent);
    } else {
      // HTTP fallback
      await _sendViaHttp(local, text);
    }
  }

  Future<void> _sendViaHttp(_LocalMessage local, String text) async {
    try {
      await ApiService.sendMessage(
        receiverId: widget.otherUser.id,
        content:    text,
      );
      if (mounted) setState(() => local.status = _MsgStatus.sent);
    } catch (_) {
      if (mounted) setState(() => local.status = _MsgStatus.failed);
    }
  }

  // ── إعادة إرسال رسالة فاشلة ──
  void _retry(_LocalMessage local) async {
    setState(() => local.status = _MsgStatus.sending);

    if (widget.wsService.isConnected) {
      widget.wsService.sendMessage(
        receiverId: widget.otherUser.id,
        content:    local.msg.content,
      );
      setState(() => local.status = _MsgStatus.sent);
    } else {
      await _sendViaHttp(local, local.msg.content);
    }
  }

  // ── typing indicator ──
  void _onTextChanged(String _) {
    widget.wsService.sendTyping(receiverId: widget.otherUser.id);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {});
  }

  // ── scroll ──
  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (jump) {
        _scrollCtrl.jumpTo(max);
      } else {
        _scrollCtrl.animateTo(
          max,
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  // ── lifecycle ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.presenceProvider.refreshUser(widget.otherUser.id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgSub?.cancel();
    _typingTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ListenableBuilder(
      listenable: widget.presenceProvider,
      builder: (context, _) {
        final isOnline = widget.presenceProvider.isOnline(widget.otherUser.id);
        final isTyping = widget.presenceProvider.isTyping(widget.otherUser.id);
        final statusText = isTyping
            ? null
            : widget.presenceProvider.lastSeenText(widget.otherUser.id);

        return Scaffold(
          backgroundColor: c.bg,
          appBar: _buildAppBar(c, isOnline, isTyping, statusText),
          body: Column(
            children: [
              Expanded(child: _buildMessageList(c)),
              TypingIndicatorAnimated(
                isVisible: isTyping,
                userName:  widget.otherUser.name,
              ),
              _buildInputArea(c),
            ],
          ),
        );
      },
    );
  }

  // ── AppBar ──
  PreferredSizeWidget _buildAppBar(
    AppColorScheme c,
    bool isOnline,
    bool isTyping,
    String? statusText,
  ) {
    return AppBar(
      backgroundColor: c.bg2,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.text2),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // avatar مع online dot
          AvatarWidget(
            name:     widget.otherUser.name,
            size:     36,
            isOnline: isOnline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ إصلاح: حذف النص المكرر — كان الاسم يظهر مرتين
                Text(
                  widget.otherUser.name,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w700,
                    fontSize:   16,
                    color:      c.text,
                  ),
                ),
                // السطر الثاني: "يكتب..." أو "آخر ظهور"
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isTyping ? 'يكتب...' : (statusText ?? 'آخر ظهور مؤخراً'),
                    key: ValueKey(isTyping),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: isTyping ? c.accent : (isOnline ? c.green : c.text2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: c.border, height: 1),
      ),
      actions: [
        // زر تبديل الثيم
        GestureDetector(
          onTap: () => widget.themeProvider.toggle(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: c.bg3,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              widget.themeProvider.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 17, color: c.text2,
            ),
          ),
        ),
      ],
    );
  }

  // ── قائمة الرسائل ──
  Widget _buildMessageList(AppColorScheme c) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'ابدأ المحادثة! 👋',
          style: GoogleFonts.ibmPlexSansArabic(color: c.text3, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller:  _scrollCtrl,
      padding:     const EdgeInsets.symmetric(vertical: 12),
      itemCount:   _messages.length,
      itemBuilder: (_, i) {
        final local  = _messages[i];
        final isMe   = local.msg.senderId == widget.myId;

        // date divider — نفس date-div من صفحة الويب
        final showDate = i == 0 ||
            !_sameDay(_messages[i - 1].msg.timestamp, local.msg.timestamp);

        return Column(
          children: [
            if (showDate) _buildDateDivider(local.msg.timestamp, c),
            _buildBubble(local, isMe, c),
          ],
        );
      },
    );
  }

  // ── date divider ──
  Widget _buildDateDivider(DateTime ts, AppColorScheme c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: c.border)),
          Container(
            margin:  const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: AppDecorations.dateDivider(c),
            child: Text(
              _dayLabel(ts),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11, color: c.text2,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: c.border)),
        ],
      ),
    );
  }

  // ── فقاعة الرسالة ──
  Widget _buildBubble(_LocalMessage local, bool isMe, AppColorScheme c) {
    final i            = _messages.indexOf(local);
    final prevSameUser = i > 0 && _messages[i-1].msg.senderId == local.msg.senderId;
    final nextSameUser = i < _messages.length - 1 && _messages[i+1].msg.senderId == local.msg.senderId;

    return AnimatedOpacity(
      opacity:  local.status == _MsgStatus.sending ? 0.65 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: MessageBubble(
        message:        local.msg,
        isMe:           isMe,
        isFirstInGroup: !prevSameUser,
        isLastInGroup:  !nextSameUser,
        isPending:      local.status == _MsgStatus.sending,
        hasFailed:      local.status == _MsgStatus.failed,
        onRetry:        local.status == _MsgStatus.failed ? () => _retry(local) : null,
      ),
    );
  }

  // ── منطقة الإدخال ──
  Widget _buildInputArea(AppColorScheme c) {
    return Container(
      color: c.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SafeArea(
        child: Row(
          children: [
            // حقل الكتابة
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color:  c.bg3,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller:      _msgCtrl,
                  maxLines:        null,
                  textInputAction: TextInputAction.send,
                  textAlign:       TextAlign.right,
                  style:           TextStyle(color: c.text, fontSize: 14),
                  onChanged:       _onTextChanged,
                  onSubmitted:     (_) => _send(),
                  decoration: InputDecoration(
                    hintText:  'اكتب رسالتك...',
                    hintStyle: TextStyle(color: c.text3, fontSize: 14),
                    border:    InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // زر الإرسال
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: AppDecorations.sendButton(c),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────
  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  String _dayLabel(DateTime ts) {
    final local = ts.toLocal();
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(local.year, local.month, local.day);
    final diff  = today.difference(day).inDays;

    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff < 7) {
      const weekdays = [
        '', 'الاثنين', 'الثلاثاء', 'الأربعاء',
        'الخميس', 'الجمعة', 'السبت', 'الأحد',
      ];
      return weekdays[local.weekday];
    }
    return '${local.day}/${local.month}/${local.year}';
  }
}