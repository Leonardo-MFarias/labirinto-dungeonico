import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/game/game_controller.dart';
import 'package:app/core/models/attributes.dart';
import 'package:app/core/models/character.dart';
import 'package:app/core/models/combat_event.dart';
import 'package:app/core/models/dungeon_map.dart';
import 'package:app/core/models/enemy.dart';
import 'package:app/core/models/game_session.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/features/combat/combat_screen.dart';

const _attributes = Attributes(strength: 5, agility: 5, vitality: 5, speed: 5, defense: 5, intelligence: 5);

Character _character({int currentHealth = 45}) => Character(
      id: 'char-1',
      name: 'Aria',
      level: 1,
      experience: 0,
      unspentAttributePoints: 0,
      attributes: _attributes,
      effectiveAttributes: _attributes,
      inventory: const [],
      equipped: const {},
      mode: GameMode.normal,
      currentHealth: currentHealth,
      maxHealth: 45,
      alive: currentHealth > 0,
    );

GameSession _session(Character character) => GameSession(
      id: 'session-1',
      character: character,
      dungeonMap: const DungeonMap(seed: '1', width: 1, height: 1, rooms: {}, entranceRoomId: '0,0'),
      currentRoomId: '0,0',
      visitedRoomIds: const {'0,0'},
      depth: 1,
    );

const _enemy = Enemy(id: 'enemy-1', name: 'Goblin', attributes: _attributes, currentHealth: 20, maxHealth: 20);

GameController _controller() => GameController(ApiClient(baseUrl: 'http://backend.test'));

void main() {
  testWidgets('sem combate ainda mostra estado vazio', (tester) async {
    final controller = _controller()..session = _session(_character());

    await tester.pumpWidget(MaterialApp(home: CombatScreen(controller: controller)));
    await tester.pump();

    expect(find.textContaining('Nenhum combate ainda'), findsOneWidget);
  });

  testWidgets('revela os eventos aos poucos e mostra vitória no final', (tester) async {
    final controller = _controller()
      ..session = _session(_character())
      ..lastEnemy = _enemy
      ..lastCombatEvents = const [
        CombatEvent(type: CombatEventType.attack, actorId: 'char-1', targetId: 'enemy-1', amount: 5, timestamp: 1),
        CombatEvent(type: CombatEventType.death, actorId: 'char-1', targetId: 'enemy-1', amount: 0, timestamp: 2),
        CombatEvent(type: CombatEventType.combatEnd, actorId: 'char-1', targetId: 'enemy-1', amount: 0, timestamp: 3),
      ];

    await tester.pumpWidget(MaterialApp(home: CombatScreen(controller: controller)));
    await tester.pump();

    // Logo após montar, nenhum evento foi revelado ainda (o primeiro só
    // aparece depois do primeiro delay).
    expect(find.textContaining('acertou'), findsNothing);

    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('acertou'), findsOneWidget);
    expect(find.text('Vitória!'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Continuar'), findsOneWidget);
  });

  testWidgets('botão Pular revela tudo na hora', (tester) async {
    final controller = _controller()
      ..session = _session(_character())
      ..lastEnemy = _enemy
      ..lastCombatEvents = const [
        CombatEvent(type: CombatEventType.attack, actorId: 'char-1', targetId: 'enemy-1', amount: 5, timestamp: 1),
        CombatEvent(type: CombatEventType.death, actorId: 'char-1', targetId: 'enemy-1', amount: 0, timestamp: 2),
        CombatEvent(type: CombatEventType.combatEnd, actorId: 'char-1', targetId: 'enemy-1', amount: 0, timestamp: 3),
      ];

    await tester.pumpWidget(MaterialApp(home: CombatScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Pular'));
    await tester.pump();

    expect(find.text('Vitória!'), findsOneWidget);
  });

  testWidgets('botão Continuar chama onFinished quando fornecido', (tester) async {
    var finished = false;
    final controller = _controller()
      ..session = _session(_character())
      ..lastEnemy = _enemy
      ..lastCombatEvents = const [
        CombatEvent(type: CombatEventType.attack, actorId: 'char-1', targetId: 'enemy-1', amount: 5, timestamp: 1),
        CombatEvent(type: CombatEventType.death, actorId: 'char-1', targetId: 'enemy-1', amount: 0, timestamp: 2),
        CombatEvent(type: CombatEventType.combatEnd, actorId: 'char-1', targetId: 'enemy-1', amount: 0, timestamp: 3),
      ];

    await tester.pumpWidget(
      MaterialApp(home: CombatScreen(controller: controller, onFinished: () => finished = true)),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Pular'));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
    await tester.pump();

    expect(finished, isTrue);
  });
}
