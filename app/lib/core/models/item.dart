import 'affix.dart';
import 'rarity.dart';

class Item {
  const Item({
    required this.id,
    required this.baseType,
    required this.itemLevel,
    required this.rarity,
    required this.prefixes,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        baseType: json['baseType'] as String,
        itemLevel: json['itemLevel'] as int,
        rarity: Rarity.values.byName((json['rarity'] as String).toLowerCase()),
        prefixes: (json['prefixes'] as List)
            .map((e) => Affix.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String baseType;
  final int itemLevel;
  final Rarity rarity;
  final List<Affix> prefixes;
}
