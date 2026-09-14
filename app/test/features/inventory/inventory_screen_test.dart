import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/game/game_controller.dart';
import 'package:app/core/models/attributes.dart';
import 'package:app/core/models/character.dart';
import 'package:app/core/models/dungeon_map.dart';
import 'package:app/core/models/game_session.dart';
import 'package:app/core/models/item.dart';
import 'package:app/core/models/rarity.dart';
import 'package:app/core/models/room.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/features/inventory/inventory_screen.dart';

const _attributes = Attributes(strength: 5, agility: 5, vitality: 5, speed: 5, defense: 5, intelligence: 5);

const _sword = Item(
  id: 'item-1',
  baseType: 'espada',
  itemLevel: 2,
  rarity: Rarity.incomum,
  prefixes: [],
  baseStats: {},
);

Character _character({List<Item> inventory = const []}) => Character(
      id: 'char-1',
      name: 'Aria',
      level: 1,
      experience: 0,
      attributes: _attributes,
      inventory: inventory,
      equipped: const {},
      mode: GameMode.normal,
      currentHealth: 45,
      maxHealth: 45,
      alive: true,
    );

GameSession _sessionWithLootHere({required List<Item> roomItems, required List<Item> inventory}) {
  const roomId = '0,0';
  return GameSession(
    id: 'session-1',
    character: _character(inventory: inventory),
    dungeonMap: DungeonMap(
      seed: '1',
      width: 1,
      height: 1,
      entranceRoomId: roomId,
      rooms: {
        roomId: Room(
          id: roomId,
          type: RoomType.loot,
          x: 0,
          y: 0,
          items: roomItems,
          connectedRoomIds: const [],
          enemy: null,
        ),
      },
    ),
    currentRoomId: roomId,
    visitedRoomIds: const {roomId},
    depth: 1,
  );
}

GameController _controller() => GameController(ApiClient(baseUrl: 'http://backend.test'));

void main() {
  testWidgets('inventário vazio mostra mensagem', (tester) async {
    final controller = _controller()..session = _sessionWithLootHere(roomItems: const [], inventory: const []);

    await tester.pumpWidget(MaterialApp(home: InventoryScreen(controller: controller)));
    await tester.pump();

    expect(find.text('Inventário vazio.'), findsOneWidget);
  });

  testWidgets('lista itens do inventário com raridade', (tester) async {
    final controller = _controller()
      ..session = _sessionWithLootHere(roomItems: const [], inventory: const [_sword]);

    await tester.pumpWidget(MaterialApp(home: InventoryScreen(controller: controller)));
    await tester.pump();

    expect(find.text('Espada'), findsOneWidget);
    expect(find.textContaining('Incomum'), findsOneWidget);
  });

  testWidgets('botão de coletar aparece quando a sala tem itens', (tester) async {
    final controller = _controller()
      ..session = _sessionWithLootHere(roomItems: const [_sword], inventory: const []);

    await tester.pumpWidget(MaterialApp(home: InventoryScreen(controller: controller)));
    await tester.pump();

    expect(find.textContaining('Coletar 1 item'), findsOneWidget);
  });
}
