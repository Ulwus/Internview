import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'signaling_message.dart';

class SignalingClient {
  SignalingClient._(this._channel, this._controller);

  final WebSocketChannel _channel;
  final StreamController<SignalingMessage> _controller;

  Stream<SignalingMessage> get messages => _controller.stream;

  static Future<SignalingClient> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    final controller = StreamController<SignalingMessage>.broadcast();
    channel.stream.listen(
      (raw) {
        try {
          final map = jsonDecode(raw as String) as Map<String, dynamic>;
          controller.add(SignalingMessage.fromJson(map));
        } catch (_) {
          controller.add(ErrorMessage(code: 'PARSE', message: 'Geçersiz WS mesajı'));
        }
      },
      onError: (e) => controller.add(ErrorMessage(code: 'WS', message: '$e')),
      onDone: () => controller.close(),
    );
    return SignalingClient._(channel, controller);
  }

  void sendJson(Map<String, dynamic> json) {
    _channel.sink.add(jsonEncode(json));
  }

  Future<void> dispose() async {
    await _channel.sink.close();
    await _controller.close();
  }
}
