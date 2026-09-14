package com.furios.labirinto_dungeonico.api.dto;

import com.furios.labirinto_dungeonico.combat.CombatEvent;
import com.furios.labirinto_dungeonico.session.GameSession;

import java.util.List;

/**
 * Resposta de {@code POST /api/session/{id}/move}. {@code combatEvents} é {@code null} quando o
 * movimento não desencadeou combate; quando presente, RF-20 a RF-27 já foram aplicados (XP/loot
 * na vitória, RN-01/RN-02 na derrota) antes desta resposta ser montada.
 */
public record MoveResponse(GameSession session, List<CombatEvent> combatEvents) {
}
