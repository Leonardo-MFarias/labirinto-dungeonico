enum CombatEventType { attack, criticalHit, miss, death, combatEnd }

class CombatEvent {
  const CombatEvent({
    required this.type,
    required this.actorId,
    required this.targetId,
    required this.amount,
    required this.timestamp,
  });

  factory CombatEvent.fromJson(Map<String, dynamic> json) => CombatEvent(
        type: CombatEventType.values.byName(json['type'] as String),
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
