package com.furios.labirinto_dungeonico.item;

import java.util.Map;

public record Affix(
        String id,
        String name,
        Map<String, Double> modifiers,
        int minItemLevel,
        Rarity minRarity
) {
}
