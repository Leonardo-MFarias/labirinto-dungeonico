package com.furios.labirinto_dungeonico.item;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class RandomLootGenerator implements LootGenerator {

    @Override
    public Item generate(String baseType, int dungeonDepth) {
        // TODO: sortear raridade (ponderada por dungeonDepth) e prefixos elegíveis da tabela de afixos
        return new Item(
                UUID.randomUUID().toString(),
                baseType,
                dungeonDepth,
                Rarity.NORMAL,
                List.of(),
                Map.of()
        );
    }
}
