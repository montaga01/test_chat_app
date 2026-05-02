class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: j['id'] ?? 0,
    senderId: j['sender_id'],
    receiverId: j['receiver_id'],
    content: j['content'],
    timestamp: _parseTs(j['timestamp']),
  );
  // وأضف دالة static في نفس الكلاس:
  static DateTime _parseTs(dynamic val) {
    if (val == null) return DateTime.now();
    final s = val.toString();
    if (s.isEmpty) return DateTime.now();
    final normalized = (s.contains('Z') || s.contains('+')) ? s : '${s}Z';
    return DateTime.tryParse(normalized)?.toLocal() ?? DateTime.now();
  }
}
