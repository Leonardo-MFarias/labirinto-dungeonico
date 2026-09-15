import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:app/core/game/game_controller.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/main.dart';

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = {
      'id': 'session-1',
      'character': {
        'id': 'char-1',
        'name': 'Aria',
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
      },
      'dungeonMap': {
        'seed': '1',
        'entranceRoomId': '0,0',
        'width': 1,
        'height': 1,
        'rooms': {
          '0,0': {
            'id': '0,0',
            'type': 'ENTRANCE',
            'x': 0,
            'y': 0,
            'connectedRoomIds': <String>[],
            'enemy': null,
            'items': [],
          },
        },
      },
      'currentRoomId': '0,0',
      'visitedRoomIds': ['0,0'],
      'depth': 1,
    };
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 201);
  }
}

void main() {
  testWidgets('criar sessão pelo diálogo navega para o Mapa', (tester) async {
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test', client: _FakeHttpClient()));

    await tester.pumpWidget(MaterialApp(home: HomeScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.text('Mapa'));
    await tester.pump();

    expect(find.text('Nova run'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Aria');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mapa da Masmorra'), findsOneWidget);
  });

  testWidgets('navegar entre abas do shell sem voltar à Home (RF-57)', (tester) async {
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test', client: _FakeHttpClient()));

    await tester.pumpWidget(MaterialApp(home: HomeScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.text('Mapa'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Aria');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(find.text('Mapa da Masmorra'), findsOneWidget);

    // Usa o NavigationBar do shell, não o botão da Home por baixo (a rota da
    // Home continua montada, então 'Personagem'/'Mapa' podem existir em
    // ambas — o descendant restringe a busca à barra de navegação).
    final navBar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: navBar, matching: find.text('Personagem')));
    await tester.pumpAndSettle();

    expect(find.text('Aria'), findsOneWidget);

    await tester.tap(find.descendant(of: navBar, matching: find.text('Mapa')));
    await tester.pumpAndSettle();

    expect(find.text('Mapa da Masmorra'), findsOneWidget);
  });
}
