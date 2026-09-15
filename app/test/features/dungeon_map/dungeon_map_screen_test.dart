import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:app/core/game/game_controller.dart';
import 'package:app/core/models/character.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/features/dungeon_map/dungeon_map_screen.dart';

const _character = {
  'id': 'char-1',
  'name': 'Testador',
  'mode': 'NORMAL',
  'level': 1,
  'experience': 0,
  'attributes': {'strength': 5, 'agility': 5, 'vitality': 5, 'speed': 5, 'defense': 5, 'intelligence': 5},
  'effectiveAttributes': {'strength': 5, 'agility': 5, 'vitality': 5, 'speed': 5, 'defense': 5, 'intelligence': 5},
  'currentHealth': 45,
  'maxHealth': 45,
  'alive': true,
  'inventory': [],
  'equipped': {},
};

const _rooms = {
  '0,0': {
    'id': '0,0',
    'type': 'ENTRANCE',
    'x': 0,
    'y': 0,
    'connectedRoomIds': ['1,0', '0,1'],
    'enemy': null,
    'items': [],
  },
  '1,0': {
    'id': '1,0',
    'type': 'EMPTY',
    'x': 1,
    'y': 0,
    'connectedRoomIds': ['0,0'],
    'enemy': null,
    'items': [],
  },
  '0,1': {
    'id': '0,1',
    'type': 'ENEMY',
    'x': 0,
    'y': 1,
    'connectedRoomIds': ['0,0'],
    'enemy': {
      'id': 'enemy-1',
      'name': 'Goblin',
      'attributes': {'strength': 5, 'agility': 5, 'vitality': 5, 'speed': 5, 'defense': 5, 'intelligence': 5},
      'currentHealth': 20,
      'maxHealth': 20,
    },
    'items': [],
  },
  '1,1': {
    'id': '1,1',
    'type': 'WALL',
    'x': 1,
    'y': 1,
    'connectedRoomIds': [],
    'enemy': null,
    'items': [],
  },
};

Map<String, dynamic> _sessionJson({required String currentRoomId, required List<String> visited}) => {
      'id': 'session-1',
      'character': _character,
      'dungeonMap': {
        'seed': '1',
        'entranceRoomId': '0,0',
        'width': 2,
        'height': 2,
        'rooms': _rooms,
      },
      'currentRoomId': currentRoomId,
      'visitedRoomIds': visited,
      'depth': 1,
    };

/// Cliente HTTP falso: cria a sessão inicial e responde `move` de forma
/// determinística por sala de destino, sem depender do backend real.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({this.failMove = false});

  final bool failMove;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (path == '/api/session') {
      return _respond(_sessionJson(currentRoomId: '0,0', visited: ['0,0']), 201);
    }

    if (path.endsWith('/move')) {
      if (failMove) {
        throw Exception('Falha de rede simulada');
      }
      final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      final roomId = body['roomId'] as String;
      if (roomId == '1,0') {
        return _respond({
          'session': _sessionJson(currentRoomId: '1,0', visited: ['0,0', '1,0']),
          'combatEvents': null,
        }, 200);
      }
      if (roomId == '0,1') {
        return _respond({
          'session': _sessionJson(currentRoomId: '0,1', visited: ['0,0', '0,1']),
          'combatEvents': [
            {'type': 'ATTACK', 'actorId': 'char-1', 'targetId': 'enemy-1', 'amount': 5, 'timestamp': 1},
            {'type': 'DEATH', 'actorId': 'char-1', 'targetId': 'enemy-1', 'amount': 0, 'timestamp': 2},
            {'type': 'COMBAT_END', 'actorId': 'char-1', 'targetId': 'enemy-1', 'amount': 0, 'timestamp': 3},
          ],
        }, 200);
      }
      return _respond({'error': 'Sala não conectada'}, 400);
    }

    throw UnimplementedError('Caminho não tratado no fake: $path');
  }

  http.StreamedResponse _respond(Map<String, dynamic> body, int status) {
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status);
  }
}

Future<GameController> _controllerWithSession({bool failMove = false}) async {
  final apiClient = ApiClient(baseUrl: 'http://backend.test', client: _FakeHttpClient(failMove: failMove));
  final controller = GameController(apiClient);
  await controller.createSession(name: 'Testador', mode: GameMode.normal);
  return controller;
}

void main() {
  testWidgets('carrega a sessão e destaca a sala atual', (tester) async {
    final controller = await _controllerWithSession();

    await tester.pumpWidget(MaterialApp(home: DungeonMapScreen(controller: controller)));
    await tester.pump();

    expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);
    expect(find.textContaining('Profundidade 1'), findsOneWidget);
  });

  testWidgets('mover para sala conectada sem inimigo atualiza a posição', (tester) async {
    final controller = await _controllerWithSession();

    await tester.pumpWidget(MaterialApp(home: DungeonMapScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-1,0')));
    await tester.pump();
    await tester.pump();

    expect(controller.session!.currentRoomId, '1,0');
    expect(find.text('Mapa da Masmorra'), findsOneWidget);
  });

  testWidgets('mover para sala com inimigo dispara onCombatTriggered', (tester) async {
    final controller = await _controllerWithSession();
    var combatTriggered = false;

    await tester.pumpWidget(MaterialApp(
      home: DungeonMapScreen(controller: controller, onCombatTriggered: () => combatTriggered = true),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-0,1')));
    await tester.pump();
    await tester.pump();

    expect(combatTriggered, isTrue);
    expect(controller.lastCombatEvents, isNotNull);
  });

  testWidgets('mover para sala com inimigo sem callback não navega nem lança erro', (tester) async {
    final controller = await _controllerWithSession();

    await tester.pumpWidget(MaterialApp(home: DungeonMapScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-0,1')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mapa da Masmorra'), findsOneWidget);
    expect(controller.lastCombatEvents, isNotNull);
  });

  testWidgets('falha de rede ao mover mostra aviso', (tester) async {
    final controller = await _controllerWithSession(failMove: true);

    await tester.pumpWidget(MaterialApp(home: DungeonMapScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-1,0')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
