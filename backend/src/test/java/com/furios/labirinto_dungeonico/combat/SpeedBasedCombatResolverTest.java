package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Attributes;
import com.furios.labirinto_dungeonico.character.Character;
import com.furios.labirinto_dungeonico.character.GameMode;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SpeedBasedCombatResolverTest {

    private final SpeedBasedCombatResolver resolver = new SpeedBasedCombatResolver();

    private Character newCharacter(int strength, int agility, int vitality, int speed, int defense) {
        Attributes attributes = new Attributes(strength, agility, vitality, speed, defense, 5);
        return new Character("player-1", "Herói", attributes, GameMode.NORMAL);
    }

    private Enemy newEnemy(int strength, int agility, int vitality, int speed, int defense) {
        Attributes attributes = new Attributes(strength, agility, vitality, speed, defense, 5);
        int maxHealth = 20 + vitality * 5;
        return new Enemy("enemy-1", "Goblin", attributes, maxHealth, maxHealth);
    }

    @ParameterizedTest
    @ValueSource(longs = {1L, 2L, 42L, 12345L})
    void mesmaSeedProduzOsMesmosEventos(long seed) {
        List<CombatEvent> first = resolver.resolve(newCharacter(10, 10, 10, 10, 5), newEnemy(8, 8, 8, 8, 4), seed);
        List<CombatEvent> second = resolver.resolve(newCharacter(10, 10, 10, 10, 5), newEnemy(8, 8, 8, 8, 4), seed);

        assertEquals(first.size(), second.size());
        for (int i = 0; i < first.size(); i++) {
            CombatEvent a = first.get(i);
            CombatEvent b = second.get(i);
            assertEquals(a.type(), b.type());
            assertEquals(a.actorId(), b.actorId());
            assertEquals(a.targetId(), b.targetId());
            assertEquals(a.amount(), b.amount());
        }
    }

    @ParameterizedTest
    @ValueSource(longs = {1L, 2L, 42L, 12345L, 999L})
    void terminaSempreComDeathSeguidoDeCombatEnd(long seed) {
        List<CombatEvent> events = resolver.resolve(newCharacter(10, 10, 10, 10, 5), newEnemy(8, 8, 8, 8, 4), seed);

        assertTrue(events.size() >= 2);
        assertEquals(CombatEventType.DEATH, events.get(events.size() - 2).type());
        assertEquals(CombatEventType.COMBAT_END, events.get(events.size() - 1).type());
    }

    @ParameterizedTest
    @ValueSource(longs = {1L, 2L, 3L, 4L, 5L})
    void personagemMuitoMaisForteVenceInimigoFraco(long seed) {
        Character strong = newCharacter(50, 50, 50, 50, 30);
        Enemy weak = newEnemy(1, 0, 1, 1, 0);

        resolver.resolve(strong, weak, seed);

        assertTrue(strong.isAlive());
    }

    @ParameterizedTest
    @ValueSource(longs = {1L, 2L, 3L, 4L, 5L})
    void personagemMuitoMaisFracoPerdeParaInimigoForte(long seed) {
        Character weak = newCharacter(1, 0, 1, 1, 0);
        Enemy strong = newEnemy(50, 50, 50, 50, 30);

        resolver.resolve(weak, strong, seed);

        assertFalse(weak.isAlive());
    }

    @Test
    void danoNuncaFicaAbaixoDeUm() {
        // Defesa do inimigo muito maior que a força do jogador: todo ATTACK/CRITICAL_HIT deve
        // ainda assim causar pelo menos 1 de dano (RN-06, piso mínimo).
        Character character = newCharacter(5, 30, 20, 20, 5);
        Enemy enemy = newEnemy(0, 0, 20, 5, 1000);

        List<CombatEvent> events = resolver.resolve(character, enemy, 7L);

        boolean anyPlayerHit = false;
        for (CombatEvent event : events) {
            if (event.actorId().equals(character.id())
                    && (event.type() == CombatEventType.ATTACK || event.type() == CombatEventType.CRITICAL_HIT)) {
                anyPlayerHit = true;
                assertTrue(event.amount() >= 1);
            }
        }
        assertTrue(anyPlayerHit, "Esperava pelo menos um ATTACK/CRITICAL_HIT do jogador");
    }
}
