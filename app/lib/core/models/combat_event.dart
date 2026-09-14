enum CombatEventType { attack, criticalHit, miss, death, combatEnd }

/// O backend serializa o enum pelo nome Java (ex.: `CRITICAL_HIT`); converte para o
/// nome lowerCamelCase usado pelo enum Dart correspondente (ex.: `criticalHit`).
CombatEventType _combatEventTypeFromJava(String javaName) {
  final camelCase = javaName.toLowerCase().replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
  return CombatEventType.values.byName(camelCase);
}

class CombatEvent {
  const CombatEvent({
    required this.type,
    required this.actorId,
    required this.targetId,
    required this.amount,
    required this.timestamp,
  });

  factory CombatEvent.fromJson(Map<String, dynamic> json) => CombatEvent(
        type: _combatEventTypeFromJava(json['type'] as String),
        actorId: json['actorId'] as String,
        targetId: json['targetId'] as String,
        amount: json['amount'] as int,
        timestamp: json['timestamp'] as int,
      );

  final CombatEventType type;
  final String actorId;
  final String targetId;
  final int amount;
  final int timestamp;
}
