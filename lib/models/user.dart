class ChatUser {
  final int id;
  final String name;
  final String email;

  ChatUser({required this.id, required this.name, required this.email});

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
    id: j['id'],
    name: j['name'],
    email: j['email'] ?? '',
  );
}
