package com.furios.labirinto_dungeonico.item;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RandomLootGeneratorTest {

    private final RandomLootGenerator generator = new RandomLootGenerator(new AffixTable());

    @Test
    void itemLevelIgualAProfundidade() {
        Item item = generator.generate(1L, "espada", 7);

        assertEquals(7, item.itemLevel());
    }

    @Test
    void afixosRespeitamMinItemLevelEMinRarity() {
        for (long seed = 0; seed < 200; seed++) {
            Item item = generator.generate(seed, "espada", 15);
            for (Affix affix : item.prefixes()) {
                assertTrue(affix.minItemLevel() <= item.itemLevel());
                assertTrue(affix.minRarity().ordinal() <= item.rarity().ordinal());
            }
        }
    }

    @Test
    void nuncaRepeteOMesmoAfixoNoMesmoItem() {
        for (long seed = 0; seed < 200; seed++) {
            Item item = generator.generate(seed, "espada", 15);
            Set<String> ids = new HashSet<>();
            for (Affix affix : item.prefixes()) {
                assertTrue(ids.add(affix.id()), "Afixo repetido: " + affix.id());
            }
        }
    }

    @Test
    void mesmaSeedProduzOMesmoItem() {
        Item first = generator.generate(42L, "elmo", 5);
        Item second = generator.generate(42L, "elmo", 5);

        assertEquals(first.rarity(), second.rarity());
        assertEquals(first.prefixes().size(), second.prefixes().size());
    }

    @Test
    void raridadeMediaSobeComAProfundidade() {
        double meanOrdinalShallow = averageRarityOrdinal(1);
        double meanOrdinalDeep = averageRarityOrdinal(50);

        assertTrue(meanOrdinalDeep > meanOrdinalShallow,
                "Esperava raridade média maior em profundidade alta: raso=" + meanOrdinalShallow
                        + " fundo=" + meanOrdinalDeep);
    }

    private double averageRarityOrdinal(int depth) {
        long sum = 0;
        int samples = 500;
        for (long seed = 0; seed < samples; seed++) {
            sum += generator.generate(seed, "espada", depth).rarity().ordinal();
        }
        return (double) sum / samples;
    }
}
