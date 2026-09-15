import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/character.dart';
import 'package:app/core/models/enemy.dart';
import 'package:app/core/models/game_session.dart';
import 'package:app/core/models/move_response.dart';

const _attributesJson = {
  'strength': 5,
  'agility': 6,
  'vitality': 7,
  'speed': 8,
  'defense': 9,
  'intelligence': 10,
};

const _characterJson = {
  'id': 'char-1',
  'name': 'Aria',
  'mode': 'HARDCORE',
  'level': 2,
  'experience': 40,
  'attributes': _attributesJson,
  'effectiveAttributes': _attributesJson,
  'currentHealth': 30,
  'maxHealth': 45,
  'alive': true,
  'inventory': [],
  'equipped': {},
};

const _roomsJson = {
  '0,0': {
    'id': '0,0',
    'type': 'ENTRANCE',
    'x': 0,
    'y': 0,
    'connectedRoomIds': <String>[],
    'enemy': null,
    'items': [],
  },
};

void main() {
  group('Character.fromJson', () {
    test('lê vida, modo e demais campos novos', () {
      final character = Character.fromJson(_characterJson);

      expect(character.currentHealth, 30);
      expect(character.maxHealth, 45);
      expect(character.alive, true);
      expect(character.mode, GameMode.hardcore);
      expect(character.equipped, isEmpty);
    });
  });

  group('Enemy.fromJson', () {
    test('lê atributos e vida', () {
      final enemy = Enemy.fromJson({
        'id': 'enemy-1',
        'name': 'Goblin',
        'attributes': _attributesJson,
        'currentHealth': 12,
        'maxHealth': 20,
      });

      expect(enemy.name, 'Goblin');
      expect(enemy.currentHealth, 12);
      expect(enemy.maxHealth, 20);
      expect(enemy.attributes.intelligence, 10);
    });
  });

  group('GameSession.fromJson', () {
    test('lê sessão completa, incluindo salas visitadas como Set', () {
      final session = GameSession.fromJson({
        'id': 'session-1',
        'character': _characterJson,
        'dungeonMap': {
          'seed': '42',
          'entranceRoomId': '0,0',
          'width': 1,
          'height': 1,
          'rooms': _roomsJson,
        },
        'currentRoomId': '0,0',
        'visitedRoomIds': ['0,0', '0,0'],
        'depth': 3,
      });

      expect(session.id, 'session-1');
      expect(session.character.name, 'Aria');
      expect(session.currentRoomId, '0,0');
      expect(session.visitedRoomIds, {'0,0'});
      expect(session.depth, 3);
    });
  });

  group('MoveResponse.fromJson', () {
    test('combatEvents nulo quando não houve combate', () {
      final response = MoveResponse.fromJson({
        'session': {
          'id': 'session-1',
          'character': _characterJson,
          'dungeonMap': {
            'seed': '42',
            'entranceRoomId': '0,0',
            'width': 1,
            'height': 1,
            'rooms': _roomsJson,
          },
          'currentRoomId': '0,0',
          'visitedRoomIds': ['0,0'],
          'depth': 1,
        },
        'combatEvents': null,
      });

      expect(response.combatEvents, isNull);
    });

    test('combatEvents preenchido quando houve combate', () {
      final response = MoveResponse.fromJson({
        'session': {
          'id': 'session-1',
          'character': _characterJson,
          'dungeonMap': {
            'seed': '42',
            'entranceRoomId': '0,0',
            'width': 1,
            'height': 1,
            'rooms': _roomsJson,
          },
          'currentRoomId': '0,0',
          'visitedRoomIds': ['0,0'],
          'depth': 1,
        },
        'combatEvents': [
          {'type': 'ATTACK', 'actorId': 'char-1', 'targetId': 'enemy-1', 'amount': 5, 'timestamp': 1},
        ],
      });

      expect(response.combatEvents, hasLength(1));
      expect(response.combatEvents!.first.amount, 5);
    });
  });
}
