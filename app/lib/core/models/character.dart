import 'attributes.dart';
import 'item.dart';

enum GameMode { hardcore, normal }

class Character {
  const Character({
    required this.id,
    required this.name,
    required this.level,
    required this.experience,
    required this.attributes,
    required this.inventory,
    required this.mode,
  });

  final String id;
  final String name;
  final int level;
  final int experience;
  final Attributes attributes;
  final List<Item> inventory;
  final GameMode mode;
}
