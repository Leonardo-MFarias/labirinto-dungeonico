class Affix {
  const Affix({
    required this.id,
    required this.name,
    required this.modifiers,
  });

  factory Affix.fromJson(Map<String, dynamic> json) => Affix(
        id: json['id'] as String,
        name: json['name'] as String,
        modifiers: (json['modifiers'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      );

  final String id;
  final String name;
  final Map<String, double> modifiers;
}
