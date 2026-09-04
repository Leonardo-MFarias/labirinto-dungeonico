package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Character;

import java.util.List;

public interface CombatResolver {

    List<CombatEvent> resolve(Character player, Enemy enemy);
}
