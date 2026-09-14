package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Character;

import java.util.List;

public interface CombatResolver {

    /**
     * Resolve um combate por completo (todos os ticks até um dos lados morrer), com {@code seed}
     * determinando todo o sorteio (RNF-07/RNF-20).
     */
    List<CombatEvent> resolve(Character player, Enemy enemy, long seed);
}
