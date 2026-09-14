package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Attributes;
import org.springframework.stereotype.Component;

import java.util.Random;
import java.util.UUID;

/**
 * Cria inimigos escalados pela profundidade da masmorra (RN-16: "a força dos inimigos... cresce
 * monotonicamente com a profundidade"). Fórmula assumida nesta versão (não especificada em
 * detalhe nos requisitos): atributos base {@link #BASE_ATTRIBUTE} + 1 ponto por nível de
 * profundidade em cada atributo, a partir da profundidade 1 (andar mais raso tem inimigos
 * equivalentes a um personagem recém-criado, também com atributos base 5 — RN-16 exige
 * crescimento monotônico com a profundidade, não uma vantagem já no andar inicial); vida máxima
 * segue a mesma fórmula de {@code Character}.
 */
@Component
public class EnemyFactory {

    private static final int BASE_ATTRIBUTE = 5;
    private static final int PER_DEPTH_GROWTH = 1;
    private static final int BASE_HEALTH = 20;
    private static final int HEALTH_PER_VITALITY = 5;

    public Enemy create(Random random, int depth) {
        int value = BASE_ATTRIBUTE + (depth - 1) * PER_DEPTH_GROWTH;
        Attributes attributes = new Attributes(value, value, value, value, value, value);
        int maxHealth = BASE_HEALTH + attributes.vitality() * HEALTH_PER_VITALITY;
        String id = new UUID(random.nextLong(), random.nextLong()).toString();
        return new Enemy(id, "Inimigo nível " + depth, attributes, maxHealth, maxHealth);
    }
}
