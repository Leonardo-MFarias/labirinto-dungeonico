import 'attributes.dart';

class Enemy {
  const Enemy({
    required this.id,
    required this.name,
    required this.attributes,
    required this.currentHealth,
    required this.maxHealth,
  });

  factory Enemy.fromJson(Map<String, dynamic> json) => Enemy(
        id: json['id'] as String,
        name: json['name'] as String,
        attributes: Attributes.fromJson(json['attributes'] as Map<String, dynamic>),
        currentHealth: json['currentHealth'] as int,
        maxHealth: json['maxHealth'] as int,
      );

  final String id;
  final String name;
  final Attributes attributes;
  final int currentHealth;
  final int maxHealth;
}
