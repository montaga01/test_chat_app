import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';
import '../models/message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Message> _messageController = StreamController.broadcast();

  Stream<Message> get messages => _messageController.stream;

  void connect(String token) {
    final uri = Uri.parse('${AppConstants.wsUrl}/$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data);
        if (json['status'] == 'sent') return;
        if (json['error'] != null) return;
        _messageController.add(Message.fromJson(json));
      },
      onError: (e) => print('WebSocket error: $e'),
      onDone: () => print('WebSocket closed'),
    );
  }

  void sendMessage({required int receiverId, required String content}) {
    _channel?.sink.add(jsonEncode({
      'receiver_id': receiverId,
      'content': content,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
