import 'attributes.dart';
import 'item.dart';

enum GameMode { hardcore, normal }

class Character {
  const Character({
    required this.id,
    required this.name,
    required this.level,
    required this.experience,
    required this.unspentAttributePoints,
    required this.attributes,
    required this.effectiveAttributes,
    required this.inventory,
    required this.equipped,
    required this.mode,
    required this.currentHealth,
    required this.maxHealth,
    required this.alive,
  });

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as int,
        experience: json['experience'] as int,
        unspentAttributePoints: json['unspentAttributePoints'] as int,
        attributes: Attributes.fromJson(json['attributes'] as Map<String, dynamic>),
        effectiveAttributes: Attributes.fromJson(json['effectiveAttributes'] as Map<String, dynamic>),
        inventory: (json['inventory'] as List)
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
        equipped: (json['equipped'] as Map).map(
          (key, value) => MapEntry(key as String, Item.fromJson(value as Map<String, dynamic>)),
        ),
        mode: GameMode.values.byName((json['mode'] as String).toLowerCase()),
        currentHealth: json['currentHealth'] as int,
        maxHealth: json['maxHealth'] as int,
        alive: json['alive'] as bool,
      );

  final String id;
  final String name;
  final int level;
  final int experience;
  final int unspentAttributePoints;
  final Attributes attributes;
  final Attributes effectiveAttributes;
  final List<Item> inventory;
  final Map<String, Item> equipped;
  final GameMode mode;
  final int currentHealth;
  final int maxHealth;
  final bool alive;
}
