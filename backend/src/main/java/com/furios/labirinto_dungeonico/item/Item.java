package com.furios.labirinto_dungeonico.item;

import java.util.List;
import java.util.Map;

public record Item(
        String id,
        String baseType,
        int itemLevel,
        Rarity rarity,
        List<Affix> prefixes,
        Map<String, Double> baseStats
) {
}
