import 'combat_event.dart';
import 'game_session.dart';

/// Resposta de `POST /api/session/{id}/move`. [combatEvents] é `null` quando
/// o movimento não desencadeou combate.
class MoveResponse {
  const MoveResponse({required this.session, required this.combatEvents});

  factory MoveResponse.fromJson(Map<String, dynamic> json) => MoveResponse(
        session: GameSession.fromJson(json['session'] as Map<String, dynamic>),
        combatEvents: json['combatEvents'] == null
            ? null
            : (json['combatEvents'] as List)
                .map((e) => CombatEvent.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  final GameSession session;
  final List<CombatEvent>? combatEvents;
}
