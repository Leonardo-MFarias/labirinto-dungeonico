package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Attributes;
import org.springframework.stereotype.Component;

import java.util.Random;
import java.util.UUID;

/**
 * Cria inimigos escalados pela profundidade da masmorra (RN-16: "a força dos inimigos... cresce
 * monotonicamente com a profundidade"). Fórmula revisada em v2.4 a pedido do usuário, após
 * playtesting mostrar que o inimigo do andar 1 nascia empatado em atributos com um personagem
 * recém-criado (mesma base 5), deixando a primeira luta uma questão de sorte: agora o inimigo
 * nasce mais fraco ({@link #MIN_ATTRIBUTE}) no andar 1 e sobe linearmente até
 * {@link #BASE_ATTRIBUTE} no andar {@link #EASE_IN_DEPTH} — o "andar de equilíbrio", onde a
 * força do inimigo passa a igualar a do personagem base — daí em diante cresce
 * {@link #PER_DEPTH_GROWTH} ponto por atributo a cada andar adicional, exatamente como antes.
 * Vida máxima segue a mesma fórmula de {@code Character}.
 */
@Component
public class EnemyFactory {

    private static final int MIN_ATTRIBUTE = 2;
    private static final int BASE_ATTRIBUTE = 5;
    private static final int EASE_IN_DEPTH = 5;
    private static final int PER_DEPTH_GROWTH = 1;
    private static final int BASE_HEALTH = 20;
    private static final int HEALTH_PER_VITALITY = 5;

    public Enemy create(Random random, int depth) {
        int value = attributeValueFor(depth);
        Attributes attributes = new Attributes(value, value, value, value, value, value);
        int maxHealth = BASE_HEALTH + attributes.vitality() * HEALTH_PER_VITALITY;
        String id = new UUID(random.nextLong(), random.nextLong()).toString();
        return new Enemy(id, "Inimigo nível " + depth, attributes, maxHealth, maxHealth);
    }

    /** RN-16: interpola de {@link #MIN_ATTRIBUTE} (andar 1) a {@link #BASE_ATTRIBUTE} (andar
     * {@link #EASE_IN_DEPTH}), depois cresce {@link #PER_DEPTH_GROWTH} por andar. */
    private int attributeValueFor(int depth) {
        if (depth <= EASE_IN_DEPTH) {
            double progress = (depth - 1) / (double) (EASE_IN_DEPTH - 1);
            return (int) Math.round(MIN_ATTRIBUTE + (BASE_ATTRIBUTE - MIN_ATTRIBUTE) * progress);
        }
        return BASE_ATTRIBUTE + (depth - EASE_IN_DEPTH) * PER_DEPTH_GROWTH;
    }
}
