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
}
