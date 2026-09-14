package com.furios.labirinto_dungeonico.item;

import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Fórmulas assumidas nesta versão (RN-16/RN-08/RN-09 só especificam a direção qualitativa, não
 * valores exatos):
 * <ul>
 *   <li>Raridade: peso-base decrescente por raridade, com bônus proporcional a
 *       {@code depth * ordinal(raridade)} — desloca a massa de probabilidade para raridades
 *       altas conforme a profundidade sobe (RN-16);</li>
 *   <li>Quantidade de afixos por raridade: ver {@link #maxAffixesFor(Rarity)} (RN-09);</li>
 *   <li>Elegibilidade de afixo: {@code minItemLevel} e {@code minRarity} do afixo (RN-08).</li>
 * </ul>
 */
@Service
public class RandomLootGenerator implements LootGenerator {

    private static final double RARITY_DEPTH_WEIGHT = 0.01;

    private final AffixTable affixTable;

    public RandomLootGenerator(AffixTable affixTable) {
        this.affixTable = affixTable;
    }

    @Override
    public Item generate(long seed, String baseType, int dungeonDepth) {
        Random random = new Random(seed);
        Rarity rarity = rollRarity(random, dungeonDepth);
        List<Affix> prefixes = rollAffixes(random, dungeonDepth, rarity);

        return new Item(
                UUID.randomUUID().toString(),
                baseType,
                dungeonDepth,
                rarity,
                prefixes,
                Map.of()
        );
    }

    private Rarity rollRarity(Random random, int depth) {
        Rarity[] rarities = Rarity.values();
        double[] weights = new double[rarities.length];
        double total = 0;
        for (int i = 0; i < rarities.length; i++) {
            weights[i] = Math.max(0.01, 1.0 - i * 0.09) + depth * RARITY_DEPTH_WEIGHT * i;
            total += weights[i];
        }
        double roll = random.nextDouble() * total;
        double cumulative = 0;
        for (int i = 0; i < rarities.length; i++) {
            cumulative += weights[i];
            if (roll < cumulative) {
                return rarities[i];
            }
        }
        return rarities[rarities.length - 1];
    }

    private List<Affix> rollAffixes(Random random, int itemLevel, Rarity rarity) {
        int maxAffixes = maxAffixesFor(rarity);
        if (maxAffixes == 0) {
            return List.of();
        }
        List<Affix> eligible = affixTable.all().stream()
                .filter(affix -> affix.minItemLevel() <= itemLevel)
                .filter(affix -> affix.minRarity().ordinal() <= rarity.ordinal())
                .collect(Collectors.toCollection(ArrayList::new));
        Collections.shuffle(eligible, random);
        return List.copyOf(eligible.subList(0, Math.min(maxAffixes, eligible.size())));
    }

    /** RN-09: raridades mais altas comportam mais afixos. */
    private int maxAffixesFor(Rarity rarity) {
        return switch (rarity) {
            case OBSOLETO, ARCAICO, TRIVIAL -> 0;
            case NORMAL, COMUM -> 1;
            case INCOMUM -> 2;
            case LENDARIO -> 3;
            case MITICO -> 4;
            case DIVINO -> 5;
            case ASTRAL -> 6;
        };
    }
}
