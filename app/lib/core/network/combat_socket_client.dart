import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/combat_event.dart';

class CombatSocketClient {
  CombatSocketClient(String wsUrl)
      : _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  final WebSocketChannel _channel;

  Stream<CombatEvent> get events => _channel.stream.map(
        (raw) => CombatEvent.fromJson(
          jsonDecode(raw as String) as Map<String, dynamic>,
        ),
      );

  void dispose() {
    _channel.sink.close();
  }
}
