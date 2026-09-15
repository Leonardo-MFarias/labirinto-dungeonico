import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/game/game_controller.dart';
import 'package:app/core/models/attributes.dart';
import 'package:app/core/models/character.dart';
import 'package:app/core/models/dungeon_map.dart';
import 'package:app/core/models/game_session.dart';
import 'package:app/core/models/room.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/features/shell/game_shell.dart';

const _attributes = Attributes(strength: 5, agility: 5, vitality: 5, speed: 5, defense: 5, intelligence: 5);

// IndexedStack constrói as quatro telas de uma vez (não só a aba ativa), então o mapa de
// salas precisa ser real — DungeonMapScreen/InventoryScreen buscam `rooms[currentRoomId]!`.
const _entranceRoom = Room(id: '0,0', type: RoomType.entrance, x: 0, y: 0, items: [], connectedRoomIds: [], enemy: null);

GameSession _session() => GameSession(
      id: 'session-1',
      character: const Character(
        id: 'char-1',
        name: 'Aria',
        level: 1,
        experience: 0,
        unspentAttributePoints: 0,
        attributes: _attributes,
        effectiveAttributes: _attributes,
        inventory: [],
        equipped: {},
        mode: GameMode.normal,
        currentHealth: 45,
        maxHealth: 45,
        alive: true,
      ),
      dungeonMap: const DungeonMap(seed: '1', width: 1, height: 1, rooms: {'0,0': _entranceRoom}, entranceRoomId: '0,0'),
      currentRoomId: '0,0',
      visitedRoomIds: const {'0,0'},
      depth: 1,
    );

GameController _controller() => GameController(ApiClient(baseUrl: 'http://backend.test'))..session = _session();

void main() {
  testWidgets('mostra as quatro abas e começa na aba pedida', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GameShell(controller: _controller(), initialIndex: 2)));
    await tester.pump();

    final navBar = find.byType(NavigationBar);
    expect(find.descendant(of: navBar, matching: find.text('Mapa')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Combate')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Inventário')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Personagem')), findsOneWidget);
    expect(find.text('Inventário vazio.'), findsOneWidget);
  });

  testWidgets('tocar num destino troca de aba sem sair do shell', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GameShell(controller: _controller())));
    await tester.pump();

    expect(find.text('Mapa da Masmorra'), findsOneWidget);

    final navBar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: navBar, matching: find.text('Personagem')));
    await tester.pump();

    expect(find.text('Aria'), findsOneWidget);

    await tester.tap(find.descendant(of: navBar, matching: find.text('Mapa')));
    await tester.pump();

    expect(find.text('Mapa da Masmorra'), findsOneWidget);
  });
}
