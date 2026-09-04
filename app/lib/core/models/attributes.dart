class Attributes {
  const Attributes({
    required this.strength,
    required this.agility,
    required this.vitality,
    required this.speed,
  });

  factory Attributes.fromJson(Map<String, dynamic> json) => Attributes(
        strength: json['strength'] as int,
        agility: json['agility'] as int,
        vitality: json['vitality'] as int,
        speed: json['speed'] as int,
      );

  final int strength;
  final int agility;
  final int vitality;
  final int speed;
}
