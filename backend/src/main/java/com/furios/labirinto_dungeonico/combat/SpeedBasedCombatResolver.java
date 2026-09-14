package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Attributes;
import com.furios.labirinto_dungeonico.character.Character;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Resolve o combate por ticks (modelo ATB, RN-05): cada combatente acumula uma barra de
 * iniciativa proporcional a {@code speed} a cada tick e age ao atingir {@link #ACTION_THRESHOLD}.
 * Em empate no mesmo tick, o jogador age primeiro (RN-05) — garantido pela ordem do código
 * abaixo, já que a ação do inimigo é abortada se o jogador já o derrotou nesse tick.
 *
 * <p>Fórmulas de acerto/crítico (RN-07) não são especificadas em detalhe nos requisitos;
 * valores assumidos nesta versão: {@link #MISS_CHANCE} de errar, {@link #CRIT_CHANCE_PER_AGILITY}
 * de chance de crítico por ponto de agility (capado em {@link #CRIT_CHANCE_CAP}), dano crítico
 * multiplicado por {@link #CRIT_MULTIPLIER}.
 */
@Service
public class SpeedBasedCombatResolver implements CombatResolver {

    private static final double ACTION_THRESHOLD = 100.0;
    private static final double MISS_CHANCE = 0.05;
    private static final double CRIT_CHANCE_PER_AGILITY = 0.01;
    private static final double CRIT_CHANCE_CAP = 0.5;
    private static final double CRIT_MULTIPLIER = 1.5;
    private static final long MAX_TICKS = 100_000;

    @Override
    public List<CombatEvent> resolve(Character player, Enemy enemy, long seed) {
        Random random = new Random(seed);
        List<CombatEvent> events = new ArrayList<>();

        int enemyHealth = enemy.maxHealth();
        double playerGauge = 0;
        double enemyGauge = 0;

        for (long tick = 0; tick < MAX_TICKS; tick++) {
            playerGauge += player.attributes().speed();
            enemyGauge += enemy.attributes().speed();

            if (playerGauge >= ACTION_THRESHOLD) {
                enemyHealth -= act(random, player.attributes(), enemy.attributes(), enemyHealth,
                        events, player.id(), enemy.id());
                playerGauge -= ACTION_THRESHOLD;
                if (enemyHealth <= 0) {
                    break;
                }
            }
            if (enemyGauge >= ACTION_THRESHOLD) {
                int damage = act(random, enemy.attributes(), player.attributes(), player.currentHealth(),
                        events, enemy.id(), player.id());
                player.applyDamage(damage);
                enemyGauge -= ACTION_THRESHOLD;
                if (!player.isAlive()) {
                    break;
                }
            }
        }

        boolean playerWon = player.isAlive() && enemyHealth <= 0;
        String winnerId = playerWon ? player.id() : enemy.id();
        String loserId = playerWon ? enemy.id() : player.id();
        long now = System.currentTimeMillis();
        events.add(new CombatEvent(CombatEventType.DEATH, winnerId, loserId, 0, now));
        events.add(new CombatEvent(CombatEventType.COMBAT_END, winnerId, loserId, 0, now));
        return events;
    }

    /** Executa uma ação de {@code attacker} contra {@code defender}, devolve o dano aplicado. */
    private int act(Random random, Attributes attacker, Attributes defender, int defenderHealth,
            List<CombatEvent> events, String actorId, String targetId) {
        long now = System.currentTimeMillis();
        if (random.nextDouble() < MISS_CHANCE) {
            events.add(new CombatEvent(CombatEventType.MISS, actorId, targetId, 0, now));
            return 0;
        }

        // RN-06: dano = strength do atacante - defense do alvo, piso 1.
        int baseDamage = Math.max(1, attacker.strength() - defender.defense());
        double critChance = Math.min(CRIT_CHANCE_CAP, attacker.agility() * CRIT_CHANCE_PER_AGILITY);
        boolean critical = random.nextDouble() < critChance;
        int damage = critical ? (int) Math.round(baseDamage * CRIT_MULTIPLIER) : baseDamage;
        damage = Math.min(damage, defenderHealth);

        events.add(new CombatEvent(
                critical ? CombatEventType.CRITICAL_HIT : CombatEventType.ATTACK,
                actorId, targetId, damage, now));
        return damage;
    }
}
