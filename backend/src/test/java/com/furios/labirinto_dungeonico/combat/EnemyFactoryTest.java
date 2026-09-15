package com.furios.labirinto_dungeonico.combat;

import org.junit.jupiter.api.Test;

import java.util.Random;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class EnemyFactoryTest {

    private final EnemyFactory factory = new EnemyFactory();

    @Test
    void atributosECrescemMonotonicamenteComAProfundidade() {
        Enemy shallow = factory.create(new Random(1), 1);
        Enemy deep = factory.create(new Random(1), 20);

        assertTrue(deep.attributes().strength() > shallow.attributes().strength());
        assertTrue(deep.attributes().vitality() > shallow.attributes().vitality());
        assertTrue(deep.maxHealth() > shallow.maxHealth());
    }

    @Test
    void vidaAtualComecaCheia() {
        Enemy enemy = factory.create(new Random(1), 5);

        assertEquals(enemy.maxHealth(), enemy.currentHealth());
    }

    /** RN-16 (revisada v2.4): andar 1 nasce mais fraco que um personagem recém-criado
     * (atributos base 5), não empatado com ele. */
    @Test
    void inimigoDoAndar1NasceMaisFracoQuePersonagemRecemCriado() {
        Enemy enemy = factory.create(new Random(1), 1);

        assertTrue(enemy.attributes().strength() < 5);
    }

    /** RN-16 (revisada v2.4): a força do inimigo alcança a base do personagem (5) no andar de
     * equilíbrio (5), não antes disso. */
    @Test
    void inimigoAlcancaAtributoBaseNoAndarDeEquilibrio() {
        Enemy enemy = factory.create(new Random(1), 5);

        assertEquals(5, enemy.attributes().strength());
    }

    /** RN-16 (revisada v2.4): além do andar de equilíbrio, a escala volta a crescer 1 ponto por
     * andar, como antes da revisão. */
    @Test
    void inimigoContinuaCrescendoAposOAndarDeEquilibrio() {
        Enemy atEquilibrium = factory.create(new Random(1), 5);
        Enemy beyond = factory.create(new Random(1), 6);

        assertEquals(atEquilibrium.attributes().strength() + 1, beyond.attributes().strength());
    }

    @Test
    void atributosCrescemMonotonicamenteDentroDaFaseDeAquecimento() {
        int previous = factory.create(new Random(1), 1).attributes().strength();
        for (int depth = 2; depth <= 5; depth++) {
            int current = factory.create(new Random(1), depth).attributes().strength();
            assertTrue(current >= previous, "Esperava crescimento monotônico até o andar de equilíbrio");
            previous = current;
        }
    }
}
