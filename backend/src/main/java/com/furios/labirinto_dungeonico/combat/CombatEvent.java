package com.furios.labirinto_dungeonico.combat;

public record CombatEvent(
        CombatEventType type,
        String actorId,
        String targetId,
        int amount,
        long timestamp
) {
}
