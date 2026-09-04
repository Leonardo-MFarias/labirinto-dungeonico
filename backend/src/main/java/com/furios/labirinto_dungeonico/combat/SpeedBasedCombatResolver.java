package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Character;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class SpeedBasedCombatResolver implements CombatResolver {

    @Override
    public List<CombatEvent> resolve(Character player, Enemy enemy) {
        // TODO: simular ticks de combate com base no atributo speed de cada lado (sistema tipo ATB)
        return List.of(new CombatEvent(CombatEventType.COMBAT_END, player.id(), enemy.id(), 0, System.currentTimeMillis()));
    }
}
