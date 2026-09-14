import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/attributes.dart';
import 'package:app/core/models/combat_event.dart';
import 'package:app/core/models/item.dart';
import 'package:app/core/models/rarity.dart';

void main() {
  group('Attributes.fromJson (PEND-02)', () {
    test('lê os seis atributos, incluindo defense e intelligence', () {
      final attributes = Attributes.fromJson({
        'strength': 10,
        'agility': 8,
        'vitality': 12,
        'speed': 6,
        'defense': 4,
        'intelligence': 3,
      });

      expect(attributes.defense, 4);
      expect(attributes.intelligence, 3);
    });
  });

  group('CombatEvent.fromJson (PEND-03)', () {
    test('converte o tipo serializado pelo backend (SCREAMING_SNAKE_CASE)', () {
      final event = CombatEvent.fromJson({
        'type': 'CRITICAL_HIT',
        'actorId': 'char-1',
        'targetId': 'enemy-3',
        'amount': 27,
        'timestamp': 1757308800000,
      });

      expect(event.type, CombatEventType.criticalHit);
    });

    test('converte cada tipo de evento sem lançar exceção', () {
      const raw = ['ATTACK', 'CRITICAL_HIT', 'MISS', 'DEATH', 'COMBAT_END'];
      const expected = [
        CombatEventType.attack,
        CombatEventType.criticalHit,
        CombatEventType.miss,
        CombatEventType.death,
        CombatEventType.combatEnd,
      ];

      for (var i = 0; i < raw.length; i++) {
        final event = CombatEvent.fromJson({
          'type': raw[i],
          'actorId': 'a',
          'targetId': 'b',
          'amount': 1,
          'timestamp': 0,
        });
        expect(event.type, expected[i]);
      }
    });
  });

  group('Item.fromJson (PEND-04)', () {
    test('lê baseStats', () {
      final item = Item.fromJson({
        'id': 'item-1',
        'baseType': 'sword',
        'itemLevel': 3,
        'rarity': 'COMUM',
        'prefixes': [],
        'baseStats': {'damage': 5.0},
      });

      expect(item.baseStats, {'damage': 5.0});
      expect(item.rarity, Rarity.comum);
    });
  });
}
