import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:app/core/network/api_client.dart';
import 'package:app/features/dungeon_map/dungeon_map_screen.dart';

/// Cliente HTTP falso: responde `/api/dungeon/generate` com um mapa fixo de
/// 3x1 salas (ENTRANCE - EMPTY - EXIT, todas conectadas em linha), sem tocar
/// a rede de verdade.
class _FakeHttpClient extends http.BaseClient {
  static const _mapJson = {
    'seed': '7',
    'entranceRoomId': '0,0',
    'width': 3,
    'height': 1,
    'rooms': {
      '0,0': {
        'id': '0,0',
        'type': 'ENTRANCE',
        'x': 0,
        'y': 0,
        'connectedRoomIds': ['1,0'],
        'enemy': null,
        'items': [],
      },
      '1,0': {
        'id': '1,0',
        'type': 'EMPTY',
        'x': 1,
        'y': 0,
        'connectedRoomIds': ['0,0', '2,0'],
        'enemy': null,
        'items': [],
      },
      '2,0': {
        'id': '2,0',
        'type': 'EXIT',
        'x': 2,
        'y': 0,
        'connectedRoomIds': ['1,0'],
        'enemy': null,
        'items': [],
      },
    },
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = utf8.encode(jsonEncode(_mapJson));
    return http.StreamedResponse(Stream.value(body), 200);
  }
}

class _FailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('Conexão recusada');
  }
}

void main() {
  testWidgets('carrega o mapa e destaca a sala de entrada como atual', (tester) async {
    final apiClient = ApiClient(baseUrl: 'http://backend.test', client: _FakeHttpClient());

    await tester.pumpWidget(
      MaterialApp(home: DungeonMapScreen(apiClient: apiClient)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);
    expect(find.textContaining('Seed: 7'), findsOneWidget);
  });

  testWidgets('mover para uma sala conectada atualiza a sala atual', (tester) async {
    final apiClient = ApiClient(baseUrl: 'http://backend.test', client: _FakeHttpClient());

    await tester.pumpWidget(
      MaterialApp(home: DungeonMapScreen(apiClient: apiClient)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-1,0')));
    await tester.pump();

    final iconFinder = find.byIcon(Icons.person_pin_circle);
    expect(iconFinder, findsOneWidget);

    final iconCenter = tester.getCenter(iconFinder);
    final targetCenter = tester.getCenter(find.byKey(const ValueKey('room-1,0')));
    expect(iconCenter, targetCenter);
  });

  testWidgets('mover para uma sala não conectada mostra aviso e não move', (tester) async {
    final apiClient = ApiClient(baseUrl: 'http://backend.test', client: _FakeHttpClient());

    await tester.pumpWidget(
      MaterialApp(home: DungeonMapScreen(apiClient: apiClient)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-2,0')));
    await tester.pump();

    expect(find.text('Essa sala não está conectada à sala atual.'), findsOneWidget);

    final iconCenter = tester.getCenter(find.byIcon(Icons.person_pin_circle));
    final entranceCenter = tester.getCenter(find.byKey(const ValueKey('room-0,0')));
    expect(iconCenter, entranceCenter);
  });

  testWidgets('falha de rede mostra erro com opção de tentar novamente', (tester) async {
    final apiClient = ApiClient(baseUrl: 'http://backend.test', client: _FailingHttpClient());

    await tester.pumpWidget(
      MaterialApp(home: DungeonMapScreen(apiClient: apiClient)),
    );
    await tester.pump();

    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });
}
