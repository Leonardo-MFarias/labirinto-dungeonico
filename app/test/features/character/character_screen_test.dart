import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/game/game_controller.dart';
import 'package:app/core/models/attributes.dart';
import 'package:app/core/models/character.dart';
import 'package:app/core/models/dungeon_map.dart';
import 'package:app/core/models/game_session.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/features/character/character_screen.dart';

const _attributes = Attributes(strength: 7, agility: 8, vitality: 9, speed: 10, defense: 11, intelligence: 12);

GameSession _session() => GameSession(
      id: 'session-1',
      character: const Character(
        id: 'char-1',
        name: 'Aria',
        level: 3,
        experience: 120,
        attributes: _attributes,
        inventory: [],
        equipped: {},
        mode: GameMode.hardcore,
        currentHealth: 30,
        maxHealth: 60,
        alive: true,
      ),
      dungeonMap: const DungeonMap(seed: '1', width: 1, height: 1, rooms: {}, entranceRoomId: '0,0'),
      currentRoomId: '0,0',
      visitedRoomIds: const {'0,0'},
      depth: 1,
    );

void main() {
  testWidgets('mostra nome, modo, nível, XP, vida e atributos', (tester) async {
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test'))..session = _session();

    await tester.pumpWidget(MaterialApp(home: CharacterScreen(controller: controller)));
    await tester.pump();

    expect(find.text('Aria'), findsOneWidget);
    expect(find.text('Hardcore'), findsOneWidget);
    expect(find.textContaining('Nível 3'), findsOneWidget);
    expect(find.textContaining('120 XP'), findsOneWidget);
    expect(find.textContaining('30/60'), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // intelligence
  });

  testWidgets('sem sessão mostra mensagem', (tester) async {
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test'));

    await tester.pumpWidget(MaterialApp(home: CharacterScreen(controller: controller)));
    await tester.pump();

    expect(find.text('Nenhuma sessão ativa.'), findsOneWidget);
  });
}
