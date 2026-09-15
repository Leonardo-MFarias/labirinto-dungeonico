import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:app/core/game/game_controller.dart';
import 'package:app/core/models/attributes.dart';
import 'package:app/core/models/character.dart';
import 'package:app/core/models/dungeon_map.dart';
import 'package:app/core/models/game_session.dart';
import 'package:app/core/models/item.dart';
import 'package:app/core/models/rarity.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/features/character/character_screen.dart';

const _attributes = Attributes(strength: 7, agility: 8, vitality: 9, speed: 10, defense: 11, intelligence: 12);
const _effectiveAttributes = Attributes(strength: 7, agility: 8, vitality: 9, speed: 10, defense: 15, intelligence: 12);

const _sword = Item(id: 'item-1', baseType: 'espada', itemLevel: 2, rarity: Rarity.incomum, prefixes: [], baseStats: {});

GameSession _session({
  List<Item> inventory = const [],
  Map<String, Item> equipped = const {},
  Attributes? effectiveAttributes,
}) =>
    GameSession(
      id: 'session-1',
      character: Character(
        id: 'char-1',
        name: 'Aria',
        level: 3,
        experience: 120,
        attributes: _attributes,
        effectiveAttributes: effectiveAttributes ?? _attributes,
        inventory: inventory,
        equipped: equipped,
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

Map<String, dynamic> _sessionJson({required Map<String, dynamic> equipped, required List<dynamic> inventory}) => {
      'id': 'session-1',
      'character': {
        'id': 'char-1',
        'name': 'Aria',
        'mode': 'HARDCORE',
        'level': 3,
        'experience': 120,
        'attributes': {'strength': 7, 'agility': 8, 'vitality': 9, 'speed': 10, 'defense': 11, 'intelligence': 12},
        'effectiveAttributes': {
          'strength': 7,
          'agility': 8,
          'vitality': 9,
          'speed': 10,
          'defense': 11,
          'intelligence': 12,
        },
        'currentHealth': 30,
        'maxHealth': 60,
        'alive': true,
        'inventory': inventory,
        'equipped': equipped,
      },
      'dungeonMap': {'seed': '1', 'entranceRoomId': '0,0', 'width': 1, 'height': 1, 'rooms': <String, dynamic>{}},
      'currentRoomId': '0,0',
      'visitedRoomIds': ['0,0'],
      'depth': 1,
    };

const _swordJson = {
  'id': 'item-1',
  'baseType': 'espada',
  'itemLevel': 2,
  'rarity': 'INCOMUM',
  'prefixes': [],
  'baseStats': {},
};

/// Cliente HTTP falso: responde `/equip`/`/unequip` registrando o corpo da
/// requisição, para os testes verificarem qual chamada a tela disparou sem
/// depender de simular o gesto de arraste até o fim.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({this.onEquip, this.onUnequip});

  final void Function(Map<String, dynamic> body)? onEquip;
  final void Function(Map<String, dynamic> body)? onUnequip;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;

    if (path.endsWith('/equip')) {
      onEquip?.call(body);
      return _respond(_sessionJson(
        equipped: {body['slot'] as String: _swordJson},
        inventory: const [],
      ));
    }
    if (path.endsWith('/unequip')) {
      onUnequip?.call(body);
      return _respond(_sessionJson(equipped: const {}, inventory: [_swordJson]));
    }
    throw UnimplementedError('Caminho não tratado no fake: $path');
  }

  http.StreamedResponse _respond(Map<String, dynamic> body) =>
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200);
}

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

  testWidgets('mostra os oito slots e o item equipado em um deles', (tester) async {
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test'))
      ..session = _session(equipped: const {'HAND_LEFT': _sword});

    await tester.pumpWidget(MaterialApp(home: CharacterScreen(controller: controller)));
    await tester.pump();

    expect(find.text('Mão esquerda'), findsOneWidget);
    expect(find.text('Acessório 1'), findsOneWidget);
    expect(find.text('Espada'), findsOneWidget);
  });

  testWidgets('atributo efetivo diferente do base mostra anotação', (tester) async {
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test'))
      ..session = _session(effectiveAttributes: _effectiveAttributes);

    await tester.pumpWidget(MaterialApp(home: CharacterScreen(controller: controller)));
    await tester.pump();

    expect(find.textContaining('15 (base 11)'), findsOneWidget);
  });

  testWidgets('arrastar item compatível até o slot dispara equip', (tester) async {
    Map<String, dynamic>? calledWith;
    final client = _FakeHttpClient(onEquip: (body) => calledWith = body);
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test', client: client))
      ..session = _session(inventory: const [_sword]);

    await tester.pumpWidget(MaterialApp(home: CharacterScreen(controller: controller)));
    await tester.pump();

    final itemFinder = find.text('Espada');
    final slotFinder = find.byKey(const ValueKey('slot-HAND_LEFT'));
    // A seção de inventário fica abaixo da dobra no viewport de teste — rola a ListView até
    // o item aparecer antes de calcular as coordenadas do arraste.
    await tester.dragUntilVisible(itemFinder, find.byType(ListView), const Offset(0, -100));
    await tester.drag(itemFinder, tester.getCenter(slotFinder) - tester.getCenter(itemFinder));
    await tester.pumpAndSettle();

    expect(calledWith, isNotNull);
    expect(calledWith!['itemId'], 'item-1');
    expect(calledWith!['slot'], 'HAND_LEFT');
  });

  testWidgets('tocar item equipado dispara unequip', (tester) async {
    Map<String, dynamic>? calledWith;
    final client = _FakeHttpClient(onUnequip: (body) => calledWith = body);
    final controller = GameController(ApiClient(baseUrl: 'http://backend.test', client: client))
      ..session = _session(equipped: const {'HAND_LEFT': _sword});

    await tester.pumpWidget(MaterialApp(home: CharacterScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.text('Espada'));
    await tester.pump();

    expect(calledWith, isNotNull);
    expect(calledWith!['slot'], 'HAND_LEFT');
  });
}
